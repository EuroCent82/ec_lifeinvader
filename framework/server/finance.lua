LiBridgeServerFinance = LiBridgeServerFinance or {}

local function frameworkModule()
    local fw = LiBridge.Framework()
    if fw == 'qbcore' then
        return LiBridgeServerQbcore
    end
    if fw == 'qbox' then
        return LiBridgeServerQbox
    end
    return LiBridgeServerEsx
end

function LiBridgeServerFinance.GetPlayer(source)
    return frameworkModule().GetPlayer(source)
end

function LiBridgeServerFinance.GetCash(source)
    local player = LiBridgeServerFinance.GetPlayer(source)
    if not player then
        return 0
    end
    return frameworkModule().GetCash(player)
end

function LiBridgeServerFinance.GetBank(source)
    local player = LiBridgeServerFinance.GetPlayer(source)
    if not player then
        return 0
    end
    return frameworkModule().GetBank(player)
end

local function paymentCfg()
    return Config.Payment or {}
end

function LiBridgeServerFinance.CanPay(source, amount, mode)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return true, nil
    end

    local cashAllowed = Config.Deposit and Config.Deposit.cash ~= false
    local bankAllowed = Config.Deposit and Config.Deposit.bank ~= false
    local cash = LiBridgeServerFinance.GetCash(source)
    local bank = LiBridgeServerFinance.GetBank(source)

    mode = mode or paymentCfg().preferred or 'bank'

    if mode == 'cash' and cashAllowed then
        return cash >= amount, cash >= amount and 'cash' or nil
    end

    if mode == 'bank' and bankAllowed then
        return bank >= amount, bank >= amount and 'bank' or nil
    end

    if mode == 'both' or paymentCfg().allowBoth == true then
        local priority = paymentCfg().preferredWhenBoth or 'bank'
        if priority == 'cash' then
            if cashAllowed and cash >= amount then return true, 'cash' end
            if bankAllowed and bank >= amount then return true, 'bank' end
        else
            if bankAllowed and bank >= amount then return true, 'bank' end
            if cashAllowed and cash >= amount then return true, 'cash' end
        end
    end

    return false, nil
end

function LiBridgeServerFinance.RemoveMoney(source, accountType, amount)
    local player = LiBridgeServerFinance.GetPlayer(source)
    if not player then
        return false
    end
    return frameworkModule().RemoveMoney(player, accountType, amount)
end

function LiBridgeServerFinance.AddMoney(source, accountType, amount)
    local player = LiBridgeServerFinance.GetPlayer(source)
    if not player then
        return false
    end
    return frameworkModule().AddMoney(player, accountType, amount)
end

function LiBridgeServerFinance.AttachWalletSnapshot(source, response)
    response = response or {}
    response.cash = LiBridgeServerFinance.GetCash(source)
    response.bank = LiBridgeServerFinance.GetBank(source)
    return response
end

function LiBridgeServerFinance.CanWithdrawTo(accountType)
    if accountType == 'cash' then
        return Config.Withdraw and Config.Withdraw.cash ~= false
    end
    if accountType == 'bank' then
        return Config.Withdraw and Config.Withdraw.bank == true
    end
    return false
end
