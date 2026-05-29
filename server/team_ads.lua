--[[ ec_lifeinvader — Team: Anzeigen-Moderation ]]

local FEED_SELECT = [[SELECT id, identifier, author_name, title, content, category, phone, anonymous,
    premium, duration_hours, price_paid, status, created_at, expires_at, spotlight_until
    FROM lifeinvader_feeds]]

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

        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader_feeds SET status = ? WHERE id = ?',
            { status, adId },
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
