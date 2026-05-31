--[[ ec_lifeinvader — Feed- & Nachrichten-Benachrichtigungen (GTA Feed / ESX Advanced) ]]

EcLifeInvader = EcLifeInvader or {}
EcLifeInvader.NotifyQueue = EcLifeInvader.NotifyQueue or {}

local queue = {}
local busy = false
local lastShownAt = 0

local function feedCfg()
    return Config.FeedNotifications or {}
end

local function messageNotifyCfg()
    return (Config.Messages or {}).notifications or {}
end

local function ensureTextureDict(textureDict)
    if type(textureDict) ~= 'string' or textureDict == '' then
        return false
    end

    if HasStreamedTextureDictLoaded(textureDict) then
        return true
    end

    RequestStreamedTextureDict(textureDict, false)
    local timeout = GetGameTimer() + 2500
    while not HasStreamedTextureDictLoaded(textureDict) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasStreamedTextureDictLoaded(textureDict)
end

function EcLifeInvader.ShowAdvancedNotification(options)
    options = type(options) == 'table' and options or {}

    local sender = tostring(options.sender or 'LifeInvader')
    local subject = tostring(options.subject or '')
    local message = tostring(options.message or '')
    local textureDict = tostring(options.textureDict or 'CHAR_LIFEINVADER')
    local iconType = tonumber(options.iconType) or 1
    local flash = options.flash == true
    local saveToBrief = options.saveToBrief ~= false
    local hudColorIndex = options.hudColorIndex

    if message == '' then
        return
    end

    if LiBridgeClientEsx and LiBridgeClientEsx.ShowAdvancedNotification then
        local ok = LiBridgeClientEsx.ShowAdvancedNotification(
            sender,
            subject,
            message,
            textureDict,
            iconType,
            flash,
            saveToBrief,
            hudColorIndex
        )
        if ok then
            return
        end
    end

    TriggerEvent(
        'esx:showAdvancedNotification',
        sender,
        subject,
        message,
        textureDict,
        iconType,
        flash,
        saveToBrief,
        hudColorIndex
    )
    if GetResourceState('es_extended') == 'started' then
        return
    end

    ensureTextureDict(textureDict)

    AddTextEntry('ecLiAdvNotify', message)
    BeginTextCommandThefeedPost('ecLiAdvNotify')
    if hudColorIndex then
        ThefeedSetNextPostBackgroundColor(hudColorIndex)
    end
    EndTextCommandThefeedPostMessagetext(textureDict, textureDict, false, iconType, sender, subject)
    EndTextCommandThefeedPostTicker(flash, saveToBrief)
end

local function notifySimple(message, title)
    title = title or feedCfg().title or 'LifeInvader'

    if LiBridge and LiBridge.Library and LiBridge.Library() == 'ox_lib' and lib and lib.notify then
        lib.notify({
            title = title,
            description = message,
            type = 'inform',
        })
        return
    end

    if LiBridgeClientEsx and LiBridgeClientEsx.Notify then
        LiBridgeClientEsx.Notify(('%s: %s'):format(title, message), 'inform')
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('%s: %s'):format(title, message))
    EndTextCommandThefeedPostTicker(false, false)
end

local function processQueue()
    if busy then
        return
    end
    busy = true

    CreateThread(function()
        while #queue > 0 do
            local interval = tonumber(feedCfg().queueIntervalMs) or tonumber(messageNotifyCfg().queueIntervalMs) or 3200
            local now = GetGameTimer()
            local waitFor = interval - (now - lastShownAt)
            if waitFor > 0 then
                Wait(waitFor)
            end

            local item = table.remove(queue, 1)
            if item then
                if item.kind == 'advanced' then
                    EcLifeInvader.ShowAdvancedNotification(item)
                else
                    notifySimple(item.message, item.title)
                end
                lastShownAt = GetGameTimer()
            end
        end
        busy = false
    end)
end

