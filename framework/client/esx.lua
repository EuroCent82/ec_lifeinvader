LiBridgeClientEsx = LiBridgeClientEsx or {}

local ESX

function LiBridgeClientEsx.GetEsx()
    if ESX then
        return ESX
    end
    if GetResourceState('es_extended') ~= 'started' then
        return nil
    end
    local ok, obj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if ok then
        ESX = obj
    end
    return ESX
end

function LiBridgeClientEsx.ShowHelp(text)
    local esx = LiBridgeClientEsx.GetEsx()
    if esx and esx.ShowHelpNotification then
        esx.ShowHelpNotification(text)
        return true
    end
    return false
end

function LiBridgeClientEsx.Notify(message, notifyType)
    local esx = LiBridgeClientEsx.GetEsx()
    if esx and esx.ShowNotification then
        esx.ShowNotification(message)
        return true
    end
    return false
end
