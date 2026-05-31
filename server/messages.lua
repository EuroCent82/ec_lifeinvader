--[[ ec_lifeinvader — Ingame-Nachrichten (Anzeigen-Chat) ]]

LiBridgeServerMessages = LiBridgeServerMessages or {}

local function messagesCfg()
    return Config.Messages or {}
end

local function maxBodyLength()
    return tonumber(messagesCfg().maxLength) or 500
end

local function respond(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:messagesResult', src, requestId, payload)
end

local function teamRespond(src, requestId, payload)
    LiBridgeServerTeam.Respond(src, requestId, payload)
end

local function trimBody(text)
    return tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function parseDateTimeToUnix(value)
    if not value then
        return nil
    end

    if type(value) == 'number' then
        if value > 1e12 then
            return math.floor(value / 1000)
        end
        return math.floor(value)
    end

    local text = tostring(value)
    local numeric = tonumber(text)
    if numeric then
        if numeric > 1e12 then
            return math.floor(numeric / 1000)
        end
        return math.floor(numeric)
    end

    local y, m, d, h, min, sec = text:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)')
    if not y then
        y, m, d, h, min = text:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+)')
        sec = 0
    end

    if y then
        return os.time({
            year = tonumber(y),
            month = tonumber(m),
            day = tonumber(d),
            hour = tonumber(h),
            min = tonumber(min),
            sec = tonumber(sec) or 0,
        })
    end

    return nil
end

local function formatTimestamp(value)
    if value == nil then
        return nil
    end

    local unix = parseDateTimeToUnix(value)
    if unix then
        return os.date('%d.%m.%Y %H:%M', unix)
    end

    return tostring(value)
end

local function isAnonymousFeed(row)
    return row and (row.anonymous == 1 or row.anonymous == true)
end

local function publicAuthorName(row, viewerIdentifier)
    local realName = row.author_name or 'Unbekannt'
    local ownerIdentifier = row.identifier or row.ad_owner_identifier

    if isAnonymousFeed(row) and ownerIdentifier ~= viewerIdentifier then
        return 'Anonym'
    end

    return realName
end

local function mapMessageRow(row, viewerIdentifier)
    return {
        id = tonumber(row.id),
        conversationId = tonumber(row.conversation_id),
        senderIdentifier = row.sender_identifier,
        body = row.body,
        createdAt = formatTimestamp(row.created_at),
        isMine = row.sender_identifier == viewerIdentifier,
    }
end

local FEED_SELECT = [[SELECT id, identifier, author_name, title, content, category, phone, anonymous, status, expires_at
          FROM lifeinvader_feeds WHERE id = ? LIMIT 1]]

local CONVERSATION_SELECT = [[SELECT c.id, c.feed_id, c.ad_owner_identifier, c.guest_identifier, c.guest_name,
                 c.created_at, c.updated_at,
                 f.title AS feed_title, f.author_name, f.phone, f.anonymous, f.status AS feed_status
          FROM lifeinvader_conversations c
          INNER JOIN lifeinvader_feeds f ON f.id = c.feed_id
          WHERE c.id = ? LIMIT 1]]

local function fetchFeed(feedId)
    return LiBridge.MySQL.SingleSync(FEED_SELECT, { feedId })
end

local function fetchConversation(conversationId)
    return LiBridge.MySQL.SingleSync(CONVERSATION_SELECT, { conversationId })
end

local function participantAllowed(conversation, identifier)
    if not conversation or not identifier then
        return false
    end
    return identifier == conversation.ad_owner_identifier
        or identifier == conversation.guest_identifier
end

local UNREAD_COUNT_SELECT = [[(SELECT COUNT(*) FROM lifeinvader_messages um
    WHERE um.conversation_id = c.id
      AND um.sender_identifier <> ?
      AND um.created_at > COALESCE(
        IF(c.ad_owner_identifier = ?, c.ad_owner_last_read_at, c.guest_last_read_at),
        '1970-01-01 00:00:00')) AS unread_count]]

local function markConversationRead(conversation, identifier)
    if not conversation or not identifier then
        return
    end

    if conversation.ad_owner_identifier == identifier then
        LiBridge.MySQL.ExecuteSync(
            'UPDATE lifeinvader_conversations SET ad_owner_last_read_at = CURRENT_TIMESTAMP WHERE id = ?',
            { tonumber(conversation.id) }
        )
        return
    end

    if conversation.guest_identifier == identifier then
        LiBridge.MySQL.ExecuteSync(
            'UPDATE lifeinvader_conversations SET guest_last_read_at = CURRENT_TIMESTAMP WHERE id = ?',
            { tonumber(conversation.id) }
        )
    end
