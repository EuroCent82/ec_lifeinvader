--[[ ec_lifeinvader — Client Bootstrap (einmaliger Welt-Spawn wie v1.0) ]]

EcLifeInvader = EcLifeInvader or {}

local worldBootstrapCompleted = false

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

local function runWorldBootstrap(reason)
    if worldBootstrapCompleted then
        return
    end

    if not pedLooksSpawned() then
        return
    end

    worldBootstrapCompleted = true
    debugPrint('Bootstrap —', tostring(reason))

    if EcLifeInvader.World and EcLifeInvader.World.SpawnAll then
        EcLifeInvader.World.SpawnAll()
    end
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

--- Nur manuell /ec_li_world_respawn — kein automatisches Löschen bei playerSpawned (hat NPC kaputt gemacht).
