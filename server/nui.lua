--[[ ec_lifeinvader — NUI open payload (Spieler, Berechtigungen, Ticker, Feed) ]]

local function buildOpenPayload(source, feedData)
    local identifier = LiBridge.Server.GetIdentifier(source)
    local phone = LiBridgeServerInventory.GetPhoneNumber(source)
    local adminCfg = Config.Admin or {}

    return {
        player = {
            name = LiBridge.Server.GetCharacterName(source) or GetPlayerName(source) or 'Unbekannt',
            phone = phone or '',
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
    local feedData
    local accountRow
    local activeCount
    local unreadMessages
    local pending = 4

    local function tryFinish()
        pending = pending - 1
        if pending > 0 or not feedData or not accountRow or activeCount == nil or unreadMessages == nil then
            return
        end

        local payload = buildOpenPayload(src, feedData)
        payload.player.money = tonumber(accountRow.balance) or 0
        payload.adSlots = LiBridgeServerAdSlots.BuildSlotInfoFromAccount(accountRow, activeCount)
        payload.adSlotPolicy = LiBridgeServerAdSlots.BuildPolicyForUi()
        payload.adDurationPolicy = LiBridgeServerAdDuration.BuildPolicyForUi()
        payload.adDuration = LiBridgeServerAdDuration.BuildPlayerInfoFromAccount(accountRow)
        payload.myAds = feedData.myAds or {}
        payload.messagesUnreadCount = unreadMessages
        TriggerClientEvent('ec_lifeinvader:client:openNui', src, payload)
    end

    LiBridgeServerFeeds.LoadOpenData(identifier, function(data)
        feedData = data
        tryFinish()
    end)

    LiBridgeServerAccount.GetAccountRow(identifier, function(row)
        accountRow = row
        tryFinish()
    end)

    LiBridgeServerAdSlots.GetActiveAdCount(identifier, function(count)
        activeCount = count
        tryFinish()
    end)

    LiBridgeServerMessages.GetUnreadCount(identifier, function(count)
        unreadMessages = count
        tryFinish()
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