function EcLifeInvader.NotifyQueue.Push(message, title)
    if type(message) ~= 'string' or message == '' then
        return
    end
    queue[#queue + 1] = { kind = 'simple', message = message, title = title }
    processQueue()
end

function EcLifeInvader.NotifyQueue.PushAdvanced(options)
    if type(options) ~= 'table' or type(options.message) ~= 'string' or options.message == '' then
        return
    end
    queue[#queue + 1] = {
        kind = 'advanced',
        sender = options.sender,
        subject = options.subject,
        message = options.message,
        textureDict = options.textureDict,
        iconType = options.iconType,
        flash = options.flash,
        saveToBrief = options.saveToBrief,
        hudColorIndex = options.hudColorIndex,
    }
    processQueue()
end

local function resolveTemplate(templates, keys, fallback)
    for i = 1, #keys do
        local tpl = templates[keys[i]]
        if type(tpl) == 'string' and tpl ~= '' then
            return tpl
        end
    end
    return fallback
end

local function buildMessageNotificationText(payload)
    local cfg = messageNotifyCfg()
    local templates = cfg.templates or {}
    local notifyType = tostring(payload.type or 'owner_single'):lower()
    local adTitle = tostring(payload.adTitle or 'Anzeige')
    local unreadTotal = tonumber(payload.unreadTotal) or 1
    local customText = type(payload.text) == 'string' and payload.text:gsub('^%s+', ''):gsub('%s+$', '') or ''

    if notifyType == 'custom' and customText ~= '' then
        return customText
    end

    if notifyType == 'owner_multi' then
        local tpl = resolveTemplate(templates, { 'owner_multi' }, '%d ungelesene Nachrichten zu deinen Anzeigen.')
        return tpl:format(unreadTotal)
    end

    if notifyType == 'inquirer_multi' or notifyType == 'guest_multi' then
        local tpl = resolveTemplate(
            templates,
            { 'inquirer_multi', 'guest_multi' },
            '%d Antworten auf deine Anfragen.'
        )
        return tpl:format(unreadTotal)
    end

    if notifyType == 'inquirer_reply' or notifyType == 'guest_reply' then
        local tpl = resolveTemplate(
            templates,
            { 'inquirer_reply', 'guest_reply' },
            'Antwort auf „%s“. Der Inserent meldet sich.'
        )
        return tpl:format(adTitle)
    end

    local tpl = resolveTemplate(
        templates,
        { 'owner_single' },
        'Neuer Interessent zu „%s“.'
    )
    return tpl:format(adTitle)
end

function EcLifeInvader.ShowMessageNotification(payload)
    local cfg = messageNotifyCfg()
    if cfg.enabled == false then
        return
    end

    payload = type(payload) == 'table' and payload or {}
    local message = buildMessageNotificationText(payload)
    if message == '' then
        return
    end

    EcLifeInvader.NotifyQueue.PushAdvanced({
        sender = cfg.sender or 'LifeInvader',
        subject = cfg.subject or 'Neue Nachricht',
        message = message,
        textureDict = cfg.textureDict or 'CHAR_LIFEINVADER',
        iconType = cfg.iconType or 1,
        flash = cfg.flash == true,
        saveToBrief = cfg.saveToBrief ~= false,
    })
end

RegisterNetEvent('ec_lifeinvader:client:feedPostedNotify', function(payload)
    if feedCfg().enabled == false then
        return
    end

    local excludeSource = payload and payload._excludeSource
    if excludeSource and tonumber(excludeSource) == GetPlayerServerId(PlayerId()) then
        return
    end

    local author = tostring((payload and payload.author) or 'Unbekannt')
    local title = tostring((payload and payload.title) or 'Neue Anzeige')
    local templates = feedCfg().templates or {}
    local picked = templates[1]

    if type(templates) == 'table' and #templates > 0 then
        picked = templates[math.random(1, #templates)]
    end

    if type(picked) ~= 'string' or picked == '' then
        picked = 'Neue Anzeige auf LifeInvader!'
    end

    local ok, text = pcall(function()
        return picked:format(author, title)
    end)

    if not ok or type(text) ~= 'string' then
        text = ('Neue Anzeige von %s: %s'):format(author, title)
    end

    EcLifeInvader.NotifyQueue.Push(text)
end)

RegisterNetEvent('ec_lifeinvader:client:messageNotify', function(payload)
    EcLifeInvader.ShowMessageNotification(payload)
end)

CreateThread(function()
    local cfg = messageNotifyCfg()
    local command = cfg.testCommand
    if type(command) ~= 'string' or command == '' then
        return
    end

    RegisterCommand(command, function(_, args)
        local notifyType = tostring(args[1] or 'owner_single'):lower()
        local payload = {
            type = notifyType,
            adTitle = 'Sultan RS Vollgetunt',
        }

        if notifyType == 'custom' then
            payload.text = table.concat(args, ' ', 2)
        elseif notifyType == 'owner_multi' or notifyType == 'inquirer_multi' or notifyType == 'guest_multi' then
            payload.type = notifyType == 'guest_multi' and 'inquirer_multi' or notifyType
            payload.unreadTotal = tonumber(args[2]) or 3
        elseif notifyType == 'inquirer_reply' or notifyType == 'guest_reply' or notifyType == 'owner_single' then
            if notifyType == 'guest_reply' then
                payload.type = 'inquirer_reply'
            end
            if args[2] and args[2] ~= '' then
                payload.adTitle = table.concat(args, ' ', 2)
            end
        end

        EcLifeInvader.ShowMessageNotification(payload)
    end, false)

    TriggerEvent('chat:addSuggestion', '/' .. command, 'LifeInvader Nachrichten-Notify testen', {
        {
            name = 'type',
            help = 'owner_single | owner_multi | inquirer_reply | inquirer_multi | custom',
        },
        {
            name = 'count|text',
            help = 'Anzahl (multi) oder Anzeigentitel / Freitext (custom)',
        },
    })
end)
