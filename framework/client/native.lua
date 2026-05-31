LiBridgeClientNative = LiBridgeClientNative or {}

local nativeZones = {}
local threadStarted = false

local PromptMode = {
    TEXT_3D = '3d',
    HELP = 'help',
}

local function getInteractionConfig()
    return Config.Interaction or {}
end

local function getNativePrompt(location)
    if type(location) == 'table' and location.nativePrompt ~= nil then
        return string.lower(tostring(location.nativePrompt))
    end
    return string.lower(tostring(getInteractionConfig().nativePrompt or PromptMode.TEXT_3D))
end

local function getInteractDistance(location)
    return tonumber(location.interactDistance)
        or tonumber(getInteractionConfig().nativeDistance)
        or 2.5
end

local function getWakeDistance()
    return tonumber(getInteractionConfig().nativeWakeDistance) or 20.0
end

local function getIdleWaitMs()
    return math.max(100, tonumber(getInteractionConfig().nativeIdleWait) or 500)
end

local function getTextHeightOffset(location)
    local cfg = getInteractionConfig()
    if location and location.nativeTextOffset ~= nil then
        return tonumber(location.nativeTextOffset) or 0.35
    end
    return tonumber(cfg.nativeTextOffset) or 0.35
end

local function getPromptText(location, forHelp)
    local keyLabel = getInteractionConfig().nativeKeyLabel or 'E'
    local label = location.label or 'LifeInvader öffnen'
    if forHelp then
        return ('[~g~%s~s~] %s'):format(keyLabel, label)
    end
    return ('[%s] %s'):format(keyLabel, label)
end

local function zoneLocationId(location, fallbackIndex)
    if type(location) == 'table' and location.id ~= nil then
        return tostring(location.id)
    end
    return ('zone_%s'):format(tostring(fallbackIndex or 0))
end

local function resolveInteractionEntity(zone)
    local locationId = zone.locationId
    if locationId
        and EcLifeInvader
        and EcLifeInvader.World
        and EcLifeInvader.World.GetInteractionEntity
    then
        local entity = EcLifeInvader.World.GetInteractionEntity(locationId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            return entity
        end
    end

    if zone.entity and zone.entity ~= 0 and DoesEntityExist(zone.entity) then
        return zone.entity
    end

    return nil
end

local function updateZoneAnchor(zone)
    local entity = resolveInteractionEntity(zone)
    if entity then
        zone.entity = entity

        if IsEntityAPed(entity) then
            if not zone.headBone then
                zone.headBone = GetPedBoneIndex(entity, 31086)
            end

            if zone.headBone and zone.headBone ~= -1 then
                local boneCoords = GetWorldPositionOfEntityBone(entity, zone.headBone)
                if boneCoords then
                    zone.anchor = vector3(boneCoords.x, boneCoords.y, boneCoords.z)
                    return zone.anchor.x, zone.anchor.y, zone.anchor.z
                end
            end
        end

        local coords = GetEntityCoords(entity)
        zone.anchor = vector3(coords.x, coords.y, coords.z)
        return coords.x, coords.y, coords.z
    end

    if zone.anchor then
        return zone.anchor.x, zone.anchor.y, zone.anchor.z
    end

    local location = zone.location
    local x, y, z = LiBridge.Vec4Parts(location.coords)
    if not x then
        return nil
    end

    local zOffset = tonumber(location.spawnZOffset)
    if zOffset == nil then
        zOffset = -1.0
    end

    zone.anchor = vector3(x, y, z + zOffset)
    return x, y, z + zOffset
end

local function horizontalDistance(playerPos, x, y)
    local dx = playerPos.x - x
    local dy = playerPos.y - y
    return math.sqrt(dx * dx + dy * dy)
end

local function drawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function showNativePrompt(zone, x, y, z)
    local promptMode = getNativePrompt(zone.location)
    if promptMode == PromptMode.HELP then
        drawHelpText(getPromptText(zone.location, true))
        return
    end

    local textZ = z + getTextHeightOffset(zone.location)
    drawText3D(x, y, textZ, getPromptText(zone.location, false))
end

function LiBridgeClientNative.RegisterZone(location, onSelect, entity)
    if type(location) ~= 'table' or type(onSelect) ~= 'function' then
        return
    end

    local locationId = zoneLocationId(location, #nativeZones + 1)

    for i = #nativeZones, 1, -1 do
        if nativeZones[i].locationId == locationId then
            table.remove(nativeZones, i)
        end
    end

    local zone = {
        locationId = locationId,
        location = location,
        onSelect = onSelect,
        entity = entity,
        anchor = nil,
        headBone = nil,
    }

    updateZoneAnchor(zone)
    nativeZones[#nativeZones + 1] = zone

    LiBridgeClientNative.EnsureThread()
end

function LiBridgeClientNative.Clear()
    nativeZones = {}
end

function LiBridgeClientNative.EnsureThread()
    if threadStarted then
        return
    end
    threadStarted = true

    CreateThread(function()
        local defaultPrompt = string.lower(tostring(getInteractionConfig().nativePrompt or PromptMode.TEXT_3D))
        print(('^2[ec_lifeinvader]^0 Native [E]: prompt=%s (3d | help)'):format(defaultPrompt))

        while true do
            if #nativeZones == 0 then
                Wait(getIdleWaitMs())
            else
                local playerPos = GetEntityCoords(PlayerPedId())
                local wakeDistance = getWakeDistance()
                local nearestWakeDist = nil
                local nearestZone = nil
                local nearestInteractDist = nil

                for i = 1, #nativeZones do
                    local zone = nativeZones[i]
                    local checkX, checkY, checkZ

                    if zone.anchor then
                        checkX, checkY, checkZ = zone.anchor.x, zone.anchor.y, zone.anchor.z
                    else
                        checkX, checkY, checkZ = updateZoneAnchor(zone)
                    end

                    if checkX then
                        local wakeDist = horizontalDistance(playerPos, checkX, checkY)
                        if not nearestWakeDist or wakeDist < nearestWakeDist then
                            nearestWakeDist = wakeDist
                        end

                        if wakeDist <= wakeDistance then
                            local x, y, z = updateZoneAnchor(zone)
                            if x then
                                local interactDist = horizontalDistance(playerPos, x, y)
                                local maxDist = getInteractDistance(zone.location)
                                if interactDist <= maxDist
                                    and (not nearestInteractDist or interactDist < nearestInteractDist)
                                then
                                    nearestZone = zone
                                    nearestInteractDist = interactDist
                                end
                            end
                        end
                    end
                end

                if nearestZone then
                    local x, y, z = updateZoneAnchor(nearestZone)
                    if x then
                        showNativePrompt(nearestZone, x, y, z)
                    end

                    local key = tonumber(getInteractionConfig().nativeKey) or 38
                    if IsControlJustReleased(0, key) then
                        nearestZone.onSelect(nearestZone.location)
                    end
                end

                if nearestWakeDist and nearestWakeDist <= wakeDistance then
                    Wait(0)
                else
                    Wait(getIdleWaitMs())
                end
            end
        end
    end)
end

CreateThread(function()
    Wait(1000)
    LiBridgeClientNative.EnsureThread()
end)
