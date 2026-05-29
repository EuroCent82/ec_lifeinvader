--[[ ec_lifeinvader — Team: zusätzliche Anzeigen-Slots vergeben ]]

local function teamSlotsEnabled()
    local cfg = Config.AdSlots or {}
    return cfg.teamCanAdjust ~= false
end

local function isAllowedOption(amount, optionKey, fallback)
    for _, option in ipairs((Config.AdSlots or {})[optionKey] or fallback) do
        if math.floor(tonumber(option) or 0) == amount then
            return true
        end
    end
    return false
end

RegisterNetEvent('ec_lifeinvader:server:teamLookupAdSlots', function(requestId, targetIdentifier)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'adSlots') then
        return
    end

    if not teamSlotsEnabled() then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    targetIdentifier = LiBridgeServerTeam.TrimIdentifier(targetIdentifier)
    if targetIdentifier == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    LiBridgeServerAdSlots.GetPlayerAdSlotInfo(targetIdentifier, function(info)
        LiBridgeServerTeam.Respond(src, requestId, {
            ok = true,
            identifier = targetIdentifier,
            slots = info,
            policy = LiBridgeServerAdSlots.BuildPolicyForUi(),
        })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamGrantAdSlots', function(requestId, targetIdentifier, amount)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'adSlots') then
        return
    end

    if not teamSlotsEnabled() then
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

    if not isAllowedOption(amount, 'teamGrantOptions', { 1, 8 }) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_grant_option' })
        return
    end

    LiBridgeServerAdSlots.AddBonusSlots(targetIdentifier, amount, function(ok, reason, info)
        if not ok then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = reason or 'db_failed' })
            return
        end

        local staffName = LiBridge.Server.GetCharacterName(src) or GetPlayerName(src) or 'Team'
        print(('^2[ec_lifeinvader]^0 %s'):format(_L(
            'team.slotGrantedLog',
            staffName,
            amount,
            targetIdentifier,
            info.max
        )))

        LiBridgeServerTeam.Respond(src, requestId, {
            ok = true,
            identifier = targetIdentifier,
            granted = amount,
            slots = info,
        })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamRemoveAdSlots', function(requestId, targetIdentifier, amount)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'adSlots') then
        return
    end

    if not teamSlotsEnabled() then
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

    if not isAllowedOption(amount, 'teamRemoveOptions', { 1, 8 }) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_grant_option' })
        return
    end

    LiBridgeServerAdSlots.RemoveBonusSlots(targetIdentifier, amount, function(ok, reason, info)
        if not ok then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = reason or 'db_failed' })
            return
        end

        LiBridgeServerTeam.Respond(src, requestId, {
            ok = true,
            identifier = targetIdentifier,
            removed = amount,
            slots = info,
        })
    end)
end)
