--[[ ec_lifeinvader — Client Bootstrap ]]

EcLifeInvader = EcLifeInvader or {}

local worldBootstrapCompleted = false
local lastWorldRespawnMs = -999999

local function debugPrint(...)
    LiBridge.Debug(...)
end

local function pedLooksSpawned()
    if not NetworkIsPlayerActive(PlayerId()) then
        return false
    end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    return GetEntityModel(ped) ~= 0
end

local function isWorldComplete()
    return EcLifeInvader.World
        and EcLifeInvader.World.IsWorldComplete
        and EcLifeInvader.World.IsWorldComplete()
end

local function scheduleWorldRetry(reason, delayMs)
    CreateThread(function()
        Wait(delayMs or 3000)
        if isWorldComplete() then
            return
        end
        debugPrint('Welt unvollständig — Retry:', tostring(reason))
        worldBootstrapCompleted = false
        tryWorldRespawn(reason, true)
        Wait(1500)
        if EcLifeInvader.World and EcLifeInvader.World.ReportToServer then
            EcLifeInvader.World.ReportToServer('retry_' .. tostring(reason))
        end
    end)
end

local function tryWorldRespawn(reason, forceBypassThrottle)
    if isWorldComplete() and reason ~= 'manual' then
        debugPrint('Welt-Respawn übersprungen (bereits vollständig):', tostring(reason))
        return false
    end

    local now = GetGameTimer()
    if not forceBypassThrottle and (now - lastWorldRespawnMs) < 1200 then
        return false
    end

    lastWorldRespawnMs = now
    if EcLifeInvader.World and EcLifeInvader.World.SpawnAll then
        EcLifeInvader.World.SpawnAll()
    end

    debugPrint('Welt-Respawn:', tostring(reason), '— vollständig:', tostring(isWorldComplete()))
    return true
end

local function runWorldBootstrap(reason)
    if worldBootstrapCompleted then
        return
    end

    if not pedLooksSpawned() then
        return
    end

    worldBootstrapCompleted = true
    debugPrint('Bootstrap Start —', tostring(reason))
    tryWorldRespawn(reason, true)
    scheduleWorldRetry('bootstrap_incomplete', 3000)
end

CreateThread(function()
    while not pedLooksSpawned() do
        Wait(250)
    end

    runWorldBootstrap('client_thread')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    worldBootstrapCompleted = false

    CreateThread(function()
        local attempts = 0
        while not pedLooksSpawned() and attempts < 80 do
            attempts = attempts + 1
            Wait(250)
        end
        runWorldBootstrap('onClientResourceStart')
    end)
end)

AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(500)
        tryWorldRespawn('playerSpawned', false)
    end)
end)

AddEventHandler('esx:playerLoaded', function()
    CreateThread(function()
        Wait(500)
        tryWorldRespawn('esx:playerLoaded', false)
    end)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(500)
        tryWorldRespawn('QBCore:Client:OnPlayerLoaded', false)
    end)
end)
