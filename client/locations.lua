--[[ ec_lifeinvader — Standorte: NPCs, Objekte, Blips, Bridge-Interaktion ]]

EcLifeInvader = EcLifeInvader or {}
EcLifeInvader.World = EcLifeInvader.World or {}

local spawnedPeds = {}
local spawnedObjects = {}
local spawnedBlips = {}
local activeSpawnId = 0
local lastWorldDebug = { blips = {}, npcs = {}, objects = {} }

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

local function blipDebugEnabled()
    local cfg = Config.Blip or {}
    return cfg.debug == true or worldDebugEnabled()
end

local function blipDebug(...)
    if blipDebugEnabled() then
        print('^5[ec_lifeinvader:blip]^0', ...)
    end
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        return nil, 'model_not_in_cdimage'
    end

    RequestModel(hash)
    local timeoutAt = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeoutAt do
        Wait(50)
    end

    if not HasModelLoaded(hash) then
        return nil, 'model_timeout'
    end

    return hash, nil
end

local function waitForCollisionAt(x, y, z, timeoutMs)
    timeoutMs = timeoutMs or 8000
    local untilAt = GetGameTimer() + timeoutMs

    RequestCollisionAtCoord(x, y, z)
    while GetGameTimer() < untilAt do
        RequestCollisionAtCoord(x, y, z)
        if HasCollisionLoadedAroundEntity(PlayerPedId()) then
            return true
        end
        Wait(50)
    end

    return false
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

local function clearSpawnedBlips()
    for locationId, blip in pairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        spawnedBlips[locationId] = nil
    end
end

local function setBlipLabel(blip, label)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
end

