LiBridgeServerInventory = LiBridgeServerInventory or {}

local function itemCfg()
    return Config.Item or {}
end

function LiBridgeServerInventory.HasItem(source, itemName, amount)
    amount = tonumber(amount) or 1
    itemName = tostring(itemName or '')
    if itemName == '' then
        return false
    end

    local adapter = LiBridge.Inventory()

    if adapter == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:Search(source, 'count', itemName) or 0
        return count >= amount
    end

    if adapter == 'esx' then
        local xPlayer = LiBridgeServerEsx.GetPlayer(source)
        if not xPlayer or not xPlayer.getInventoryItem then
            return false
        end
        local item = xPlayer.getInventoryItem(itemName)
        return item and (item.count or 0) >= amount
    end

    if adapter == 'qb-inventory' or adapter == 'qb_inventory' then
        local player = LiBridgeServerQbcore.GetPlayer(source)
        if not player or not player.Functions or not player.Functions.GetItemByName then
            return false
        end
        local item = player.Functions.GetItemByName(itemName)
        return item and (item.amount or 0) >= amount
    end

    if adapter == 'qs-inventory' and GetResourceState('qs-inventory') == 'started' then
        local ok, count = pcall(function()
            return exports['qs-inventory']:GetItemTotalAmount(source, itemName)
        end)
        return ok and (tonumber(count) or 0) >= amount
    end

    return false
end

function LiBridgeServerInventory.GetPhoneNumber(source)
    local cfg = Config.Phone or {}
    local phoneItems = cfg.items or { 'phone', 'black_phone', 'yellow_phone' }

    local adapter = LiBridge.Inventory()

    if adapter == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        for i = 1, #phoneItems do
            local itemName = phoneItems[i]
            local items = exports.ox_inventory:Search(source, 'slots', itemName)
            if type(items) == 'table' then
                for _, slot in pairs(items) do
                    local meta = slot.metadata or slot.info
                    local number = meta and (meta.phone or meta.number or meta.phoneNumber)
                    if number and tostring(number) ~= '' then
                        return tostring(number)
                    end
                end
            end
        end
    end

    if adapter == 'esx' then
        for i = 1, #phoneItems do
            if LiBridgeServerInventory.HasItem(source, phoneItems[i], 1) then
                if cfg.esxDefaultNumber then
                    return tostring(cfg.esxDefaultNumber)
                end
                break
            end
        end
    end

    if adapter == 'qb-inventory' or adapter == 'qb_inventory' then
        local player = LiBridgeServerQbcore.GetPlayer(source)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local phone = player.PlayerData.charinfo.phone
            if phone and tostring(phone) ~= '' then
                return tostring(phone)
            end
        end
    end

    local fw = LiBridge.Framework()
    if fw == 'qbcore' or fw == 'qbox' then
        local player = fw == 'qbox' and LiBridgeServerQbox.GetPlayer(source) or LiBridgeServerQbcore.GetPlayer(source)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local phone = player.PlayerData.charinfo.phone
            if phone and tostring(phone) ~= '' then
                return tostring(phone)
            end
        end
    end

    return nil
end

function LiBridgeServerInventory.RegisterOpenItem()
    local cfg = itemCfg()
    if cfg.enabled ~= true then
        return
    end

    local itemName = tostring(cfg.name or 'lifeinvader_tablet')
    local handler = function(source)
        if not LiBridge.Server.HasPermission(source, 'open') then
            return
        end
        TriggerClientEvent('ec_lifeinvader:client:openFromItem', source)
    end

    local adapter = LiBridge.Inventory()
    if adapter == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        if exports.ox_inventory.RegisterUsableItem then
            exports.ox_inventory:RegisterUsableItem(itemName, function(_, item)
                handler(item and item.source or source)
            end)
            return
        end

        AddEventHandler('ox_inventory:usedItem', function(playerId, name)
            if name == itemName then
                handler(playerId)
            end
        end)
        return
    end

    if LiBridge.Framework() == 'esx' then
        LiBridgeServerEsx.RegisterUsableItem(itemName, handler)
        return
    end

    if LiBridge.Framework() == 'qbox' then
        LiBridgeServerQbox.RegisterUsableItem(itemName, handler)
        return
    end

    LiBridgeServerQbcore.RegisterUsableItem(itemName, handler)
end

function LiBridgeServerInventory.PlayerHasPhone(source)
    local cfg = Config.Phone or {}
    local phoneItems = cfg.items or { 'phone' }
    for i = 1, #phoneItems do
        if LiBridgeServerInventory.HasItem(source, phoneItems[i], 1) then
            return true
        end
    end
    return cfg.requirePhoneItem ~= true
end
