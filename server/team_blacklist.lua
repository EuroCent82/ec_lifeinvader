--[[ ec_lifeinvader — Team: Blacklist ]]

RegisterNetEvent('ec_lifeinvader:server:teamListBlacklist', function(requestId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'blacklist') then
        return
    end

    if not LiBridgeServerBlacklist.IsEnabled() then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    LiBridgeServerBlacklist.ListActive(function(entries)
        LiBridgeServerTeam.Respond(src, requestId, { ok = true, entries = entries })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamBanPlayer', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'blacklist') then
        return
    end

    if not LiBridgeServerBlacklist.IsEnabled() then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    data = data or {}
    local identifier = LiBridgeServerTeam.TrimIdentifier(data.identifier)
    if identifier == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    local bannedBy = LiBridge.Server.GetIdentifier(src) or 'team'
    local days = data.days
    if days == false or days == '' then
        days = nil
    end

    LiBridgeServerBlacklist.Ban(identifier, days, data.reason, bannedBy, function(ok, err, entry)
        if not ok then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = err or 'db_failed' })
            return
        end

        LiBridgeServerTeam.Respond(src, requestId, { ok = true, entry = entry })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamUnbanPlayer', function(requestId, identifier)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'blacklist') then
        return
    end

    identifier = LiBridgeServerTeam.TrimIdentifier(identifier)
    if identifier == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    LiBridgeServerBlacklist.Unban(identifier, function(ok, err)
        if not ok then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = err or 'not_found' })
            return
        end

        LiBridgeServerTeam.Respond(src, requestId, { ok = true })
    end)
end)
