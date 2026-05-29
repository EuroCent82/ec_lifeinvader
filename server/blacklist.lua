--[[ ec_lifeinvader — Blacklist (Sperre LifeInvader-Zugang) ]]

LiBridgeServerBlacklist = LiBridgeServerBlacklist or {}

local function blacklistConfig()
    return Config.Blacklist or {}
end

function LiBridgeServerBlacklist.IsEnabled()
    return blacklistConfig().enabled ~= false
end

local function rowIsActive(row)
    if not row then
        return false
    end

    local expiresAt = row.expires_at
    if expiresAt == nil or expiresAt == '' then
        return true
    end

    if type(expiresAt) == 'number' then
        local unix = expiresAt
        if unix > 1e12 then
            unix = math.floor(unix / 1000)
        end
        return unix > os.time()
    end

    local text = tostring(expiresAt)
    local y, m, d, h, min, sec = text:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)')
    if not y then
        y, m, d, h, min = text:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+)')
        sec = 0
    end

    if not y then
        return true
    end

    local expiresUnix = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(h),
        min = tonumber(min),
        sec = tonumber(sec) or 0,
    })

    return expiresUnix and expiresUnix > os.time()
end

function LiBridgeServerBlacklist.MapRow(row)
    if not row then
        return nil
    end

    local permanent = row.expires_at == nil or row.expires_at == ''
    return {
        id = tonumber(row.id),
        identifier = row.identifier,
        reason = row.reason,
        bannedBy = row.banned_by,
        expiresAt = row.expires_at,
        createdAt = row.created_at,
        permanent = permanent,
        active = rowIsActive(row),
    }
end

function LiBridgeServerBlacklist.IsBanned(identifier, cb)
    if not LiBridgeServerBlacklist.IsEnabled() then
        cb(false, nil)
        return
    end

    identifier = LiBridgeServerTeam.TrimIdentifier(identifier)
    if identifier == '' then
        cb(false, nil)
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, identifier, reason, banned_by, expires_at, created_at
          FROM lifeinvader_blacklist
          WHERE identifier = ?
          LIMIT 1]],
        { identifier },
        function(rows)
            local row = rows and rows[1]
            if not row or not rowIsActive(row) then
                cb(false, nil)
                return
            end

            cb(true, LiBridgeServerBlacklist.MapRow(row))
        end
    )
end

function LiBridgeServerBlacklist.ListActive(cb)
    if not LiBridgeServerBlacklist.IsEnabled() then
        cb({})
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, identifier, reason, banned_by, expires_at, created_at
          FROM lifeinvader_blacklist
          ORDER BY id DESC
          LIMIT 100]],
        {},
        function(rows)
            local entries = {}
            for _, row in ipairs(rows or {}) do
                if rowIsActive(row) then
                    entries[#entries + 1] = LiBridgeServerBlacklist.MapRow(row)
                end
            end
            cb(entries)
        end
    )
end

function LiBridgeServerBlacklist.Ban(identifier, days, reason, bannedBy, cb)
    if not LiBridgeServerBlacklist.IsEnabled() then
        if cb then
            cb(false, 'feature_disabled')
        end
        return
    end

    identifier = LiBridgeServerTeam.TrimIdentifier(identifier)
    if identifier == '' then
        if cb then
            cb(false, 'invalid_identifier')
        end
        return
    end

    local cfg = blacklistConfig()
    local maxDays = math.max(1, math.floor(tonumber(cfg.maxDays) or 30))
    local expiresAt = nil

    days = tonumber(days)
    if days and days > 0 then
        days = math.floor(days)
        if days < 1 or days > maxDays then
            if cb then
                cb(false, 'invalid_duration')
            end
            return
        end
        expiresAt = ('DATE_ADD(NOW(), INTERVAL %d DAY)'):format(days)
    end

    reason = tostring(reason or ''):sub(1, 255)
    if reason == '' then
        reason = nil
    end

    bannedBy = bannedBy or 'team'

    local sql
    local params
    if expiresAt then
        sql = [[INSERT INTO lifeinvader_blacklist (identifier, reason, banned_by, expires_at)
               VALUES (?, ?, ?, ]] .. expiresAt .. [[)
               ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), expires_at = VALUES(expires_at), created_at = CURRENT_TIMESTAMP]]
        params = { identifier, reason, bannedBy }
    else
        sql = [[INSERT INTO lifeinvader_blacklist (identifier, reason, banned_by, expires_at)
               VALUES (?, ?, ?, NULL)
               ON DUPLICATE KEY UPDATE reason = VALUES(reason), banned_by = VALUES(banned_by), expires_at = NULL, created_at = CURRENT_TIMESTAMP]]
        params = { identifier, reason, bannedBy }
    end

    LiBridge.MySQL.Execute(sql, params, function(affected)
        local rows = tonumber(affected) or 0
        if rows <= 0 then
            if cb then
                cb(false, 'db_failed')
            end
            return
        end

        LiBridgeServerBlacklist.IsBanned(identifier, function(_, entry)
            if cb then
                cb(true, nil, entry)
            end
        end)
    end)
end

function LiBridgeServerBlacklist.Unban(identifier, cb)
    identifier = LiBridgeServerTeam.TrimIdentifier(identifier)
    if identifier == '' then
        if cb then
            cb(false, 'invalid_identifier')
        end
        return
    end

    LiBridge.MySQL.Execute(
        'DELETE FROM lifeinvader_blacklist WHERE identifier = ?',
        { identifier },
        function(affected)
            local rows = tonumber(affected) or 0
            if cb then
                cb(rows > 0, rows > 0 and nil or 'not_found')
            end
        end
    )
end
