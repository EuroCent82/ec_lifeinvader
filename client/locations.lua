--[[ ec_lifeinvader — Standorte: NPCs, Objekte, Blips (v1.0-Spawn + sichere Blip-Namen) ]]

EcLifeInvader = EcLifeInvader or {}
EcLifeInvader.World = EcLifeInvader.World or {}

local spawnedPeds = {}
local spawnedObjects = {}
local spawnedBlips = {}

local function worldDebugEnabled()
    if Config.Debug == true then
        return true
    end
    local world = Config.World or {}
    return world.debug == true
end

local function debugPrint(...)
    LiBridge.Debug(...)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        debugPrint('Model nicht gefunden:', tostring(model))
        return nil
    end

    RequestModel(hash)
    local timeoutAt = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeoutAt do
        Wait(50)
    end

    if not HasModelLoaded(hash) then
        debugPrint('Model-Timeout:', tostring(model))
        return nil
    end

    return hash
end

local function shouldShowBlip(location)
    if location.blip == false then
        return false
    end

    local locationType = LiBridge.NormalizeLocationType(location)
    if locationType == 'item' then
        return false
    end

    if location.enabled == false then
        return false
    end

    return Config.Blip and Config.Blip.enabled == true
end

local function resolveBlipLabel(location)
    if type(location.blipLabel) == 'string' and location.blipLabel ~= '' then
        return location.blipLabel
    end

    local defaults = Config.Blip or {}
    if type(defaults.label) == 'string' and defaults.label ~= '' then
        return defaults.label
    end

    return 'LifeInvader'
end

local function resolveBlipSettings(location)
    local defaults = Config.Blip or {}
    local x, y, z = LiBridge.Vec4Parts(location.coords)
    if not x then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
        sprite = tonumber(defaults.sprite) or 77,
        color = tonumber(defaults.color) or 1,
        scale = tonumber(defaults.scale) or 0.85,
        shortRange = defaults.shortRange == true,
        label = resolveBlipLabel(location),
    }
end

--- EndTextCommandSetBlipName (0xBC38B49…) crasht ohne gültigen Blip / Text-Stack.
local function setBlipNameSafe(blip, label)
    if not blip or blip == 0 or not DoesBlipExist(blip) then
        return false
    end

    local text = type(label) == 'string' and label or 'LifeInvader'
    local ok = pcall(function()
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandSetBlipName(blip)
    end)

    if not ok then
        debugPrint('Blip-Name fehlgeschlagen:', text)
    end

    return ok
end

local function spawnBlip(locationId, location)
    if not shouldShowBlip(location) then
        return nil
    end

    local blipData = resolveBlipSettings(location)
    if not blipData then
        return nil
    end

    local blip = AddBlipForCoord(blipData.x, blipData.y, blipData.z)
    if not blip or blip == 0 or not DoesBlipExist(blip) then
        return nil
    end

    SetBlipSprite(blip, blipData.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipData.scale)
    SetBlipColour(blip, blipData.color)
    SetBlipAsShortRange(blip, blipData.shortRange == true)
    SetBlipHighDetail(blip, true)
    setBlipNameSafe(blip, blipData.label)

    spawnedBlips[locationId] = blip
    debugPrint('Blip erstellt:', locationId, blipData.label, ('@ %.2f, %.2f, %.2f'):format(blipData.x, blipData.y, blipData.z))
    return blip
end

local function openLifeInvader(location)
    EcLifeInvader.Open(location.id)
end

local function registerInteraction(entity, location)
    LiBridge.Client.RegisterEntityInteraction(entity, location, location.label or 'LifeInvader öffnen', function()
        openLifeInvader(location)
    end)
end

