LiBridgeServerQbox = LiBridgeServerQbox or {}

local function qboxExport(name)
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core
    end
    if GetResourceState('qbox_core') == 'started' then
        return exports.qbox_core
    end
    return nil
end

function LiBridgeServerQbox.GetPlayer(source)
    local export = qboxExport()
    if not export or not export.GetPlayer then
        return LiBridgeServerQbcore.GetPlayer(source)
    end
    return export:GetPlayer(source)
end

function LiBridgeServerQbox.GetIdentifier(source)
    local player = LiBridgeServerQbox.GetPlayer(source)
    if not player or not player.PlayerData then
        return nil
    end
    return player.PlayerData.citizenid
end

function LiBridgeServerQbox.GetCharacterName(source)
    local player = LiBridgeServerQbox.GetPlayer(source)
    if not player or not player.PlayerData or not player.PlayerData.charinfo then
        return GetPlayerName(source)
    end
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

function LiBridgeServerQbox.GetGroup(source)
    local player = LiBridgeServerQbox.GetPlayer(source)
    if not player or not player.PlayerData then
        return nil
    end
    return player.PlayerData.group
end

function LiBridgeServerQbox.RegisterCallback(name, handler)
    if LiBridge.Library() == 'ox_lib' and lib and lib.callback and lib.callback.register then
        lib.callback.register(name, function(src, ...)
            return handler(src, ...)
        end)
        return true
    end
    return LiBridgeServerQbcore.RegisterCallback(name, handler)
end

function LiBridgeServerQbox.RegisterUsableItem(itemName, handler)
    local export = qboxExport()
    if export and export.CreateUseableItem then
        export:CreateUseableItem(itemName, handler)
        return true
    end
    return LiBridgeServerQbcore.RegisterUsableItem(itemName, handler)
end

function LiBridgeServerQbox.GetCash(player)
    if not player or not player.PlayerData or not player.PlayerData.money then
        return 0
    end
    return tonumber(player.PlayerData.money.cash) or 0
end

function LiBridgeServerQbox.GetBank(player)
    if not player or not player.PlayerData or not player.PlayerData.money then
        return 0
    end
    return tonumber(player.PlayerData.money.bank) or 0
end

function LiBridgeServerQbox.RemoveMoney(player, accountType, amount)
    if not player or not player.Functions or amount <= 0 then
        return false
    end
    return player.Functions.RemoveMoney(accountType, amount, 'ec_lifeinvader') == true
end

function LiBridgeServerQbox.AddMoney(player, accountType, amount)
    if not player or not player.Functions or amount <= 0 then
        return false
    end
    return player.Functions.AddMoney(accountType, amount, 'ec_lifeinvader') == true
end
