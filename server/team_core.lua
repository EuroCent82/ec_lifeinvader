--[[ ec_lifeinvader — Team-Panel: gemeinsame Hilfen ]]

LiBridgeServerTeam = LiBridgeServerTeam or {}

function LiBridgeServerTeam.HasPermission(src)
    return LiBridge.Server.HasPermission(src, 'team')
end

function LiBridgeServerTeam.FeatureEnabled(featureKey)
    local features = (Config.Admin or {}).features or {}
    return features[featureKey] ~= false
end

function LiBridgeServerTeam.Respond(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:teamResult', src, requestId, payload)
end

function LiBridgeServerTeam.TrimIdentifier(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

function LiBridgeServerTeam.Guard(src, requestId, featureKey)
    if not LiBridgeServerTeam.HasPermission(src) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'no_permission' })
        return false
    end

    if featureKey and not LiBridgeServerTeam.FeatureEnabled(featureKey) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return false
    end

    return true
end
