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

RegisterNetEvent('ec_lifeinvader:server:requestOpen', function(locationId)
    local src = source

    if not LiBridge.Server.HasPermission(src, 'open') then
        return
    end

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
end)
