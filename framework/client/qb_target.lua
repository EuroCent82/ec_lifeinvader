LiBridgeClientQbTarget = LiBridgeClientQbTarget or {}

local function qbTargetExport()
    if GetResourceState('qb-target') == 'started' then
        return exports['qb-target']
    end
    if GetResourceState('qtarget') == 'started' then
        return exports.qtarget
    end
    return nil
end

function LiBridgeClientQbTarget.RegisterEntity(entity, location, label, onSelect)
    local target = qbTargetExport()
    if not target or not target.AddTargetEntity then
        return false
    end

    local dist = (type(location) == 'table' and tonumber(location.interactDistance)) or 2.5

    target:AddTargetEntity(entity, {
        options = {
            {
                icon = 'fas fa-bullhorn',
                label = label or 'LifeInvader öffnen',
                action = onSelect,
            },
        },
        distance = dist,
    })
    return true
end

function LiBridgeClientQbTarget.RemoveEntity(entity)
    local target = qbTargetExport()
    if not target then
        return
    end
    pcall(function()
        if target.RemoveTargetEntity then
            target:RemoveTargetEntity(entity)
        end
    end)
end
