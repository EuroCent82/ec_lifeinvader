LiBridgeClientCustom = LiBridgeClientCustom or {}

function LiBridgeClientCustom.RegisterEntity(entity, location, label, onSelect)
    local bridge = (Config.Adapters or {}).customBridge or Config.Custom
    if type(bridge) ~= 'table' then
        return false
    end
    local fn = bridge.ClientRegisterTargetEntity
    if type(fn) ~= 'function' then
        return false
    end
    return fn(entity, location, label, onSelect) == true
end

function LiBridgeClientCustom.RemoveEntity(entity)
    local bridge = (Config.Adapters or {}).customBridge or Config.Custom
    if type(bridge) ~= 'table' then
        return
    end
    local fn = bridge.ClientRemoveTargetEntity
    if type(fn) == 'function' then
        fn(entity)
    end
end
