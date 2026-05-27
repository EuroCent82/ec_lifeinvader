LiBridgeClientOxTarget = LiBridgeClientOxTarget or {}

function LiBridgeClientOxTarget.RegisterEntity(entity, location, label, onSelect)
    if GetResourceState('ox_target') ~= 'started' then
        return false
    end

    local locationId = type(location) == 'table' and (location.id or 'unknown') or tostring(location)
    local dist = (type(location) == 'table' and tonumber(location.interactDistance)) or 2.5

    exports.ox_target:addLocalEntity(entity, {
        {
            name = ('ec_lifeinvader_%s'):format(locationId),
            icon = 'fa-solid fa-rectangle-ad',
            label = label or 'LifeInvader öffnen',
            distance = dist,
            onSelect = onSelect,
        },
    })
    return true
end

function LiBridgeClientOxTarget.RemoveEntity(entity)
    if GetResourceState('ox_target') ~= 'started' then
        return
    end
    pcall(function()
        exports.ox_target:removeLocalEntity(entity)
    end)
end
