--[[ ec_lifeinvader — Team-Panel: gemeinsame Hilfen ]]

LiBridgeServerTeam = LiBridgeServerTeam or {}

--- featureKey (Guard/UI) → Config.Permissions-Schlüssel (nil = wie team)
local FEATURE_PERMISSION_KEYS = {
    categories = 'teamCategories',
    vouchers = 'teamVouchers',
    ticker = 'teamTicker',
    ads = 'teamAds',
    messages = 'teamMessages',
    refunds = 'teamRefunds',
    blacklist = 'teamBlacklist',
    adSlots = 'teamAdSlots',
    adDuration = 'teamAdDuration',
}

local UI_FEATURE_KEYS = {
    'categories',
    'vouchers',
    'ticker',
    'ads',
    'messages',
    'refunds',
    'blacklist',
    'adSlots',
    'adDuration',
}

function LiBridgeServerTeam.HasPermission(src)
    return LiBridge.Server.HasPermission(src, 'team')
end

function LiBridgeServerTeam.FeatureEnabled(featureKey)
    local features = (Config.Admin or {}).features or {}
    return features[featureKey] ~= false
end

function LiBridgeServerTeam.PermissionKeyForFeature(featureKey)
    return FEATURE_PERMISSION_KEYS[featureKey]
end

local function permissionRule(featureKey)
    local permKey = FEATURE_PERMISSION_KEYS[featureKey]
    if not permKey then
        return nil
    end
    return (Config.Permissions or {})[permKey]
end

local function hasExplicitPermission(src, permKey)
    if not permKey then
        return nil
    end

    local rule = (Config.Permissions or {})[permKey]
    if rule == nil then
        return nil
    end

    return LiBridge.Server.HasPermission(src, permKey)
end

function LiBridgeServerTeam.HasFeaturePermission(src, featureKey)
    if not LiBridgeServerTeam.HasPermission(src) then
        return false
    end

    if featureKey and not LiBridgeServerTeam.FeatureEnabled(featureKey) then
        return false
    end

    if featureKey == 'messages' and permissionRule('messages') == nil then
        return LiBridgeServerTeam.HasFeaturePermission(src, 'ads')
    end

    local permKey = FEATURE_PERMISSION_KEYS[featureKey]
    if permKey then
        local explicit = hasExplicitPermission(src, permKey)
        if explicit ~= nil then
            return explicit
        end
    end

    return true
end

function LiBridgeServerTeam.BuildFeatureAccessForUi(src)
    local cfgFeatures = (Config.Admin or {}).features or {}
    local access = {}

    for i = 1, #UI_FEATURE_KEYS do
        local key = UI_FEATURE_KEYS[i]
        if cfgFeatures[key] == false then
            access[key] = false
        else
            access[key] = LiBridgeServerTeam.HasFeaturePermission(src, key)
        end
    end

    return access
end

function LiBridgeServerTeam.HasAnyFeatureAccess(src)
    local access = LiBridgeServerTeam.BuildFeatureAccessForUi(src)
    for _, allowed in pairs(access) do
        if allowed then
            return true
        end
    end
    return false
end

function LiBridgeServerTeam.Respond(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:teamResult', src, requestId, payload)
end

function LiBridgeServerTeam.TrimIdentifier(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

function LiBridgeServerTeam.Guard(src, requestId, featureKey)
    if featureKey and not LiBridgeServerTeam.FeatureEnabled(featureKey) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return false
    end

    if featureKey then
        if not LiBridgeServerTeam.HasFeaturePermission(src, featureKey) then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'no_permission' })
            return false
        end
        return true
    end

    if not LiBridgeServerTeam.HasPermission(src) then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'no_permission' })
        return false
    end

    return true
end
