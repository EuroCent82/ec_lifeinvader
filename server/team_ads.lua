--[[ ec_lifeinvader — Team: Anzeigen-Moderation ]]

local FEED_SELECT = [[SELECT id, identifier, author_name, title, content, category, phone, anonymous,
    premium, duration_hours, price_paid, status, created_at, expires_at, spotlight_until,
    anonym_until, ticker_until, ticker_enabled
    FROM lifeinvader_feeds]]

local function findDurationById(durationId)
    for _, entry in ipairs(Config.Durations or {}) do
        if entry.id == durationId then
            return entry
        end
    end
    return nil
end

local function findDurationIdByHours(hours)
    hours = tonumber(hours) or 24
    for _, entry in ipairs(Config.Durations or {}) do
        if tonumber(entry.hours) == hours then
            return entry.id
        end
    end
    return (Config.Durations or {})[1] and (Config.Durations or {})[1].id or '24h'
end

local function adDaysMax(hours)
    return math.max(1, math.ceil((tonumber(hours) or 24) / 24))
end

local function anonymDaysMax(hours)
    local capHours = (Config.PremiumFeatures.anonym or {}).maxHours or 48
    local capDays = math.max(1, math.floor(capHours / 24))
    return math.min(adDaysMax(hours), capDays)
end

local function sqlIntervalDays(days)
    days = math.max(1, math.floor(tonumber(days) or 1))
    return ('DATE_ADD(NOW(), INTERVAL %d DAY)'):format(days)
end

local function buildPremiumJson(premium, hours)
    if type(premium) ~= 'table' then
        return nil
    end

    local encoded = {}
    local maxDays = adDaysMax(hours)

    if premium.spotlight and type(premium.spotlight.days) == 'number' then
        encoded.spotlight = { days = math.max(1, math.min(math.floor(premium.spotlight.days), maxDays)) }
    end
    if premium.anonym and type(premium.anonym.days) == 'number' then
        encoded.anonym = { days = math.max(1, math.min(math.floor(premium.anonym.days), anonymDaysMax(hours))) }
    end
    if premium.liveticker and type(premium.liveticker.days) == 'number' then
        encoded.liveticker = { days = math.max(1, math.min(math.floor(premium.liveticker.days), maxDays)) }
    end

    if next(encoded) == nil then
        return nil
    end

    return json.encode(encoded)
end

local function decodePremium(raw)
    if type(raw) == 'table' then
        return raw
    end
    if type(raw) == 'string' and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            return decoded
        end
    end
    return nil
end

local function mapAdDetail(row)
    local premium = decodePremium(row.premium)
    local hours = tonumber(row.duration_hours) or 24
    local history = LiBridgeServerFeeds.FormatHistoryRow(row)

    return {
        id = tonumber(row.id),
        livId = LiBridgeServerFeeds.FormatLivId(row.id),
        title = row.title,
        content = row.content,
        category = row.category,
        phone = row.phone or '',
        durationId = findDurationIdByHours(hours),
        durationHours = hours,
        anonymous = row.anonymous == 1 or row.anonymous == true,
        authorName = row.author_name,
        identifier = row.identifier,
        status = history.status,
        dbStatus = row.status,
        createdAtLabel = history.createdAtLabel,
        expiresAtLabel = history.expiresAtLabel,
        pricePaid = history.pricePaid,
        premium = {
            spotlight = premium and premium.spotlight or nil,
            anonym = premium and premium.anonym or nil,
            liveticker = premium and premium.liveticker or nil,
        },
        hasSpotlight = row.spotlight_until ~= nil,
        hasTicker = row.ticker_until ~= nil,
        tickerEnabled = row.ticker_enabled == 1 or row.ticker_enabled == true,
    }
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function mapTeamAd(row)
    local history = LiBridgeServerFeeds.FormatHistoryRow(row)
    history.identifier = row.identifier
    history.dbStatus = row.status
    return history
end

