--[[ ec_lifeinvader — NUI open/close ]]

EcLifeInvader = EcLifeInvader or {}

local nuiOpen = false
local pendingDeposits = {}
local pendingMessages = {}
local pendingPostAds = {}
local pendingDeleteAds = {}
local pendingTeam = {}

RegisterNetEvent('ec_lifeinvader:client:openBlocked', function(banInfo)
    banInfo = banInfo or {}
    local reason = banInfo.reason
    local message = 'Du bist von LifeInvader gesperrt.'
    if reason and reason ~= '' then
        message = message .. ' Grund: ' .. tostring(reason)
    end

    if LiBridge and LiBridge.Client and LiBridge.Client.Notify then
        LiBridge.Client.Notify(message, 'error')
    end
end)

RegisterNetEvent('ec_lifeinvader:client:openNui', function(payload)
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        player = payload.player,
        ads = payload.ads,
        history = payload.history,
        myAds = payload.myAds,
        categories = payload.categories,
        permissions = payload.permissions,
        ticker = payload.ticker,
        admin = payload.admin,
        uiConfig = payload.uiConfig,
        adSlots = payload.adSlots,
        adSlotPolicy = payload.adSlotPolicy,
        lang = payload.lang,
        locale = payload.locale,
    })
end)

RegisterNetEvent('ec_lifeinvader:client:depositResult', function(requestId, result)
    local cb = pendingDeposits[requestId]
    if not cb then
        return
    end

    pendingDeposits[requestId] = nil
    cb(result or { ok = false, error = 'empty_response' })
end)

RegisterNetEvent('ec_lifeinvader:client:messagesResult', function(requestId, result)
    local cb = pendingMessages[requestId]
    if not cb then
        return
    end

    pendingMessages[requestId] = nil
    cb(result or { ok = false, error = 'empty_response' })
end)

function EcLifeInvader.IsNuiOpen()
    return nuiOpen
end

function EcLifeInvader.Open(locationId)
    if nuiOpen then
        return
    end

    TriggerServerEvent('ec_lifeinvader:server:requestOpen', locationId or 'unknown')
end

function EcLifeInvader.Close()
    if not nuiOpen then
        return
    end

    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('deposit', function(data, cb)
    local amount = tonumber(data and data.amount) or 0
    local sourceType = data and data.source or 'bank'

    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingDeposits[requestId] = cb
    TriggerServerEvent('ec_lifeinvader:server:deposit', requestId, amount, sourceType)

    SetTimeout(15000, function()
        if pendingDeposits[requestId] then
            pendingDeposits[requestId]({ ok = false, error = 'timeout' })
            pendingDeposits[requestId] = nil
        end
    end)
end)

RegisterNetEvent('ec_lifeinvader:client:postAdResult', function(requestId, result)
    local cb = pendingPostAds[requestId]
    if not cb then
        return
    end

    pendingPostAds[requestId] = nil
    cb(result or { ok = false, error = 'empty_response' })
end)

RegisterNetEvent('ec_lifeinvader:client:deleteAdResult', function(requestId, result)
    local cb = pendingDeleteAds[requestId]
    if not cb then
        return
    end

    pendingDeleteAds[requestId] = nil
    cb(result or { ok = false, error = 'empty_response' })
end)

RegisterNUICallback('postAd', function(data, cb)
    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingPostAds[requestId] = cb
    TriggerServerEvent('ec_lifeinvader:server:postAd', requestId, data or {})

    SetTimeout(15000, function()
        if pendingPostAds[requestId] then
            pendingPostAds[requestId]({ ok = false, error = 'timeout' })
            pendingPostAds[requestId] = nil
        end
    end)
end)

RegisterNUICallback('deleteAd', function(data, cb)
    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingDeleteAds[requestId] = cb
    TriggerServerEvent('ec_lifeinvader:server:deleteAd', requestId, data and data.id)

    SetTimeout(15000, function()
        if pendingDeleteAds[requestId] then
            pendingDeleteAds[requestId]({ ok = false, error = 'timeout' })
            pendingDeleteAds[requestId] = nil
        end
    end)
end)

RegisterNetEvent('ec_lifeinvader:client:teamResult', function(requestId, result)
    local cb = pendingTeam[requestId]
    if not cb then
        return
    end

    pendingTeam[requestId] = nil
    cb(result or { ok = false, error = 'empty_response' })
end)

local function registerTeamCallback(name, triggerFn)
    RegisterNUICallback(name, function(data, cb)
        local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
        pendingTeam[requestId] = cb
        triggerFn(requestId, data or {})

        SetTimeout(15000, function()
            if pendingTeam[requestId] then
                pendingTeam[requestId]({ ok = false, error = 'timeout' })
                pendingTeam[requestId] = nil
            end
        end)
    end)
end

registerTeamCallback('teamSearchPlayers', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamSearchPlayers', requestId, data.query)
end)

registerTeamCallback('teamLookupAdSlots', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamLookupAdSlots', requestId, data.identifier)
end)

registerTeamCallback('teamGrantAdSlots', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamGrantAdSlots', requestId, data.identifier, data.amount)
end)

registerTeamCallback('teamRemoveAdSlots', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamRemoveAdSlots', requestId, data.identifier, data.amount)
end)

registerTeamCallback('teamLookupAdDuration', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamLookupAdDuration', requestId, data.identifier)
end)

registerTeamCallback('teamGrantAdDuration', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamGrantAdDuration', requestId, data.identifier, data.amount)
end)

