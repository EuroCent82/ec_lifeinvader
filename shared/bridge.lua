--[[ ec_lifeinvader — Shared Bridge (Adapter-Auflösung) ]]

LiBridge = LiBridge or {}

function LiBridge.Adapters()
    return Config.Adapters or {}
end

function LiBridge.Debug(...)
    if Config.Debug then
        print('^3[ec_lifeinvader]^0', ...)
    end
end

function LiBridge.Framework()
    return string.lower(tostring(LiBridge.Adapters().framework or Config.Framework or 'esx'))
end

function LiBridge.Target()
    return string.lower(tostring(LiBridge.Adapters().target or Config.Target or 'ox_target'))
end

function LiBridge.Inventory()
    return string.lower(tostring(LiBridge.Adapters().inventory or Config.Inventory or 'ox_inventory'))
end

function LiBridge.MySql()
    local raw = LiBridge.Adapters().mysql or Config.MySQL or 'oxmysql'
    raw = string.lower(tostring(raw)):gsub('^%s+', ''):gsub('%s+$', '')
    if raw == 'mysql_async' then
        return 'mysql-async'
    end
    return raw
end

function LiBridge.Library()
    return string.lower(tostring(LiBridge.Adapters().library or Config.Library or 'ox_lib'))
end

function LiBridge.ResolveLocationInteraction(location)
    if type(location) == 'table' and location.interaction ~= nil then
        return string.lower(tostring(location.interaction))
    end
    local cfg = Config.Interaction or {}
    return string.lower(tostring(cfg.mode or 'target'))
end

function LiBridge.NormalizeLocationType(location)
    return string.lower(tostring((location and location.type) or 'npc'))
end

function LiBridge.Vec4Parts(coords)
    if coords == nil then
        return nil
    end
    local t = type(coords)
    if t == 'vector3' or t == 'vector4' then
        return coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, (coords.w or coords.h or 0.0) + 0.0
    end
    if t ~= 'table' then
        return nil
    end
    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])
    local w = tonumber(coords.w or coords.h or coords[4]) or 0.0
    if not x or not y or not z then
        return nil
    end
    return x, y, z, w
end
