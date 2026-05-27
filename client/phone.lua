--[[ ec_lifeinvader — Phone bridge (Feed: Anrufen / Nachricht) ]]

EcLifeInvader = EcLifeInvader or {}

local function phoneCfg()
    return Config.PhoneActions or {}
end

local function providerName()
    return string.lower(tostring(phoneCfg().provider or 'none'))
end

local function resourceStarted(name)
    return type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started'
end

local function notify(message, notifyType)
    if LiBridge and LiBridge.Client and LiBridge.Client.Notify then
        LiBridge.Client.Notify(message, notifyType or 'inform')
    end
end

local function normalizePhone(phone)
    return tostring(phone or ''):gsub('%s+', '')
end

local function dispatchCustom(actionType, payload, cfg)
    local eventName = actionType == 'call' and cfg.callClientEvent or cfg.smsClientEvent
    if type(eventName) ~= 'string' or eventName == '' then
        return false
    end

    TriggerEvent(eventName, payload)
    return true
end

local function dispatchGcPhone(actionType, payload)
    local phone = normalizePhone(payload.phone)
    if phone == '' then
        return false
    end

    if actionType == 'call' then
        TriggerEvent('gcphone:autoCall', phone, { lifeinvader = true })
        return true
    end

    local message = tostring(payload.message or '')
    if message == '' then
        message = phoneCfg().defaultMessageTemplate and phoneCfg().defaultMessageTemplate:format(payload.name or 'Unbekannt') or ''
    end

    TriggerServerEvent('gcPhone:sendMessage', phone, message)
    return true
end

local function dispatchRoadPhone(actionType, payload)
    if not resourceStarted('roadphone') then
        return false
    end

    local phone = normalizePhone(payload.phone)
    if phone == '' then
        return false
    end

    if actionType == 'call' then
        exports['roadphone']:startCall(phone, false)
        return true
    end

    local message = tostring(payload.message or '')
    if message == '' then
        message = phoneCfg().defaultMessageTemplate and phoneCfg().defaultMessageTemplate:format(payload.name or 'Unbekannt') or ''
    end

    exports['roadphone']:sendMessage(phone, message)
    return true
end

local function dispatchZPhone(actionType, payload)
    if not lib or not lib.callback then
        notify('Z-Phone benötigt ox_lib auf dem Client.', 'error')
        return false
    end

    local phone = normalizePhone(payload.phone)
    if phone == '' then
        return false
    end

    if actionType == 'call' then
        lib.callback('z-phone:server:StartCall', false, function(_) end, {
            to_phone_number = phone,
        })
        return true
    end

    local message = tostring(payload.message or '')
    if message == '' then
        message = phoneCfg().defaultMessageTemplate and phoneCfg().defaultMessageTemplate:format(payload.name or 'Unbekannt') or ''
    end

    lib.callback('z-phone:server:StartOrContinueChatting', false, function(chat)
        if type(chat) ~= 'table' or not chat.conversationid then
            return
        end

        lib.callback('z-phone:server:SendChatting', false, function(_) end, {
            conversationid = chat.conversationid,
            to_citizenid = chat.citizenid,
            message = message,
            is_group = chat.is_group == 1 or chat.is_group == true,
            conversation_name = chat.conversation_name,
        })
    end, {
        phone_number = phone,
    })

    return true
end

local function dispatchPhoneAction(actionType, payload)
    local provider = providerName()
    local providers = phoneCfg().providers or {}
    local cfg = providers[provider]

    if provider == 'none' then
        notify(('Telefon: %s (Phone-Integration in config.lua aktivieren)'):format(normalizePhone(payload.phone)), 'inform')
        return false
    end

    if provider == 'custom' then
        if type(cfg) ~= 'table' then
            return false
        end
        return dispatchCustom(actionType, payload, cfg)
    end

    if provider == 'gcphone' then
        return dispatchGcPhone(actionType, payload)
    end

    if provider == 'z-phone' or provider == 'zphone' then
        return dispatchZPhone(actionType, payload)
    end

    if provider == 'roadphone' then
        return dispatchRoadPhone(actionType, payload)
    end

    if type(cfg) == 'table' and (cfg.smsClientEvent or cfg.callClientEvent) then
        return dispatchCustom(actionType, payload, cfg)
    end

    notify(('Unbekannter Phone-Provider: %s'):format(provider), 'error')
    return false
end

RegisterNetEvent('ec_lifeinvader:client:phoneSms', function(payload)
    dispatchPhoneAction('sms', payload or {})
end)

RegisterNetEvent('ec_lifeinvader:client:phoneCall', function(payload)
    dispatchPhoneAction('call', payload or {})
end)