registerTeamCallback('teamRemoveAdDuration', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamRemoveAdDuration', requestId, data.identifier, data.amount)
end)

registerTeamCallback('teamListVouchers', function(requestId)
    TriggerServerEvent('ec_lifeinvader:server:teamListVouchers', requestId)
end)

registerTeamCallback('teamCreateVoucher', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamCreateVoucher', requestId, data)
end)

registerTeamCallback('teamListCategories', function(requestId)
    TriggerServerEvent('ec_lifeinvader:server:teamListCategories', requestId)
end)

registerTeamCallback('teamSetCategoryEnabled', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamSetCategoryEnabled', requestId, data.id, data.enabled)
end)

registerTeamCallback('teamCreateCategory', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamCreateCategory', requestId, data)
end)

registerTeamCallback('teamUpdateCategory', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamUpdateCategory', requestId, data)
end)

registerTeamCallback('teamDeleteCategory', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamDeleteCategory', requestId, data.id)
end)

registerTeamCallback('teamReorderCategories', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamReorderCategories', requestId, data.order)
end)

registerTeamCallback('teamListTicker', function(requestId)
    TriggerServerEvent('ec_lifeinvader:server:teamListTicker', requestId)
end)

registerTeamCallback('teamCreateTicker', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamCreateTicker', requestId, data)
end)

registerTeamCallback('teamUpdateTicker', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamUpdateTicker', requestId, data)
end)

registerTeamCallback('teamDeleteTicker', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamDeleteTicker', requestId, data.id)
end)

registerTeamCallback('teamReorderTicker', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamReorderTicker', requestId, data.order)
end)

registerTeamCallback('teamListBlacklist', function(requestId)
    TriggerServerEvent('ec_lifeinvader:server:teamListBlacklist', requestId)
end)

registerTeamCallback('teamBanPlayer', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamBanPlayer', requestId, data)
end)

registerTeamCallback('teamUnbanPlayer', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamUnbanPlayer', requestId, data.identifier)
end)

registerTeamCallback('teamListAds', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamListAds', requestId, data.filters or {})
end)

registerTeamCallback('teamUpdateAd', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamUpdateAd', requestId, data.id, data.payload or {})
end)

registerTeamCallback('teamGetAdDetail', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamGetAdDetail', requestId, data.adId)
end)

registerTeamCallback('teamSaveAdFull', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamSaveAdFull', requestId, data.adId, data.payload or {})
end)

registerTeamCallback('teamSetAdStatus', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamSetAdStatus', requestId, data.id, data.status)
end)

registerTeamCallback('teamListRefunds', function(requestId)
    TriggerServerEvent('ec_lifeinvader:server:teamListRefunds', requestId)
end)

registerTeamCallback('teamLookupAdRefund', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamLookupAdRefund', requestId, data.feedId)
end)

registerTeamCallback('teamIssueRefund', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamIssueRefund', requestId, data)
end)

RegisterNUICallback('messagesOpenChat', function(data, cb)
    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingMessages[requestId] = cb
    TriggerServerEvent('ec_lifeinvader:server:messagesOpenChat', requestId, tonumber(data and data.feedId))
    SetTimeout(15000, function()
        if pendingMessages[requestId] then
            pendingMessages[requestId]({ ok = false, error = 'timeout' })
            pendingMessages[requestId] = nil
        end
    end)
end)

RegisterNUICallback('messagesListInbox', function(_, cb)
    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingMessages[requestId] = cb
    TriggerServerEvent('ec_lifeinvader:server:messagesListInbox', requestId)
    SetTimeout(15000, function()
        if pendingMessages[requestId] then
            pendingMessages[requestId]({ ok = false, error = 'timeout' })
            pendingMessages[requestId] = nil
        end
    end)
end)

RegisterNUICallback('messagesList', function(data, cb)
    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingMessages[requestId] = cb
    TriggerServerEvent('ec_lifeinvader:server:messagesList', requestId, tonumber(data and data.conversationId))
    SetTimeout(15000, function()
        if pendingMessages[requestId] then
            pendingMessages[requestId]({ ok = false, error = 'timeout' })
            pendingMessages[requestId] = nil
        end
    end)
end)

RegisterNUICallback('messagesSend', function(data, cb)
    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingMessages[requestId] = cb
    TriggerServerEvent(
        'ec_lifeinvader:server:messagesSend',
        requestId,
        tonumber(data and data.conversationId),
        data and data.body
    )
    SetTimeout(15000, function()
        if pendingMessages[requestId] then
            pendingMessages[requestId]({ ok = false, error = 'timeout' })
            pendingMessages[requestId] = nil
        end
    end)
end)

registerTeamCallback('teamListAdConversations', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamListAdConversations', requestId, data.feedId)
end)

registerTeamCallback('teamListConversations', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamListConversations', requestId, data or {})
end)

registerTeamCallback('teamListConversationMessages', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamListConversationMessages', requestId, data.conversationId)
end)

RegisterNUICallback('copyText', function(data, cb)
    if data and type(data.text) == 'string' and data.text ~= '' then
        SendNUIMessage({ action = 'copyText', text = data.text })
    end
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    EcLifeInvader.Close()
    cb('ok')
end)

RegisterNetEvent('ec_lifeinvader:client:openFromItem', function()
    EcLifeInvader.Open('item')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    if nuiOpen then
        SetNuiFocus(false, false)
    end
end)
