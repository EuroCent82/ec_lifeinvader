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

local warnedBlipNaming = false

local function getGameBuildNumberSafe()
    if type(GetGameBuildNumber) ~= 'function' then
        return nil
    end

    local ok, build = pcall(GetGameBuildNumber)
    if not ok then
        return nil
    end

    local buildNumber = tonumber(build)
    if buildNumber and buildNumber > 0 then
        return buildNumber
    end
    return nil
end

local function isBuildBlocked(disabledBuilds, build)
    if type(disabledBuilds) ~= 'table' or not build then
        return false
    end

    if disabledBuilds[build] == true then
        return true
    end

    for i = 1, #disabledBuilds do
        if tonumber(disabledBuilds[i]) == build then
            return true
        end
    end

    return false
end

local function shouldApplyBlipName()
    local defaults = Config.Blip or {}
    local mode = tostring(defaults.nameMode or 'auto'):lower()
    local build = getGameBuildNumberSafe()
    local disabledBuilds = defaults.disableNameForBuilds or { [3407] = true }

    if mode == 'none' then
        if not warnedBlipNaming then
            warnedBlipNaming = true
            debugPrint('Blip-Namen deaktiviert (Config.Blip.nameMode=none).')
        end
        return false
    end

    if mode == 'native' then
        return true
    end

    if isBuildBlocked(disabledBuilds, build) then
        if not warnedBlipNaming then
            warnedBlipNaming = true
            debugPrint(('Blip-Namen wegen Build %s deaktiviert (Config.Blip.nameMode=auto).'):format(tostring(build)))
        end
        return false
    end

    return true
end

local function safeSetBlipName(blip, label)
    if not blip or blip == 0 or not DoesBlipExist(blip) then
        debugPrint('Blip-Name übersprungen: ungültiger Handle', tostring(blip))
        return false
    end

    if not shouldApplyBlipName() then
        return false
    end

    local safeLabel = tostring(label or '')
    if safeLabel == '' then
        safeLabel = 'LifeInvader'
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(safeLabel)
    EndTextCommandSetBlipName(blip)
    return true
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
        sprite = tonumber(defaults.sprite) or 225,
        color = tonumber(defaults.color) or 1,
        scale = tonumber(defaults.scale) or 0.85,
        display = tonumber(defaults.display) or 3,
        shortRange = defaults.shortRange ~= false,
        label = resolveBlipLabel(location),
    }
end

--- 1:1 wie nxt_driving_school/client/npc.lua (kein pcall — der kann den Text-Stack kaputt machen).
local function spawnBlip(locationId, location)
    if not shouldShowBlip(location) then
        return nil
    end

    local blipData = resolveBlipSettings(location)
    if not blipData then
        return nil
    end

    local blipLabel = blipData.label
    if type(blipLabel) ~= 'string' or blipLabel == '' then
        blipLabel = 'LifeInvader'
    end

    local blip = AddBlipForCoord(blipData.x, blipData.y, blipData.z)
    if not blip or blip == 0 then
        return nil
    end

    SetBlipSprite(blip, blipData.sprite)
    SetBlipDisplay(blip, blipData.display)
    SetBlipScale(blip, blipData.scale)
    SetBlipColour(blip, blipData.color)
    SetBlipAsShortRange(blip, blipData.shortRange)
    safeSetBlipName(blip, blipLabel)

    spawnedBlips[locationId] = blip
    debugPrint('Blip erstellt:', locationId, blipLabel, ('sprite=%s @ %.2f, %.2f, %.2f'):format(
        tostring(blipData.sprite),
        blipData.x,
        blipData.y,
        blipData.z
    ))
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

local function resolveNpcPresence(locationId, location)
    local stored = spawnedPeds[locationId]
    if stored and stored ~= 0 and DoesEntityExist(stored) then
        local coords = GetEntityCoords(stored)
        return true, stored, coords.x, coords.y, coords.z, 'handle'
    end

    local x, y, z = LiBridge.Vec4Parts(location.coords)
    if not x then
        return false, stored, 0.0, 0.0, 0.0, 'no_coords'
    end

    local modelHash = joaat(location.model)
    local closest = GetClosestPed(x, y, z, 3.0, true, true, true, false, -1)
    if closest and closest ~= 0 and DoesEntityExist(closest) and GetEntityModel(closest) == modelHash then
        spawnedPeds[locationId] = closest
        return true, closest, x, y, z, 'proximity'
    end

    return false, stored, x, y, z, 'missing'
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

    for i = 1, #(Config.Locations or {}) do
        local location = Config.Locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationType = LiBridge.NormalizeLocationType(location)
            local locationId = tostring(location.id or ('loc_%d'):format(i))

            if locationType ~= 'item' and locationType ~= 'object' then
                local ok, ped, x, y, z, source = resolveNpcPresence(locationId, location)
                if ok and ped and source == 'proximity' then
                    registerInteraction(ped, location)
                end
                npcs[#npcs + 1] = {
                    id = locationId,
                    model = tostring(location.model or '?'),
                    ok = ok,
                    x = x,
                    y = y,
                    z = z,
                    detail = source,
                }
            end
        end
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

    CreateThread(function()
        Wait(250)
        EcLifeInvader.World.ReportToServer('SpawnAll')
    end)
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
