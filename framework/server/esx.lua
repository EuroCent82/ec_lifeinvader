LiBridgeServerEsx = LiBridgeServerEsx or {}

local ESX

function LiBridgeServerEsx.GetEsx()
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

function LiBridgeServerEsx.GetPlayer(source)
    local esx = LiBridgeServerEsx.GetEsx()
    if not esx or not esx.GetPlayerFromId then
        return nil
    end
    return esx.GetPlayerFromId(source)
end

function LiBridgeServerEsx.GetIdentifier(source)
    local xPlayer = LiBridgeServerEsx.GetPlayer(source)
    if not xPlayer then
        return nil
    end
    return xPlayer.identifier or xPlayer.getIdentifier and xPlayer.getIdentifier()
end

function LiBridgeServerEsx.GetCharacterName(source)
    local xPlayer = LiBridgeServerEsx.GetPlayer(source)
    if not xPlayer then
        return nil
    end
    if xPlayer.getName then
        return xPlayer.getName()
    end
    local first = xPlayer.get and xPlayer.get('firstName') or xPlayer.firstName
    local last = xPlayer.get and xPlayer.get('lastName') or xPlayer.lastName
    if first and last then
        return ('%s %s'):format(first, last)
    end
    return GetPlayerName(source)
end

function LiBridgeServerEsx.GetGroup(source)
    local xPlayer = LiBridgeServerEsx.GetPlayer(source)
    if not xPlayer then
        return nil
    end
    if xPlayer.getGroup then
        return xPlayer.getGroup()
    end
    return xPlayer.group
end

function LiBridgeServerEsx.RegisterCallback(name, handler)
    local esx = LiBridgeServerEsx.GetEsx()
    if not esx or not esx.RegisterServerCallback then
        return false
    end
    esx.RegisterServerCallback(name, function(src, cb, ...)
        cb(handler(src, ...))
    end)
    return true
end

function LiBridgeServerEsx.RegisterUsableItem(itemName, handler)
    local esx = LiBridgeServerEsx.GetEsx()
    if not esx or not esx.RegisterUsableItem then
        return false
    end
    esx.RegisterUsableItem(itemName, handler)
    return true
end

function LiBridgeServerEsx.GetCash(xPlayer)
    if not xPlayer or not xPlayer.getMoney then
        return 0
    end
    return tonumber(xPlayer.getMoney()) or 0
end

function LiBridgeServerEsx.GetBank(xPlayer)
    if not xPlayer or not xPlayer.getAccount then
        return 0
    end
    local account = xPlayer.getAccount('bank')
    return account and tonumber(account.money) or 0
end

function LiBridgeServerEsx.RemoveMoney(xPlayer, accountType, amount)
    if not xPlayer or amount <= 0 then
        return false
    end

    amount = math.floor(amount)

    if accountType == 'cash' then
        if xPlayer.removeMoney then
            xPlayer.removeMoney(amount)
            return true
        end
        return false
    end

    if accountType == 'bank' and xPlayer.removeAccountMoney then
        xPlayer.removeAccountMoney('bank', amount)
        return true
    end

    return false
end

function LiBridgeServerEsx.AddMoney(xPlayer, accountType, amount)
    if not xPlayer or amount <= 0 then
        return false
    end

    amount = math.floor(amount)

    if accountType == 'cash' then
        if xPlayer.addMoney then
            xPlayer.addMoney(amount)
            return true
        end
        return false
    end

    if accountType == 'bank' and xPlayer.addAccountMoney then
        xPlayer.addAccountMoney('bank', amount)
        return true
    end

    return false
end
