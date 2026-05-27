LiBridgeClientNative = LiBridgeClientNative or {}

local nativeZones = {}

function LiBridgeClientNative.RegisterZone(location, onSelect)
    if type(location) ~= 'table' or type(onSelect) ~= 'function' then
        return
    end
    nativeZones[#nativeZones + 1] = {
        location = location,
        onSelect = onSelect,
    }
end

function LiBridgeClientNative.Clear()
    nativeZones = {}
end

local function showHelp(text)
    if LiBridge.Library() == 'ox_lib' and lib and lib.showTextUI then
        lib.showTextUI(text, { position = 'left-center' })
        return
    end
    if LiBridgeClientEsx and LiBridgeClientEsx.ShowHelp(text) then
        return
    end
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function hideHelp()
    if LiBridge.Library() == 'ox_lib' and lib and lib.hideTextUI then
        lib.hideTextUI()
    end
end

CreateThread(function()
    local activeHelp = false

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local nearZone = nil

        for i = 1, #nativeZones do
            local zone = nativeZones[i]
            local loc = zone.location
            local x, y, z = LiBridge.Vec4Parts(loc.coords)
            if x then
                local maxDist = tonumber(loc.interactDistance)
                    or tonumber((Config.Interaction or {}).nativeDistance)
                    or 2.5
                local dist = #(pos - vector3(x, y, z))
                if dist <= maxDist then
                    nearZone = zone
                    sleep = 0
                    break
                end
            end
        end

        if nearZone then
            local keyLabel = (Config.Interaction or {}).nativeKeyLabel or 'E'
            showHelp(('[~g~%s~s~] %s'):format(keyLabel, nearZone.location.label or 'LifeInvader öffnen'))
            activeHelp = true

            local key = tonumber((Config.Interaction or {}).nativeKey) or 38
            if IsControlJustReleased(0, key) then
                nearZone.onSelect(nearZone.location)
            end
        elseif activeHelp then
            hideHelp()
            activeHelp = false
        end

        Wait(sleep)
    end
end)
