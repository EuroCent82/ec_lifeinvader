--[[ ec_lifeinvader — NUI open/close ]]

EcLifeInvader = EcLifeInvader or {}

local nuiOpen = false
local pendingDeposits = {}
local pendingContacts = {}
local pendingPostAds = {}
local pendingDeleteAds = {}
local pendingTeam = {}

RegisterNetEvent('ec_lifeinvader:client:openNui', function(payload)
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        player = payload.player,
        ads = payload.ads,
        history = payload.history,
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

RegisterNetEvent('ec_lifeinvader:client:contactResult', function(requestId, result)
    local cb = pendingContacts[requestId]
    if not cb then
        return
    end

    pendingContacts[requestId] = nil
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

registerTeamCallback('teamLookupAdDuration', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamLookupAdDuration', requestId, data.identifier)
end)

registerTeamCallback('teamGrantAdDuration', function(requestId, data)
    TriggerServerEvent('ec_lifeinvader:server:teamGrantAdDuration', requestId, data.identifier, data.amount)
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

RegisterNUICallback('contact', function(data, cb)
    local requestId = ('%s_%s'):format(GetGameTimer(), math.random(10000, 99999))
    pendingContacts[requestId] = cb
    TriggerServerEvent('ec_lifeinvader:server:contact', requestId, data or {})

    SetTimeout(15000, function()
        if pendingContacts[requestId] then
            pendingContacts[requestId]({ ok = false, error = 'timeout' })
            pendingContacts[requestId] = nil
        end
    end)
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