local function recordBlipDebug(entry)
    lastWorldDebug.blips[#lastWorldDebug.blips + 1] = entry
end

local function recordNpcDebug(entry)
    lastWorldDebug.npcs[#lastWorldDebug.npcs + 1] = entry
end

local function recordObjectDebug(entry)
    lastWorldDebug.objects[#lastWorldDebug.objects + 1] = entry
end

local function spawnBlip(locationId, location)
    if not shouldShowBlip(location) then
        recordBlipDebug({
            locationId = locationId,
            skipped = true,
            reason = 'disabled',
        })
        return nil
    end

    local blipData = resolveBlipSettings(location)
    if not blipData then
        recordBlipDebug({
            locationId = locationId,
            skipped = true,
            reason = 'invalid_coords',
        })
        return nil
    end

    local existing = spawnedBlips[locationId]
    if existing and DoesBlipExist(existing) then
        RemoveBlip(existing)
        spawnedBlips[locationId] = nil
    end

    local blip = AddBlipForCoord(blipData.x, blipData.y, blipData.z)
    SetBlipSprite(blip, blipData.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipData.scale)
    SetBlipColour(blip, blipData.color)
    SetBlipAsShortRange(blip, blipData.shortRange == true)
    SetBlipHighDetail(blip, true)
    setBlipLabel(blip, blipData.label)

    spawnedBlips[locationId] = blip
    recordBlipDebug({
        locationId = locationId,
        label = blipData.label,
        sprite = blipData.sprite,
        color = blipData.color,
        x = blipData.x,
        y = blipData.y,
        z = blipData.z,
        handle = blip,
        skipped = false,
    })

    debugPrint('Blip erstellt:', locationId, blipData.label, ('@ %.2f, %.2f, %.2f'):format(blipData.x, blipData.y, blipData.z))
    blipDebug('spawn', locationId, ('label=%s sprite=%s'):format(blipData.label, tostring(blipData.sprite)))
    return blip
end

local function openLifeInvader(location)
    debugPrint('Öffne LifeInvader UI —', location.id or '?')
    EcLifeInvader.Open(location.id)
end

local function registerInteraction(entity, location)
    LiBridge.Client.RegisterEntityInteraction(entity, location, location.label or 'LifeInvader öffnen', function()
        openLifeInvader(location)
    end)
end

local function registerNativeFallback(location)
    LiBridgeClientNative.RegisterZone(location, function()
        openLifeInvader(location)
    end)
end

local function spawnNpc(locationId, location)
    local x, y, z, heading = LiBridge.Vec4Parts(location.coords)
    if not x then
        recordNpcDebug({
            locationId = locationId,
            model = location.model,
            success = false,
            detail = 'invalid_coords',
        })
        return nil
    end

    local zOffset = tonumber(location.spawnZOffset)
    if zOffset == nil then
        zOffset = -1.0
    end

    local spawnX, spawnY, spawnZ = x, y, z + zOffset
    local modelName = tostring(location.model or '?')
    local model, loadErr = loadModel(location.model)

    if not model then
        recordNpcDebug({
            locationId = locationId,
            model = modelName,
            x = spawnX,
            y = spawnY,
            z = spawnZ,
            success = false,
            detail = 'load_model:' .. tostring(loadErr),
        })
        debugPrint('NPC-Spawn fehlgeschlagen (Model):', locationId, modelName, loadErr)
        return nil
    end

    waitForCollisionAt(spawnX, spawnY, spawnZ, 8000)

    local ped = nil
    local lastErr = 'create_ped_failed'
    local maxAttempts = tonumber((Config.World or {}).npcSpawnAttempts) or 3

    for attempt = 1, maxAttempts do
        ped = CreatePed(4, model, spawnX, spawnY, spawnZ, heading, false, false)
        if DoesEntityExist(ped) then
            lastErr = nil
            break
        end
        Wait(100)
        lastErr = ('create_ped_failed_attempt_%d'):format(attempt)
    end

    if not ped or not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        recordNpcDebug({
            locationId = locationId,
            model = modelName,
            x = spawnX,
            y = spawnY,
            z = spawnZ,
            success = false,
            detail = lastErr,
        })
        debugPrint('NPC-Spawn fehlgeschlagen (CreatePed):', locationId, lastErr)
        return nil
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, true)

    if location.scenario and location.scenario ~= '' then
        TaskStartScenarioInPlace(ped, location.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
    spawnedPeds[locationId] = ped
    registerInteraction(ped, location)
    registerNativeFallback(location)

    recordNpcDebug({
        locationId = locationId,
        model = modelName,
        x = spawnX,
        y = spawnY,
        z = spawnZ,
        entity = ped,
        success = true,
        detail = 'spawned',
    })

    debugPrint('NPC gespawnt:', locationId, ('entity=%s @ %.2f, %.2f, %.2f'):format(ped, spawnX, spawnY, spawnZ))
    return ped
end

local function spawnObject(locationId, location)
    local x, y, z, heading = LiBridge.Vec4Parts(location.coords)
    if not x then
        recordObjectDebug({
            locationId = locationId,
            model = location.model,
            success = false,
            detail = 'invalid_coords',
        })
        return nil
    end

    local modelName = tostring(location.model or '?')
    local model, loadErr = loadModel(location.model)
    if not model then
        recordObjectDebug({
            locationId = locationId,
            model = modelName,
            x = x,
            y = y,
            z = z,
            success = false,
            detail = 'load_model:' .. tostring(loadErr),
        })
        return nil
    end

    waitForCollisionAt(x, y, z, 5000)

    local obj = CreateObject(model, x, y, z, false, false, false)
    if not DoesEntityExist(obj) then
        SetModelAsNoLongerNeeded(model)
        recordObjectDebug({
            locationId = locationId,
            model = modelName,
            x = x,
            y = y,
            z = z,
            success = false,
            detail = 'create_object_failed',
        })
        return nil
    end

    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(model)
    spawnedObjects[locationId] = obj
    registerInteraction(obj, location)
    registerNativeFallback(location)

    recordObjectDebug({
        locationId = locationId,
        model = modelName,
        x = x,
        y = y,
        z = z,
        success = true,
        detail = 'spawned',
    })

    return obj
end

local function spawnLocationEntities(location, locationId)
    local locationType = LiBridge.NormalizeLocationType(location)

    if locationType == 'item' then
        debugPrint('Standort', locationId, 'ist item-only — kein Welt-Spawn')
        return
    end

    if locationType == 'object' then
        spawnObject(locationId, location)
    else
        spawnNpc(locationId, location)
    end
end

local function resetWorldDebugTables()
    lastWorldDebug.blips = {}
    lastWorldDebug.npcs = {}
    lastWorldDebug.objects = {}
end

function EcLifeInvader.World.ReportToServer(reason)
    if not worldDebugEnabled() then
        return
    end

    local blipCount = 0
    for i = 1, #lastWorldDebug.blips do
        if lastWorldDebug.blips[i].skipped ~= true then
            blipCount = blipCount + 1
        end
    end

    TriggerServerEvent('ec_lifeinvader:server:worldDebug', {
        reason = reason or 'unknown',
        worldComplete = EcLifeInvader.World.IsWorldComplete(),
        blipGlobalEnabled = Config.Blip and Config.Blip.enabled == true,
        blipCount = blipCount,
        blips = lastWorldDebug.blips,
        npcs = lastWorldDebug.npcs,
        objects = lastWorldDebug.objects,
    })
end

function EcLifeInvader.World.SpawnBlipsOnly()
    resetWorldDebugTables()
    clearSpawnedBlips()

    local locations = Config.Locations or {}
    local blipCount = 0

    for i = 1, #locations do
        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationId = tostring(location.id or ('loc_%d'):format(i))
            if spawnBlip(locationId, location) then
                blipCount = blipCount + 1
            end
        end
    end

    debugPrint(('Blips gespawnt: %d'):format(blipCount))
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

    clearSpawnedBlips()
    LiBridge.Client.ClearNativeZones()
end

function EcLifeInvader.World.CountEntities()
    local count = 0
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            count = count + 1
        end
    end
    for _, obj in pairs(spawnedObjects) do
        if DoesEntityExist(obj) then
            count = count + 1
        end
    end
    return count
end

function EcLifeInvader.World.IsWorldComplete()
    local locations = Config.Locations or {}

    for i = 1, #locations do
        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationId = tostring(location.id or ('loc_%d'):format(i))
            local locationType = LiBridge.NormalizeLocationType(location)

            if locationType ~= 'item' then
                if locationType == 'object' then
                    local obj = spawnedObjects[locationId]
                    if not obj or not DoesEntityExist(obj) then
                        return false
                    end
                else
                    local ped = spawnedPeds[locationId]
                    if not ped or not DoesEntityExist(ped) then
                        return false
                    end
                end
            end
        end
    end

    return true
end

function EcLifeInvader.World.SpawnAll()
    activeSpawnId = activeSpawnId + 1
    local spawnId = activeSpawnId

    resetWorldDebugTables()
    EcLifeInvader.World.Cleanup()

    local locations = Config.Locations or {}
    local locationCount = 0

    for i = 1, #locations do
        if spawnId ~= activeSpawnId then
            return
        end

        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationId = tostring(location.id or ('loc_%d'):format(i))
            spawnBlip(locationId, location)
            locationCount = locationCount + 1
        end
    end

    CreateThread(function()
        local delayMs = tonumber((Config.World or {}).entitySpawnDelayMs) or 500
        Wait(delayMs)

        if spawnId ~= activeSpawnId then
            return
        end

        for i = 1, #locations do
            if spawnId ~= activeSpawnId then
                return
            end

            local location = locations[i]
            if type(location) == 'table' and location.enabled ~= false then
                local locationId = tostring(location.id or ('loc_%d'):format(i))
                spawnLocationEntities(location, locationId)
            end
        end

        debugPrint(('Welt gespawnt: %d Standort(e), vollständig=%s'):format(
            locationCount,
            tostring(EcLifeInvader.World.IsWorldComplete())
        ))

        EcLifeInvader.World.ReportToServer('SpawnAll')
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    EcLifeInvader.World.Cleanup()
end)

RegisterCommand('ec_li_blips_debug', function()
    if EcLifeInvader.World and EcLifeInvader.World.SpawnBlipsOnly then
        EcLifeInvader.World.SpawnBlipsOnly()
    end
end, false)

RegisterCommand('ec_li_world_respawn', function()
    if EcLifeInvader.World and EcLifeInvader.World.SpawnAll then
        EcLifeInvader.World.SpawnAll()
    end
end, false)

RegisterCommand('ec_li_world_debug', function()
    if EcLifeInvader.World and EcLifeInvader.World.ReportToServer then
        EcLifeInvader.World.ReportToServer('manual_command')
    end
end, false)