end

function LiBridgeServerMessages.GetUnreadCount(identifier, cb)
    if messagesCfg().enabled == false or not identifier then
        if cb then
            cb(0)
        end
        return 0
    end

    if cb then
        LiBridge.MySQL.Query(
            [[SELECT COUNT(*) AS count
              FROM lifeinvader_messages um
              INNER JOIN lifeinvader_conversations c ON c.id = um.conversation_id
              WHERE (c.ad_owner_identifier = ? OR c.guest_identifier = ?)
                AND um.sender_identifier <> ?
                AND um.created_at > COALESCE(
                  IF(c.ad_owner_identifier = ?, c.ad_owner_last_read_at, c.guest_last_read_at),
                  '1970-01-01 00:00:00')]],
            { identifier, identifier, identifier, identifier },
            function(result)
                cb(tonumber(result and result[1] and result[1].count) or 0)
            end
        )
        return
    end

    local row = LiBridge.MySQL.SingleSync(
        [[SELECT COUNT(*) AS count
          FROM lifeinvader_messages um
          INNER JOIN lifeinvader_conversations c ON c.id = um.conversation_id
          WHERE (c.ad_owner_identifier = ? OR c.guest_identifier = ?)
            AND um.sender_identifier <> ?
            AND um.created_at > COALESCE(
              IF(c.ad_owner_identifier = ?, c.ad_owner_last_read_at, c.guest_last_read_at),
              '1970-01-01 00:00:00')]],
        { identifier, identifier, identifier, identifier }
    )

    return tonumber(row and row.count) or 0
end

local function mapConversationSummary(row, viewerIdentifier)
    local isOwner = row.ad_owner_identifier == viewerIdentifier
    local displayAuthor = publicAuthorName({
        author_name = row.author_name,
        anonymous = row.anonymous,
        ad_owner_identifier = row.ad_owner_identifier,
    }, viewerIdentifier)

    return {
        id = tonumber(row.id),
        feedId = tonumber(row.feed_id),
        adTitle = row.feed_title or row.title,
        adAuthor = displayAuthor,
        adPhone = row.phone,
        feedStatus = row.feed_status,
        partnerName = isOwner and (row.guest_name or 'Unbekannt') or displayAuthor,
        partnerIdentifier = isOwner and row.guest_identifier or row.ad_owner_identifier,
        isOwner = isOwner,
        updatedAt = formatTimestamp(row.updated_at),
        lastMessage = row.last_body,
        lastMessageAt = formatTimestamp(row.last_message_at),
        unreadCount = tonumber(row.unread_count) or 0,
    }
end

local function mapAdPayload(feed, viewerIdentifier)
    return {
        id = tonumber(feed.id),
        title = feed.title,
        content = feed.content,
        category = feed.category,
        author = publicAuthorName(feed, viewerIdentifier),
        phone = feed.phone,
    }
end

