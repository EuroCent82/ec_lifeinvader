--[[ ec_lifeinvader — NUI open payload (Spieler, Berechtigungen, Ticker, Feed) ]]

local function buildOpenPayload(source, feedData)
    local identifier = LiBridge.Server.GetIdentifier(source)
    local phone = LiBridgeServerInventory.GetPhoneNumber(source)
    local adminCfg = Config.Admin or {}

    return {
        player = {
            name = LiBridge.Server.GetCharacterName(source) or GetPlayerName(source) or 'Unbekannt',
            phone = phone or 'Keine Nummer',
            money = 0,
            identifier = identifier,
        },
        ads = feedData.ads or {},
        history = feedData.history or {},
        categories = feedData.categories or {},
        permissions = {
            team = LiBridge.Server.HasPermission(source, 'team'),
            admin = LiBridge.Server.HasPermission(source, 'admin'),
        },
        ticker = feedData.ticker or {},
        admin = {
            enabled = adminCfg.enabled ~= false,
            tabLabel = adminCfg.tabLabel or 'Team',
            features = adminCfg.features or {},
        },
        uiConfig = LiBridgeServerFeeds.BuildUiConfig(),
        adSlotPolicy = LiBridgeServerAdSlots.BuildPolicyForUi(),
        lang = LiLocales.GetLanguage(),
        locale = LiLocales.GetUiTable(),
    }
end

local function canOpenTablet(src)
    if LiBridge.Server.HasPermission(src, 'open') then
        return true
    end
    if LiBridge.Server.HasPermission(src, 'team') then
        return true
    end
    if LiBridge.Server.HasPermission(src, 'teamOpen') then
        return true
    end
    return false
end

local function teamBypassesBlacklist(src)
    local cfg = Config.Blacklist or {}
    if cfg.teamBypass == false then
        return false
    end
    return LiBridge.Server.HasPermission(src, 'team')
end

local function openPlayerNui(src)
    local identifier = LiBridge.Server.GetIdentifier(src)

    LiBridgeServerFeeds.LoadOpenData(identifier, function(feedData)
        local payload = buildOpenPayload(src, feedData)

        LiBridgeServerAccount.GetBalance(identifier, function(balance)
            payload.player.money = balance

            LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, function(slotInfo)
                payload.adSlots = slotInfo
                payload.adSlotPolicy = LiBridgeServerAdSlots.BuildPolicyForUi()
                payload.adDurationPolicy = LiBridgeServerAdDuration.BuildPolicyForUi()

                LiBridgeServerAdDuration.GetPlayerInfo(identifier, function(durationInfo)
                    payload.adDuration = durationInfo
                    TriggerClientEvent('ec_lifeinvader:client:openNui', src, payload)
                end)
            end)
        end)
    end)
end

local function tryOpenTablet(src)
    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        return
    end

    LiBridgeServerBlacklist.IsBanned(identifier, function(banned, banInfo)
        if banned and not teamBypassesBlacklist(src) then
            TriggerClientEvent('ec_lifeinvader:client:openBlocked', src, banInfo or {})
            return
        end

        openPlayerNui(src)
    end)
end

RegisterNetEvent('ec_lifeinvader:server:requestOpen', function(_locationId)
    local src = source

    if not canOpenTablet(src) then
        return
    end

    tryOpenTablet(src)
end)

RegisterNetEvent('ec_lifeinvader:server:teamRemoteOpen', function()
    local src = source
    local cfg = Config.TeamRemoteOpen or {}

    if cfg.enabled == false then
        return
    end

    if not LiBridge.Server.HasPermission(src, 'teamOpen') and not LiBridge.Server.HasPermission(src, 'team') then
        return
    end

    if not canOpenTablet(src) then
        return
    end

    tryOpenTablet(src)
end)
