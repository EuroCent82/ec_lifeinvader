LiBridge = LiBridge or {}
LiBridge.Client = LiBridge.Client or {}

function LiBridge.Client.Notify(message, notifyType)
    local adapter = LiBridge.Library()

    if adapter == 'ox_lib' and lib and lib.notify then
        lib.notify({
            title = 'LifeInvader',
            description = message,
            type = notifyType or 'inform',
        })
        return true
    end

    if LiBridgeClientEsx and LiBridgeClientEsx.Notify(message, notifyType) then
        return true
    end

    LiBridge.Debug(message)
    return false
end

function LiBridge.Client.RegisterEntityInteraction(entity, location, label, onSelect)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    local mode = LiBridge.ResolveLocationInteraction(location)
    if mode == 'native' then
        LiBridgeClientNative.RegisterZone(location, onSelect)
        return true
    end

    if mode == 'item' then
        return false
    end

    local target = LiBridge.Target()

    if target == 'custom' and LiBridgeClientCustom.RegisterEntity(entity, location, label, onSelect) then
        return true
    end

    if target == 'ox_target' and LiBridgeClientOxTarget.RegisterEntity(entity, location, label, onSelect) then
        return true
    end

    if (target == 'qb-target' or target == 'qtarget') and LiBridgeClientQbTarget.RegisterEntity(entity, location, label, onSelect) then
        return true
    end

    LiBridgeClientNative.RegisterZone(location, onSelect)
    LiBridge.Debug('Target nicht verfügbar — Fallback native für', location.id or '?')
    return true
end

function LiBridge.Client.RemoveEntityInteraction(entity)
    if not entity or entity == 0 then
        return
    end

    local target = LiBridge.Target()
    if target == 'custom' then
        LiBridgeClientCustom.RemoveEntity(entity)
    elseif target == 'ox_target' then
        LiBridgeClientOxTarget.RemoveEntity(entity)
    elseif target == 'qb-target' or target == 'qtarget' then
        LiBridgeClientQbTarget.RemoveEntity(entity)
    end
end

function LiBridge.Client.RegisterNativeZone(location, onSelect)
    LiBridgeClientNative.RegisterZone(location, onSelect)
end

function LiBridge.Client.ClearNativeZones()
    LiBridgeClientNative.Clear()
end

function LiBridge.Client.UsesTargetSystem()
    local mode = string.lower(tostring((Config.Interaction or {}).mode or 'target'))
    if mode == 'native' or mode == 'item' then
        return false
    end
    local target = LiBridge.Target()
    return target == 'ox_target' or target == 'qb-target' or target == 'qtarget' or target == 'custom'
end
