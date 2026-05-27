LiBridgeServerPhone = LiBridgeServerPhone or {}

local function phoneCfg()
    return Config.PhoneActions or {}
end

local function providerName()
    return string.lower(tostring((phoneCfg().provider or 'none')))
end

local function providerCfg(provider)
    local providers = phoneCfg().providers or {}
    return providers[provider]
end

local function buildPayload(data)
    local name = tostring(data.name or 'Unbekannt')
    local phone = tostring(data.phone or '')
    local template = tostring((phoneCfg().defaultMessageTemplate or ''))

    return {
        phone = phone,
        name = name,
        message = template ~= '' and template:format(name) or '',
    }
end

local function resourceStarted(name)
    return type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started'
end

local function validateProvider(provider)
    if provider == 'none' then
        return false, 'phone_not_configured'
    end

    local cfg = providerCfg(provider)
    if provider ~= 'gcphone' and provider ~= 'z-phone' and provider ~= 'zphone' and type(cfg) ~= 'table' then
        return false, 'provider_missing'
    end

    local resource = cfg and cfg.resource
    if type(resource) == 'string' and resource ~= '' and not resourceStarted(resource) then
        return false, 'phone_resource_offline'
    end

    return true, nil
end

local function dispatchServerExport(source, actionType, payload, provider)
    local fromNumber = LiBridgeServerInventory.GetPhoneNumber(source) or ''
    local toNumber = tostring(payload.phone or '')

    if toNumber == '' then
        return false, 'phone_missing'
    end

    if provider == 'lsfive-phone' or provider == 'lsfivephone' then
        if actionType ~= 'sms' then
            TriggerClientEvent('ec_lifeinvader:client:phoneCall', source, payload)
            return true, nil
        end

        if not resourceStarted('lsfive-phone') then
            return false, 'phone_resource_offline'
        end

        exports['lsfive-phone']:SendSMS(fromNumber, toNumber, payload.message)
        return true, nil
    end

    if provider == 'lb-phone' or provider == 'lbphone' then
        if not resourceStarted('lb-phone') then
            return false, 'phone_resource_offline'
        end

        if actionType == 'call' then
            exports['lb-phone']:CreateCall({
                source = source,
                phoneNumber = fromNumber,
            }, toNumber, {
                requirePhone = false,
            })
            return true, nil
        end

        exports['lb-phone']:SendMessage(fromNumber, toNumber, payload.message)
        return true, nil
    end

    return false, 'provider_missing'
end

local function dispatchPhoneAction(source, actionType, payload)
    local provider = providerName()
    local ok, err = validateProvider(provider)
    if not ok then
        return false, err
    end

    if provider == 'lsfive-phone' or provider == 'lsfivephone' or provider == 'lb-phone' or provider == 'lbphone' then
        return dispatchServerExport(source, actionType, payload, provider)
    end

    if provider == 'custom' then
        local cfg = providerCfg(provider)
        local eventName = actionType == 'call' and cfg.callClientEvent or cfg.smsClientEvent
        if type(eventName) ~= 'string' or eventName == '' then
            return false, 'phone_event_missing'
        end

        TriggerClientEvent(eventName, source, payload)
        return true, nil
    end

    local clientEvent = actionType == 'call' and 'ec_lifeinvader:client:phoneCall' or 'ec_lifeinvader:client:phoneSms'
    TriggerClientEvent(clientEvent, source, payload)
    return true, nil
end

RegisterNetEvent('ec_lifeinvader:server:contact', function(requestId, data)
    local src = source

    local payload = buildPayload(data or {})
    if payload.phone == '' then
        TriggerClientEvent('ec_lifeinvader:client:contactResult', src, requestId, {
            ok = false,
            error = 'phone_missing',
        })
        return
    end

    local actionType = tostring((data and data.type) or 'sms')
    if actionType ~= 'sms' and actionType ~= 'call' then
        actionType = 'sms'
    end

    local ok, err = dispatchPhoneAction(src, actionType, payload)
    TriggerClientEvent('ec_lifeinvader:client:contactResult', src, requestId, {
        ok = ok,
        error = err,
        action = actionType,
    })
end)
