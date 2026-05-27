LiBridgeServerQbcore = LiBridgeServerQbcore or {}

local QBCore

function LiBridgeServerQbcore.GetCore()
    if QBCore then
        return QBCore
    end
    if GetResourceState('qb-core') ~= 'started' then
        return nil
    end
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok then
        QBCore = core
    end
    return QBCore
end

function LiBridgeServerQbcore.GetPlayer(source)
    local core = LiBridgeServerQbcore.GetCore()
    if not core or not core.Functions or not core.Functions.GetPlayer then
        return nil
    end
    return core.Functions.GetPlayer(source)
end

function LiBridgeServerQbcore.GetIdentifier(source)
    local player = LiBridgeServerQbcore.GetPlayer(source)
    if not player or not player.PlayerData then
        return nil
    end
    return player.PlayerData.citizenid
end

function LiBridgeServerQbcore.GetCharacterName(source)
    local player = LiBridgeServerQbcore.GetPlayer(source)
    if not player or not player.PlayerData or not player.PlayerData.charinfo then
        return GetPlayerName(source)
    end
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

function LiBridgeServerQbcore.GetGroup(source)
    local player = LiBridgeServerQbcore.GetPlayer(source)
    if not player or not player.PlayerData then
        return nil
    end
    if player.PlayerData.group then
        return player.PlayerData.group
    end
    if player.Functions and player.Functions.GetPermission then
        return player.Functions.GetPermission()
    end
    return nil
end

function LiBridgeServerQbcore.RegisterCallback(name, handler)
    local core = LiBridgeServerQbcore.GetCore()
    if not core or not core.Functions or not core.Functions.CreateCallback then
        return false
    end
    core.Functions.CreateCallback(name, function(src, cb, ...)
        cb(handler(src, ...))
    end)
    return true
end

function LiBridgeServerQbcore.RegisterUsableItem(itemName, handler)
    local core = LiBridgeServerQbcore.GetCore()
    if not core or not core.Functions or not core.Functions.CreateUseableItem then
        return false
    end
    core.Functions.CreateUseableItem(itemName, handler)
    return true
end

function LiBridgeServerQbcore.GetCash(player)
    if not player or not player.PlayerData or not player.PlayerData.money then
        return 0
    end
    return tonumber(player.PlayerData.money.cash) or 0
end

function LiBridgeServerQbcore.GetBank(player)
    if not player or not player.PlayerData or not player.PlayerData.money then
        return 0
    end
    return tonumber(player.PlayerData.money.bank) or 0
end

function LiBridgeServerQbcore.RemoveMoney(player, accountType, amount)
    if not player or not player.Functions or amount <= 0 then
        return false
    end
    return player.Functions.RemoveMoney(accountType, amount, 'ec_lifeinvader') == true
end

function LiBridgeServerQbcore.AddMoney(player, accountType, amount)
    if not player or not player.Functions or amount <= 0 then
        return false
    end
    return player.Functions.AddMoney(accountType, amount, 'ec_lifeinvader') == true
end
