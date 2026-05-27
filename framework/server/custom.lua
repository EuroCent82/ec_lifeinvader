LiBridgeServerCustom = LiBridgeServerCustom or {}

function LiBridgeServerCustom.Call(fnName, ...)
    local bridge = (Config.Adapters or {}).customBridge or Config.Custom
    if type(bridge) ~= 'table' then
        return nil
    end
    local fn = bridge[fnName]
    if type(fn) ~= 'function' then
        return nil
    end
    return fn(...)
end
