LiBridge = LiBridge or {}
LiBridgeServerAccount = LiBridgeServerAccount or {}

function LiBridgeServerAccount.GetBalance(identifier, cb)
    if not identifier then
        cb(0)
        return
    end

    LiBridge.MySQL.Query(
        'SELECT balance FROM lifeinvader WHERE identifier = ? LIMIT 1',
        { identifier },
        function(result)
            if result and result[1] then
                cb(tonumber(result[1].balance) or 0)
                return
            end

            LiBridge.MySQL.Insert(
                'INSERT INTO lifeinvader (identifier, balance) VALUES (?, 0)',
                { identifier },
                function()
                    cb(0)
                end
            )
        end
    )
end

function LiBridgeServerAccount.RemoveBalance(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        if cb then
            cb(false, 0, 'invalid_amount')
        end
        return
    end

    LiBridgeServerAccount.GetBalance(identifier, function(current)
        if current < amount then
            if cb then
                cb(false, current, 'insufficient_balance')
            end
            return
        end

        local nextBalance = current - amount
        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE identifier = ?',
            { nextBalance, identifier },
            function(affected)
                local rows = tonumber(affected) or 0
                if rows > 0 then
                    if cb then
                        cb(true, nextBalance, nil)
                    end
                    return
                end

                if cb then
                    cb(false, current, 'db_failed')
                end
            end
        )
    end)
end

function LiBridgeServerAccount.AddBalance(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        if cb then
            cb(false, 0)
        end
        return
    end

    LiBridgeServerAccount.GetBalance(identifier, function(current)
        local nextBalance = current + amount
        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE identifier = ?',
            { nextBalance, identifier },
            function(affected)
                local rows = tonumber(affected) or 0
                if rows > 0 then
                    if cb then
                        cb(true, nextBalance)
                    end
                    return
                end

                LiBridge.MySQL.Insert(
                    'INSERT INTO lifeinvader (identifier, balance) VALUES (?, ?)',
                    { identifier, nextBalance },
                    function()
                        if cb then
                            cb(true, nextBalance)
                        end
                    end
                )
            end
        )
    end)
end

function LiBridgeServerAccount.Deposit(source, amount, payFrom)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return { ok = false, error = 'invalid_amount' }
    end

    local depositCfg = Config.Deposit or {}
    payFrom = tostring(payFrom or 'bank')

    if payFrom == 'cash' and depositCfg.cash == false then
        return { ok = false, error = 'cash_disabled' }
    end
    if payFrom == 'bank' and depositCfg.bank == false then
        return { ok = false, error = 'bank_disabled' }
    end

    local canPay, resolved = LiBridgeServerFinance.CanPay(source, amount, payFrom)
    if not canPay or not resolved then
        return { ok = false, error = 'insufficient_funds' }
    end

    if not LiBridgeServerFinance.RemoveMoney(source, resolved, amount) then
        return { ok = false, error = 'payment_failed' }
    end

    local identifier = LiBridge.Server.GetIdentifier(source)
    if not identifier then
        LiBridgeServerFinance.AddMoney(source, resolved, amount)
        return { ok = false, error = 'no_identifier' }
    end

    local done = false
    local response = { ok = false, error = 'timeout' }

    LiBridgeServerAccount.AddBalance(identifier, amount, function(ok, balance)
        if not ok then
            LiBridgeServerFinance.AddMoney(source, resolved, amount)
            response = { ok = false, error = 'db_failed' }
        else
            response = { ok = true, balance = balance }
        end
        done = true
    end)

    while not done do
        Wait(0)
    end

    return response
end

LiBridge.Server.RegisterCallback('ec_lifeinvader:deposit', function(source, amount, payFrom)
    return LiBridgeServerAccount.Deposit(source, amount, payFrom)
end)

RegisterNetEvent('ec_lifeinvader:server:deposit', function(requestId, amount, payFrom)
    local src = source
    local result = LiBridgeServerAccount.Deposit(src, amount, payFrom)
    TriggerClientEvent('ec_lifeinvader:client:depositResult', src, requestId, result)
end)
