--[[ ec_lifeinvader — Feed Notification Queue ]]

EcLifeInvader = EcLifeInvader or {}
EcLifeInvader.NotifyQueue = EcLifeInvader.NotifyQueue or {}

local queue = {}
local busy = false
local lastShownAt = 0

local function cfg()
    return Config.FeedNotifications or {}
end

local function notify(message)
    local c = cfg()
    local title = c.title or 'LifeInvader'

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
            local interval = tonumber(cfg().queueIntervalMs) or 3200
            local now = GetGameTimer()
            local waitFor = interval - (now - lastShownAt)
            if waitFor > 0 then
                Wait(waitFor)
            end

            local item = table.remove(queue, 1)
            if item then
                notify(item)
                lastShownAt = GetGameTimer()
            end
        end
        busy = false
    end)
end

function EcLifeInvader.NotifyQueue.Push(message)
    if cfg().enabled == false then
        return
    end
    if type(message) ~= 'string' or message == '' then
        return
    end
    queue[#queue + 1] = message
    processQueue()
end

RegisterNetEvent('ec_lifeinvader:client:feedPostedNotify', function(payload)
    if cfg().enabled == false then
        return
    end

    local excludeSource = payload and payload._excludeSource
    if excludeSource and tonumber(excludeSource) == GetPlayerServerId(PlayerId()) then
        return
    end

    local author = tostring((payload and payload.author) or 'Unbekannt')
    local title = tostring((payload and payload.title) or 'Neue Anzeige')
    local templates = cfg().templates or {}
    local picked = templates[1]

    if type(templates) == 'table' and #templates > 0 then
        picked = templates[math.random(1, #templates)]
    end

    if type(picked) ~= 'string' or picked == '' then
        picked = 'Neue Anzeige auf LifeInvader!'
    end

    local ok, text = pcall(function()
        local withAuthorAndTitle = picked:format(author, title)
        return withAuthorAndTitle
    end)

    if not ok or type(text) ~= 'string' then
        text = ('Neue Anzeige von %s: %s'):format(author, title)
    end

    EcLifeInvader.NotifyQueue.Push(text)
end)
