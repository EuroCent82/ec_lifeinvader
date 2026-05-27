--[[ ec_lifeinvader — Standorte: NPCs, Objekte, Blips, Bridge-Interaktion ]]

EcLifeInvader = EcLifeInvader or {}
EcLifeInvader.World = EcLifeInvader.World or {}

local spawnedPeds = {}
local spawnedObjects = {}
local spawnedBlips = {}

local function debugPrint(...)
    LiBridge.Debug(...)
end

local function blipDebugEnabled()
    local cfg = Config.Blip or {}
    return cfg.debug == true
end

local function blipDebug(...)
    if blipDebugEnabled() then
        print('^5[ec_lifeinvader:blip]^0', ...)
    end
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
        category = tonumber(defaults.category),
    }
end

local function spawnBlip(locationId, location)
    if not shouldShowBlip(location) then
        debugPrint('Blip übersprungen:', locationId, '(global oder Standort deaktiviert)')
        blipDebug('skip', locationId, 'reason=disabled')
        return
    end

    local blipData = resolveBlipSettings(location)
    if not blipData then
        debugPrint('Blip übersprungen:', locationId, '(ungültige coords)')
        blipDebug('skip', locationId, 'reason=invalid_coords')
        return
    end

    local blip = AddBlipForCoord(blipData.x, blipData.y, blipData.z)
    SetBlipSprite(blip, blipData.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipData.scale)
    SetBlipColour(blip, blipData.color)
    SetBlipAsShortRange(blip, blipData.shortRange == true)
    SetBlipHighDetail(blip, true)

    if blipData.category and blipData.category > 0 then
        SetBlipCategory(blip, blipData.category)
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipData.label)
    EndTextCommandSetBlipName(blip)
    spawnedBlips[locationId] = blip
    debugPrint('Blip erstellt:', locationId, blipData.label, ('@ %.2f, %.2f, %.2f'):format(blipData.x, blipData.y, blipData.z))
    blipDebug(
        'spawn',
        locationId,
        ('label=%s sprite=%s category=%s'):format(
            blipData.label,
            tostring(blipData.sprite),
            tostring(blipData.category)
        )
    )
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

local function spawnNpc(locationId, location)
    local x, y, z, heading = LiBridge.Vec4Parts(location.coords)
    if not x then
        return nil
    end

    local model = loadModel(location.model)
    if not model then
        return nil
    end

    local ped = CreatePed(4, model, x, y, z - 1.0, heading, false, false)
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
        debugPrint('Standort', locationId, 'ist item-only — kein Welt-Spawn')
        return
    end

    if locationType == 'object' then
        spawnObject(locationId, location)
    else
        spawnNpc(locationId, location)
    end
end

function EcLifeInvader.World.SpawnBlipsOnly()
    for locationId, blip in pairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        spawnedBlips[locationId] = nil
    end

    local locations = Config.Locations or {}
    local blipCount = 0
    local globalEnabled = Config.Blip and Config.Blip.enabled == true
    blipDebug('start SpawnBlipsOnly', 'globalEnabled=' .. tostring(globalEnabled), 'locations=' .. tostring(#locations))

    for i = 1, #locations do
        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationId = tostring(location.id or ('loc_%d'):format(i))
            if shouldShowBlip(location) then
                spawnBlip(locationId, location)
                blipCount = blipCount + 1
            end
        end
    end

    debugPrint(('Blips gespawnt: %d'):format(blipCount))
    blipDebug('done SpawnBlipsOnly', 'count=' .. tostring(blipCount))
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

function EcLifeInvader.World.SpawnAll()
    EcLifeInvader.World.Cleanup()

    local locations = Config.Locations or {}
    local count = 0
    local blipCount = 0

    for i = 1, #locations do
        local location = locations[i]
        if type(location) == 'table' and location.enabled ~= false then
            local locationId = tostring(location.id or ('loc_%d'):format(i))
            if shouldShowBlip(location) then
                blipCount = blipCount + 1
            end
            spawnLocation(location)
            count = count + 1
        end
    end

    debugPrint(('Welt gespawnt: %d Standort(e), %d Blip(s)'):format(count, blipCount))
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    EcLifeInvader.World.Cleanup()
end)

RegisterCommand('ec_li_blips_debug', function()
    if EcLifeInvader.World and EcLifeInvader.World.SpawnBlipsOnly then
        blipDebug('manual command trigger')
        EcLifeInvader.World.SpawnBlipsOnly()
    end
end, false)
