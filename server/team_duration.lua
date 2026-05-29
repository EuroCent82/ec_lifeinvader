--[[ ec_lifeinvader — Team: Anzeigen-Laufzeit (Tage) ]]

local function durationEnabled()
    local cfg = Config.AdDuration or {}
    return cfg.teamCanAdjust ~= false
end

RegisterNetEvent('ec_lifeinvader:server:teamLookupAdDuration', function(requestId, targetIdentifier)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'adDuration') then
        return
    end

    if not durationEnabled() then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    targetIdentifier = LiBridgeServerTeam.TrimIdentifier(targetIdentifier)
    if targetIdentifier == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    LiBridgeServerAdDuration.GetPlayerInfo(targetIdentifier, function(info)
        LiBridgeServerTeam.Respond(src, requestId, {
            ok = true,
            identifier = targetIdentifier,
            duration = info,
            policy = LiBridgeServerAdDuration.BuildPolicyForUi(),
        })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamGrantAdDuration', function(requestId, targetIdentifier, amount)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'adDuration') then
        return
    end

    if not durationEnabled() then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    targetIdentifier = LiBridgeServerTeam.TrimIdentifier(targetIdentifier)
    if targetIdentifier == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_amount' })
        return
    end

    local allowed = false
    for _, option in ipairs((Config.AdDuration or {}).teamGrantOptions or { 7 }) do
        if math.floor(tonumber(option) or 0) == amount then
            allowed = true
            break
        end
    end

    if not allowed then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_grant_option' })
        return
    end

    LiBridgeServerAdDuration.AddBonusDays(targetIdentifier, amount, function(ok, reason, info)
        if not ok then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = reason or 'db_failed' })
            return
        end

        LiBridgeServerTeam.Respond(src, requestId, {
            ok = true,
            identifier = targetIdentifier,
            granted = amount,
            duration = info,
        })
    end)
end)