RegisterNetEvent('ec_lifeinvader:server:teamListAds', function(requestId, filters)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    filters = filters or {}
    local statusFilter = trim(filters.status or 'all')
    local search = trim(filters.search or '')
    local identifier = LiBridgeServerTeam.TrimIdentifier(filters.identifier or '')

    local sql = FEED_SELECT
    local params = {}
    local where = {}

    if identifier ~= '' then
        where[#where + 1] = 'identifier = ?'
        params[#params + 1] = identifier
    end

    if search ~= '' then
        local like = ('%%%s%%'):format(search:gsub('%%', ''))
        where[#where + 1] = '(title LIKE ? OR author_name LIKE ? OR CAST(id AS CHAR) LIKE ?)'
        params[#params + 1] = like
        params[#params + 1] = like
        params[#params + 1] = like
    end

    if statusFilter == 'blocked' then
        where[#where + 1] = "status = 'blocked'"
    elseif statusFilter == 'deleted' then
        where[#where + 1] = "status = 'deleted'"
    elseif statusFilter == 'active' then
        where[#where + 1] = "status = 'active' AND expires_at > NOW()"
    elseif statusFilter == 'expired' then
        where[#where + 1] = "status = 'active' AND expires_at <= NOW()"
    end

    if #where > 0 then
        sql = sql .. ' WHERE ' .. table.concat(where, ' AND ')
    end

    sql = sql .. ' ORDER BY id DESC LIMIT 80'

    LiBridge.MySQL.Query(sql, params, function(rows)
        local ads = {}
        for _, row in ipairs(rows or {}) do
            ads[#ads + 1] = mapTeamAd(row)
        end

        LiBridgeServerTeam.Respond(src, requestId, { ok = true, ads = ads })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamUpdateAd', function(requestId, adId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    adId = math.floor(tonumber(adId) or 0)
    if adId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    data = data or {}
    local title = trim(data.title)
    local content = trim(data.content)
    local category = trim(data.category)
    local phone = trim(data.phone)

    if title == '' or content == '' or category == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
        return
    end

    if #title > (Config.MaxTitleLength or 64) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'title_too_long' })
        return
    end

    if #content > (Config.MaxContentLength or 500) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'content_too_long' })
        return
    end

    LiBridge.MySQL.Query(FEED_SELECT .. ' WHERE id = ? LIMIT 1', { adId }, function(rows)
        local row = rows and rows[1]
        if not row then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
            return
        end

        if row.status == 'deleted' then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'ad_deleted' })
            return
        end

        LiBridge.MySQL.Execute(
            [[UPDATE lifeinvader_feeds
              SET title = ?, content = ?, category = ?, phone = ?
              WHERE id = ?]],
            { title, content, category, phone, adId },
            function(affected)
                if (tonumber(affected) or 0) <= 0 then
                    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                    return
                end

                row.title = title
                row.content = content
                row.category = category
                row.phone = phone

                LiBridgeServerTeam.Respond(src, requestId, { ok = true, ad = mapTeamAd(row) })
            end
        )
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamSetAdStatus', function(requestId, adId, status)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    adId = math.floor(tonumber(adId) or 0)
    status = trim(status)

    if adId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    if status ~= 'active' and status ~= 'blocked' and status ~= 'deleted' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_status' })
        return
    end

    LiBridge.MySQL.Query(FEED_SELECT .. ' WHERE id = ? LIMIT 1', { adId }, function(rows)
        local row = rows and rows[1]
        if not row then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
            return
        end

        if status == 'active' and row.status == 'deleted' then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'ad_deleted' })
            return
        end

        local sql = 'UPDATE lifeinvader_feeds SET status = ?'
        local params = { status }

        if status == 'blocked' then
            sql = sql .. ', ticker_enabled = 0'
        end

        sql = sql .. ' WHERE id = ?'
        params[#params + 1] = adId

        LiBridge.MySQL.Execute(
            sql,
            params,
            function(affected)
                if (tonumber(affected) or 0) <= 0 then
                    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                    return
                end

                row.status = status
                LiBridgeServerTeam.Respond(src, requestId, { ok = true, ad = mapTeamAd(row) })
            end
        )
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamGetAdDetail', function(requestId, adId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    adId = math.floor(tonumber(adId) or 0)
    if adId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    LiBridge.MySQL.Query(FEED_SELECT .. ' WHERE id = ? LIMIT 1', { adId }, function(rows)
        local row = rows and rows[1]
        if not row then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
            return
        end

        if row.status == 'deleted' then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'ad_deleted' })
            return
        end

        LiBridgeServerTeam.Respond(src, requestId, { ok = true, ad = mapAdDetail(row) })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamSaveAdFull', function(requestId, adId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ads') then
        return
    end

    adId = math.floor(tonumber(adId) or 0)
    if adId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    data = data or {}
    local title = trim(data.title)
    local content = trim(data.content)
    local category = trim(data.category)
    local phone = trim(data.phone)

    if title == '' or content == '' or category == '' or phone == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
        return
    end

    local duration = findDurationById(data.durationId)
    if not duration then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_duration' })
        return
    end

    local hours = tonumber(duration.hours) or 24
    local isAnonymous = data.anonymous == true
    local premium = data.premium or {}
    local premiumJson = buildPremiumJson(premium, hours)

    local spotlightSql = 'NULL'
    local anonymSql = 'NULL'
    local tickerSql = 'NULL'
    local tickerEnabled = 0

    if isAnonymous then
        anonymSql = ('DATE_ADD(NOW(), INTERVAL %d HOUR)'):format(hours)
    end

    if type(premium) == 'table' then
        if premium.spotlight and premium.spotlight.days then
            spotlightSql = sqlIntervalDays(premium.spotlight.days)
        end
        if premium.liveticker and premium.liveticker.days then
            tickerSql = sqlIntervalDays(premium.liveticker.days)
            tickerEnabled = 1
        end
    end

    LiBridge.MySQL.Query(FEED_SELECT .. ' WHERE id = ? LIMIT 1', { adId }, function(rows)
        local row = rows and rows[1]
        if not row then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
            return
        end

        if row.status == 'deleted' then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'ad_deleted' })
            return
        end

        if row.status == 'blocked' then
            tickerEnabled = 0
        end

        local sql = ([[UPDATE lifeinvader_feeds SET
            title = ?, content = ?, category = ?, phone = ?,
            anonymous = ?, duration_hours = ?, premium = ?,
            spotlight_until = %s, anonym_until = %s, ticker_until = %s,
            ticker_enabled = ?,
            expires_at = DATE_ADD(NOW(), INTERVAL %d HOUR)
            WHERE id = ?]]):format(spotlightSql, anonymSql, tickerSql, hours)

        LiBridge.MySQL.Execute(
            sql,
            {
                title,
                content,
                category,
                phone,
                isAnonymous and 1 or 0,
                hours,
                premiumJson,
                tickerEnabled,
                adId,
            },
            function(affected)
                if (tonumber(affected) or 0) <= 0 then
                    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                    return
                end

                LiBridge.MySQL.Query(FEED_SELECT .. ' WHERE id = ? LIMIT 1', { adId }, function(updated)
                    local updatedRow = updated and updated[1]
                    if not updatedRow then
                        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                        return
                    end

                    LiBridgeServerTeam.Respond(src, requestId, {
                        ok = true,
                        ad = mapTeamAd(updatedRow),
                        detail = mapAdDetail(updatedRow),
                    })
                end)
            end
        )
    end)
end)
