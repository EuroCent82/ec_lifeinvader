if Config.Debug ~= true then
    return
end

--[[
    Isolierter Blip-Test — nur bei Config.Debug = true
    Vergleich: nxt_driving_school/client/npc.lua Zeile 677–686

    /ec_li_blip_test        → gelbes Haus (Sprite 40), Name „Hallo“ an deiner Position
    /ec_li_blip_test_clear  → Test-Blip entfernen
]]

local testBlipHandle = nil

local function removeTestBlip()
    if testBlipHandle and DoesBlipExist(testBlipHandle) then
        RemoveBlip(testBlipHandle)
    end
    testBlipHandle = nil
end

local function logTest(message)
    print('^3[ec_lifeinvader:blip_test]^0 ' .. message)
    TriggerServerEvent('ec_lifeinvader:server:blipTestLog', message)
end

local function safeSetBlipName(blip, label)
    if not blip or blip == 0 or not DoesBlipExist(blip) then
        logTest(('Blip-Name übersprungen: ungültiger Handle (%s)'):format(tostring(blip)))
        return false
    end

    local safeLabel = tostring(label or '')
    if safeLabel == '' then
        safeLabel = 'Hallo'
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(safeLabel)
    EndTextCommandSetBlipName(blip)
    return true
end

--- Minimaler Blip — exakt die Native-Reihenfolge aus nxt_driving_school.
local function createMinimalBlip(x, y, z, sprite, color, scale, label)
    removeTestBlip()

    local blip = AddBlipForCoord(x, y, z)
    if not blip or blip == 0 or not DoesBlipExist(blip) then
        logTest('AddBlipForCoord hat keinen gültigen Blip geliefert.')
        return nil
    end

    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, false)
    safeSetBlipName(blip, label)

    testBlipHandle = blip
    return blip
end

RegisterCommand('ec_li_blip_test', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- Sprite 40 = Safehouse (Haus), Farbe 5 = Gelb (FiveM Blip-Colors)
    local sprite = 40
    local color = 5
    local scale = 0.9
    local label = 'Hallo'

    local blip = createMinimalBlip(coords.x, coords.y, coords.z, sprite, color, scale, label)

    logTest(('Test-Blip erstellt handle=%s sprite=%d color=%d label="%s" @ %.2f, %.2f, %.2f'):format(
        tostring(blip),
        sprite,
        color,
        label,
        coords.x,
        coords.y,
        coords.z
    ))
    logTest('Karte öffnen → Legende muss „Hallo“ zeigen (nicht Safehouse/Gang-Fahrzeug).')
end, false)

RegisterCommand('ec_li_blip_test_clear', function()
    removeTestBlip()
    logTest('Test-Blip entfernt.')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    removeTestBlip()
end)
