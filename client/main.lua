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

local function tryWorldRespawn(reason, forceBypassThrottle)
    local now = GetGameTimer()
    if not forceBypassThrottle and (now - lastWorldRespawnMs) < 1200 then
        return false
    end

    lastWorldRespawnMs = now
    if EcLifeInvader.World and EcLifeInvader.World.SpawnAll then
        EcLifeInvader.World.SpawnAll()
    end

    debugPrint('Welt-Respawn:', tostring(reason))
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
    if EcLifeInvader.World and EcLifeInvader.World.SpawnBlipsOnly then
        EcLifeInvader.World.SpawnBlipsOnly()
        debugPrint('Blip-Bootstrap Start — onClientResourceStart')
    end

    CreateThread(function()
        local attempts = 0
        while not pedLooksSpawned() and attempts < 80 do
            attempts = attempts + 1
            Wait(250)
        end
        runWorldBootstrap('onClientResourceStart')
    end)
end)

CreateThread(function()
    Wait(150)
    if EcLifeInvader.World and EcLifeInvader.World.SpawnBlipsOnly then
        EcLifeInvader.World.SpawnBlipsOnly()
        debugPrint('Blip-Bootstrap Start — early_thread')
    end
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