local function spawnNpc(locationId, location)
    local x, y, z, heading = LiBridge.Vec4Parts(location.coords)
    if not x then
        return nil
    end

    local model = loadModel(location.model)
    if not model then
        return nil
    end

    local zOffset = tonumber(location.spawnZOffset)
    if zOffset == nil then
        zOffset = -1.0
    end

    local spawnZ = z + zOffset
    local ped = CreatePed(4, model, x, y, spawnZ, heading, false, false)
    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    if location.scenario and location.scenario ~= '' then
        TaskStartScenarioInPlace(ped, location.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
    spawnedPeds[locationId] = ped
    registerInteraction(ped, location)
    debugPrint('NPC gespawnt:', locationId, ('@ %.2f, %.2f, %.2f'):format(x, y, spawnZ))
    return ped
end

local function spawnObject(locationId, location)
    local x, y, z, heading = LiBridge.Vec4Parts(location.coords)
    if not x then
        return nil
    end

    local model = loadModel(location.model)
    if not model then
        return nil
    end

    local obj = CreateObject(model, x, y, z, false, false, false)
    if not DoesEntityExist(obj) then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(model)
    spawnedObjects[locationId] = obj
    registerInteraction(obj, location)
    return obj
end

local function spawnLocation(location)
    if type(location) ~= 'table' or location.enabled == false then
        return
    end

    local locationId = tostring(location.id or ('loc_%s'):format(#spawnedPeds + #spawnedObjects + 1))
    local locationType = LiBridge.NormalizeLocationType(location)

    spawnBlip(locationId, location)

    if locationType == 'item' then
        return
    end

    if locationType == 'object' then
        spawnObject(locationId, location)
    else
        spawnNpc(locationId, location)
    end
end

local function collectWorldReport()
    local blips = {}
    local npcs = {}
    local objects = {}

    for locationId, blip in pairs(spawnedBlips) do
        if blip and DoesBlipExist(blip) then
            local loc = nil
            for i = 1, #(Config.Locations or {}) do
                local entry = Config.Locations[i]
                if entry and tostring(entry.id) == locationId then
                    loc = entry
                    break
                end
            end
            local x, y, z = 0.0, 0.0, 0.0
            if loc then
                x, y, z = LiBridge.Vec4Parts(loc.coords)
            end
            blips[#blips + 1] = {
                id = locationId,
                name = loc and resolveBlipLabel(loc) or 'LifeInvader',
                x = x,
                y = y,
                z = z,
            }
        end
    end

    for locationId, ped in pairs(spawnedPeds) do
        local exists = ped and DoesEntityExist(ped)
        local x, y, z = 0.0, 0.0, 0.0
        if exists then
            local coords = GetEntityCoords(ped)
            x, y, z = coords.x, coords.y, coords.z
        end
        local modelName = '?'
        for i = 1, #(Config.Locations or {}) do
            local entry = Config.Locations[i]
            if entry and tostring(entry.id) == locationId then
                modelName = tostring(entry.model or '?')
                break
            end
        end
        npcs[#npcs + 1] = {
            id = locationId,
            model = modelName,
            ok = exists,
            x = x,
            y = y,
            z = z,
        }
    end

    for locationId, obj in pairs(spawnedObjects) do
        local exists = obj and DoesEntityExist(obj)
        local x, y, z = 0.0, 0.0, 0.0
        if exists then
            local coords = GetEntityCoords(obj)
            x, y, z = coords.x, coords.y, coords.z
        end
        objects[#objects + 1] = {
            id = locationId,
            ok = exists,
            x = x,
            y = y,
            z = z,
        }
    end

    return blips, npcs, objects
end

function EcLifeInvader.World.ReportToServer(reason)
    if not worldDebugEnabled() then
        return
    end

    local blips, npcs, objects = collectWorldReport()
    TriggerServerEvent('ec_lifeinvader:server:worldDebug', {
        reason = reason or 'unknown',
        blips = blips,
        npcs = npcs,
        objects = objects,
    })
end

function EcLifeInvader.World.SpawnBlipsOnly()
    for locationId, blip in pairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        spawnedBlips[locationId] = nil
    end

    local locations = Config.Locations or {}
    for i = 1, #locations do
        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationId = tostring(location.id or ('loc_%d'):format(i))
            spawnBlip(locationId, location)
        end
    end

    EcLifeInvader.World.ReportToServer('SpawnBlipsOnly')
end

function EcLifeInvader.World.Cleanup()
    for locationId, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            LiBridge.Client.RemoveEntityInteraction(ped)
            DeletePed(ped)
        end
        spawnedPeds[locationId] = nil
    end

    for locationId, obj in pairs(spawnedObjects) do
        if DoesEntityExist(obj) then
            LiBridge.Client.RemoveEntityInteraction(obj)
            DeleteEntity(obj)
        end
        spawnedObjects[locationId] = nil
    end

    for locationId, blip in pairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        spawnedBlips[locationId] = nil
    end

    LiBridge.Client.ClearNativeZones()
end

function EcLifeInvader.World.IsWorldComplete()
    local locations = Config.Locations or {}

    for i = 1, #locations do
        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationId = tostring(location.id or ('loc_%d'):format(i))
            local locationType = LiBridge.NormalizeLocationType(location)

            if locationType == 'object' then
                local obj = spawnedObjects[locationId]
                if not obj or not DoesEntityExist(obj) then
                    return false
                end
            elseif locationType ~= 'item' then
                local ped = spawnedPeds[locationId]
                if not ped or not DoesEntityExist(ped) then
                    return false
                end
            end
        end
    end

    return true
end

function EcLifeInvader.World.SpawnAll()
    EcLifeInvader.World.Cleanup()

    local locations = Config.Locations or {}
    local count = 0

    for i = 1, #locations do
        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            spawnLocation(location)
            count = count + 1
        end
    end

    debugPrint(('Welt gespawnt: %d Standort(e), vollständig=%s'):format(count, tostring(EcLifeInvader.World.IsWorldComplete())))
    EcLifeInvader.World.ReportToServer('SpawnAll')
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    EcLifeInvader.World.Cleanup()
end)

RegisterCommand('ec_li_world_respawn', function()
    EcLifeInvader.World.SpawnAll()
end, false)

RegisterCommand('ec_li_world_debug', function()
    EcLifeInvader.World.ReportToServer('manual')
end, false)