function LiBridgeServerMessages.OpenChat(src, requestId, feedId)
    feedId = tonumber(feedId)
    if not feedId then
        respond(src, requestId, { ok = false, error = 'invalid_feed' })
        return
    end

    if messagesCfg().enabled == false then
        respond(src, requestId, { ok = false, error = 'messages_disabled' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respond(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    LiBridgeServerBlacklist.IsBanned(identifier, function(banned)
        if banned then
            respond(src, requestId, { ok = false, error = 'blacklisted' })
            return
        end

        local feed = fetchFeed(feedId)
        if not feed then
            respond(src, requestId, { ok = false, error = 'feed_not_found' })
            return
        end

        if feed.status ~= 'active' then
            respond(src, requestId, { ok = false, error = 'feed_inactive' })
            return
        end

        if feed.identifier == identifier then
            respond(src, requestId, { ok = false, error = 'own_ad' })
            return
        end

        local guestName = LiBridge.Server.GetCharacterName(src) or 'Unbekannt'

        LiBridge.MySQL.InsertSync(
            [[INSERT INTO lifeinvader_conversations (feed_id, ad_owner_identifier, guest_identifier, guest_name)
              VALUES (?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE guest_name = VALUES(guest_name)]],
            { feedId, feed.identifier, identifier, guestName }
        )

        local conversation = LiBridge.MySQL.SingleSync(
            [[SELECT c.id, c.feed_id, c.ad_owner_identifier, c.guest_identifier, c.guest_name,
                     c.created_at, c.updated_at,
                     f.title AS feed_title, f.author_name, f.phone, f.anonymous, f.status AS feed_status,
                     (SELECT m.body FROM lifeinvader_messages m
                      WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_body,
                     (SELECT m.created_at FROM lifeinvader_messages m
                      WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message_at
              FROM lifeinvader_conversations c
              INNER JOIN lifeinvader_feeds f ON f.id = c.feed_id
              WHERE c.feed_id = ? AND c.guest_identifier = ? LIMIT 1]],
            { feedId, identifier }
        )

        if not conversation then
            respond(src, requestId, { ok = false, error = 'conversation_failed' })
            return
        end

        respond(src, requestId, {
            ok = true,
            conversation = mapConversationSummary(conversation, identifier),
            ad = mapAdPayload(feed, identifier),
        })
    end)
end

function LiBridgeServerMessages.ListInbox(src, requestId)
    if messagesCfg().enabled == false then
        respond(src, requestId, { ok = false, error = 'messages_disabled' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respond(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    local rows = LiBridge.MySQL.QuerySync(
        ([[SELECT c.id, c.feed_id, c.ad_owner_identifier, c.guest_identifier, c.guest_name,
                 c.updated_at, f.title AS feed_title, f.author_name, f.phone, f.anonymous, f.status AS feed_status,
                 (SELECT m.body FROM lifeinvader_messages m
                  WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_body,
                 (SELECT m.created_at FROM lifeinvader_messages m
                  WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message_at,
                 %s
          FROM lifeinvader_conversations c
          INNER JOIN lifeinvader_feeds f ON f.id = c.feed_id
          WHERE c.ad_owner_identifier = ? OR c.guest_identifier = ?
          ORDER BY c.updated_at DESC
          LIMIT 100]]):format(UNREAD_COUNT_SELECT),
        { identifier, identifier, identifier, identifier, identifier }
    )

    local conversations = {}
    for i = 1, #rows do
        conversations[#conversations + 1] = mapConversationSummary(rows[i], identifier)
    end

    respond(src, requestId, {
        ok = true,
        conversations = conversations,
        unreadTotal = LiBridgeServerMessages.GetUnreadCount(identifier),
    })
end

function LiBridgeServerMessages.ListMessages(src, requestId, conversationId)
    conversationId = tonumber(conversationId)
    if not conversationId then
        respond(src, requestId, { ok = false, error = 'invalid_conversation' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respond(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    local conversation = fetchConversation(conversationId)
    if not conversation or not participantAllowed(conversation, identifier) then
        respond(src, requestId, { ok = false, error = 'no_access' })
        return
    end

    markConversationRead(conversation, identifier)

    local rows = LiBridge.MySQL.QuerySync(
        [[SELECT id, conversation_id, sender_identifier, body, created_at
          FROM lifeinvader_messages
          WHERE conversation_id = ?
          ORDER BY id ASC
          LIMIT 200]],
        { conversationId }
    )

    local messages = {}
    for i = 1, #rows do
        messages[#messages + 1] = mapMessageRow(rows[i], identifier)
    end

    respond(src, requestId, {
        ok = true,
        conversation = mapConversationSummary(conversation, identifier),
        messages = messages,
        ad = {
            id = tonumber(conversation.feed_id),
            title = conversation.feed_title,
            author = publicAuthorName({
                author_name = conversation.author_name,
                anonymous = conversation.anonymous,
                ad_owner_identifier = conversation.ad_owner_identifier,
            }, identifier),
            phone = conversation.phone,
        },
        unreadTotal = LiBridgeServerMessages.GetUnreadCount(identifier),
    })
end

function LiBridgeServerMessages.SendMessage(src, requestId, conversationId, body)
    conversationId = tonumber(conversationId)
    body = trimBody(body)
    local maxLen = maxBodyLength()

    if not conversationId then
        respond(src, requestId, { ok = false, error = 'invalid_conversation' })
        return
    end

    if body == '' then
        respond(src, requestId, { ok = false, error = 'empty_message' })
        return
    end

    if #body > maxLen then
        respond(src, requestId, { ok = false, error = 'message_too_long' })
        return
    end

    if messagesCfg().enabled == false then
        respond(src, requestId, { ok = false, error = 'messages_disabled' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respond(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    LiBridgeServerBlacklist.IsBanned(identifier, function(banned)
        if banned then
            respond(src, requestId, { ok = false, error = 'blacklisted' })
            return
        end

        local conversation = fetchConversation(conversationId)
        if not conversation or not participantAllowed(conversation, identifier) then
            respond(src, requestId, { ok = false, error = 'no_access' })
            return
        end

        if conversation.feed_status ~= 'active' then
            respond(src, requestId, { ok = false, error = 'feed_inactive' })
            return
        end

        local messageId = LiBridge.MySQL.InsertSync(
            [[INSERT INTO lifeinvader_messages (conversation_id, sender_identifier, body)
              VALUES (?, ?, ?)]],
            { conversationId, identifier, body }
        )

        LiBridge.MySQL.ExecuteSync(
            'UPDATE lifeinvader_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = ?',
            { conversationId }
        )

        local row = LiBridge.MySQL.SingleSync(
            [[SELECT id, conversation_id, sender_identifier, body, created_at
              FROM lifeinvader_messages WHERE id = ? LIMIT 1]],
            { messageId }
        )

        respond(src, requestId, {
            ok = true,
            message = mapMessageRow(row, identifier),
        })
    end)
end

function LiBridgeServerMessages.TeamListFeedConversations(src, requestId, feedId)
    feedId = tonumber(feedId)
    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    if not feedId then
        teamRespond(src, requestId, { ok = false, error = 'invalid_feed' })
        return
    end

    local feed = fetchFeed(feedId)
    if not feed then
        teamRespond(src, requestId, { ok = false, error = 'feed_not_found' })
        return
    end

    local rows = LiBridge.MySQL.QuerySync(
        [[SELECT c.id, c.feed_id, c.ad_owner_identifier, c.guest_identifier, c.guest_name,
                 c.updated_at, f.title AS feed_title, f.author_name, f.phone, f.anonymous, f.status AS feed_status,
                 (SELECT m.body FROM lifeinvader_messages m
                  WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_body,
                 (SELECT m.created_at FROM lifeinvader_messages m
                  WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message_at,
                 (SELECT COUNT(*) FROM lifeinvader_messages m WHERE m.conversation_id = c.id) AS message_count
          FROM lifeinvader_conversations c
          INNER JOIN lifeinvader_feeds f ON f.id = c.feed_id
          WHERE c.feed_id = ?
          ORDER BY c.updated_at DESC]],
        { feedId }
    )

    local conversations = {}
    for i = 1, #rows do
        conversations[#conversations + 1] = {
            id = tonumber(rows[i].id),
            feedId = tonumber(rows[i].feed_id),
            adTitle = rows[i].feed_title,
            adAuthor = rows[i].author_name,
            adOwnerIdentifier = rows[i].ad_owner_identifier,
            guestName = rows[i].guest_name,
            guestIdentifier = rows[i].guest_identifier,
            updatedAt = formatTimestamp(rows[i].updated_at),
            lastMessage = rows[i].last_body,
            lastMessageAt = formatTimestamp(rows[i].last_message_at),
            messageCount = tonumber(rows[i].message_count) or 0,
        }
    end

    teamRespond(src, requestId, {
        ok = true,
        feed = {
            id = tonumber(feed.id),
            title = feed.title,
            author = feed.author_name,
        },
        conversations = conversations,
    })
end

function LiBridgeServerMessages.TeamListConversationMessages(src, requestId, conversationId)
    conversationId = tonumber(conversationId)
    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    if not conversationId then
        teamRespond(src, requestId, { ok = false, error = 'invalid_conversation' })
        return
    end

    local conversation = fetchConversation(conversationId)
    if not conversation then
        teamRespond(src, requestId, { ok = false, error = 'conversation_not_found' })
        return
    end

    local rows = LiBridge.MySQL.QuerySync(
        [[SELECT id, conversation_id, sender_identifier, body, created_at
          FROM lifeinvader_messages
          WHERE conversation_id = ?
          ORDER BY id ASC
          LIMIT 500]],
        { conversationId }
    )

    local messages = {}
    for i = 1, #rows do
        local senderId = rows[i].sender_identifier
        local senderLabel = senderId == conversation.ad_owner_identifier
            and (conversation.author_name or 'Inserent')
            or (conversation.guest_name or 'Interessent')

        messages[#messages + 1] = {
            id = tonumber(rows[i].id),
            senderIdentifier = senderId,
            senderLabel = senderLabel,
            isOwner = senderId == conversation.ad_owner_identifier,
            body = rows[i].body,
            createdAt = formatTimestamp(rows[i].created_at),
        }
    end

    teamRespond(src, requestId, {
        ok = true,
        conversation = {
            id = tonumber(conversation.id),
            feedId = tonumber(conversation.feed_id),
            adTitle = conversation.feed_title,
            adAuthor = conversation.author_name,
            adOwnerIdentifier = conversation.ad_owner_identifier,
            guestName = conversation.guest_name,
            guestIdentifier = conversation.guest_identifier,
        },
        messages = messages,
    })
end

local TEAM_CONVERSATION_SELECT = [[SELECT c.id, c.feed_id, c.ad_owner_identifier, c.guest_identifier, c.guest_name,
                 c.updated_at, f.title AS feed_title, f.author_name, f.phone, f.anonymous, f.status AS feed_status,
                 (SELECT m.body FROM lifeinvader_messages m
                  WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_body,
                 (SELECT m.created_at FROM lifeinvader_messages m
                  WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message_at,
                 (SELECT COUNT(*) FROM lifeinvader_messages m WHERE m.conversation_id = c.id) AS message_count
          FROM lifeinvader_conversations c
          INNER JOIN lifeinvader_feeds f ON f.id = c.feed_id]]

local function mapTeamConversationRow(row)
    return {
        id = tonumber(row.id),
        feedId = tonumber(row.feed_id),
        adTitle = row.feed_title,
        adAuthor = row.author_name,
        adOwnerIdentifier = row.ad_owner_identifier,
        guestName = row.guest_name,
        guestIdentifier = row.guest_identifier,
        feedStatus = row.feed_status,
        updatedAt = formatTimestamp(row.updated_at),
        lastMessage = row.last_body,
        lastMessageAt = formatTimestamp(row.last_message_at),
        messageCount = tonumber(row.message_count) or 0,
    }
end

function LiBridgeServerMessages.TeamListConversations(src, requestId, filters)
    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    filters = type(filters) == 'table' and filters or {}
    local feedId = tonumber(filters.feedId)
    local identifier = type(filters.identifier) == 'string' and filters.identifier:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local search = type(filters.search) == 'string' and filters.search:gsub('^%s+', ''):gsub('%s+$', '') or ''

    local sql = TEAM_CONVERSATION_SELECT .. ' WHERE 1=1'
    local params = {}

    if feedId then
        sql = sql .. ' AND c.feed_id = ?'
        params[#params + 1] = feedId
    end

    if identifier ~= '' then
        sql = sql .. ' AND (c.ad_owner_identifier = ? OR c.guest_identifier = ?)'
        params[#params + 1] = identifier
        params[#params + 1] = identifier
    end

    if search ~= '' then
        local like = '%' .. search .. '%'
        sql = sql .. [[ AND (
            f.title LIKE ?
            OR f.author_name LIKE ?
            OR c.guest_name LIKE ?
            OR c.ad_owner_identifier LIKE ?
            OR c.guest_identifier LIKE ?
            OR CAST(c.feed_id AS CHAR) LIKE ?
        )]]
        for _ = 1, 6 do
            params[#params + 1] = like
        end
    end

    sql = sql .. ' ORDER BY c.updated_at DESC LIMIT 150'

    local rows = LiBridge.MySQL.QuerySync(sql, params)
    local conversations = {}
    for i = 1, #rows do
        conversations[#conversations + 1] = mapTeamConversationRow(rows[i])
    end

    teamRespond(src, requestId, {
        ok = true,
        conversations = conversations,
    })
end

RegisterNetEvent('ec_lifeinvader:server:messagesOpenChat', function(requestId, feedId)
    LiBridgeServerMessages.OpenChat(source, requestId, feedId)
end)

RegisterNetEvent('ec_lifeinvader:server:messagesListInbox', function(requestId)
    LiBridgeServerMessages.ListInbox(source, requestId)
end)

RegisterNetEvent('ec_lifeinvader:server:messagesList', function(requestId, conversationId)
    LiBridgeServerMessages.ListMessages(source, requestId, conversationId)
end)

RegisterNetEvent('ec_lifeinvader:server:messagesSend', function(requestId, conversationId, body)
    LiBridgeServerMessages.SendMessage(source, requestId, conversationId, body)
end)

RegisterNetEvent('ec_lifeinvader:server:teamListAdConversations', function(requestId, feedId)
    LiBridgeServerMessages.TeamListFeedConversations(source, requestId, feedId)
end)

RegisterNetEvent('ec_lifeinvader:server:teamListConversations', function(requestId, filters)
    LiBridgeServerMessages.TeamListConversations(source, requestId, filters)
end)

RegisterNetEvent('ec_lifeinvader:server:teamListConversationMessages', function(requestId, conversationId)
    LiBridgeServerMessages.TeamListConversationMessages(source, requestId, conversationId)
end)
