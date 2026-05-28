--[[ ec_lifeinvader — Team: zusätzliche Anzeigen-Slots vergeben ]]

local function teamSlotsEnabled()
    local cfg = Config.AdSlots or {}
    return cfg.teamCanAdjust ~= false
end

local function teamFeatureEnabled()
    local features = (Config.Admin or {}).features or {}
    return features.adSlots ~= false
end

local function respondGrant(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:teamGrantAdSlotsResult', src, requestId, payload)
end

RegisterNetEvent('ec_lifeinvader:server:teamLookupAdSlots', function(requestId, targetIdentifier)
    local src = source

    if not teamSlotsEnabled() or not teamFeatureEnabled() then
        respondGrant(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    if not LiBridge.Server.HasPermission(src, 'team') then
        respondGrant(src, requestId, { ok = false, error = 'no_permission' })
        return
    end

    targetIdentifier = tostring(targetIdentifier or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if targetIdentifier == '' then
        respondGrant(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    LiBridgeServerAdSlots.GetPlayerAdSlotInfo(targetIdentifier, function(info)
        respondGrant(src, requestId, {
            ok = true,
            identifier = targetIdentifier,
            slots = info,
            policy = LiBridgeServerAdSlots.BuildPolicyForUi(),
        })
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamGrantAdSlots', function(requestId, targetIdentifier, amount)
    local src = source

    if not teamSlotsEnabled() or not teamFeatureEnabled() then
        respondGrant(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    if not LiBridge.Server.HasPermission(src, 'team') then
        respondGrant(src, requestId, { ok = false, error = 'no_permission' })
        return
    end

    targetIdentifier = tostring(targetIdentifier or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if targetIdentifier == '' then
        respondGrant(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        respondGrant(src, requestId, { ok = false, error = 'invalid_amount' })
        return
    end

    local allowed = false
    for _, option in ipairs((Config.AdSlots or {}).teamGrantOptions or { 1, 8 }) do
        if math.floor(tonumber(option) or 0) == amount then
            allowed = true
            break
        end
    end

    if not allowed then
        respondGrant(src, requestId, { ok = false, error = 'invalid_grant_option' })
        return
    end

    LiBridgeServerAdSlots.AddBonusSlots(targetIdentifier, amount, function(ok, reason, info)
        if not ok then
            respondGrant(src, requestId, { ok = false, error = reason or 'db_failed' })
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

        respondGrant(src, requestId, {
            ok = true,
            identifier = targetIdentifier,
            granted = amount,
            slots = info,
        })
    end)
end)
