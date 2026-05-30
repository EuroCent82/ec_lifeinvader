LiBridge = LiBridge or {}
LiBridgeServerAccount = LiBridgeServerAccount or {}

function LiBridgeServerAccount.GetAccountRow(identifier, cb)
    if not identifier then
        cb({ balance = 0, ad_slot_bonus = 0, ad_duration_bonus_days = 0 })
        return
    end

    LiBridge.MySQL.Query(
        'SELECT balance, ad_slot_bonus, ad_duration_bonus_days FROM lifeinvader WHERE identifier = ? LIMIT 1',
        { identifier },
        function(result)
            if result and result[1] then
                cb(result[1])
                return
            end

            LiBridge.MySQL.Insert(
                'INSERT INTO lifeinvader (identifier, balance, ad_slot_bonus, ad_duration_bonus_days) VALUES (?, 0, 0, 0)',
                { identifier },
                function()
                    cb({ balance = 0, ad_slot_bonus = 0, ad_duration_bonus_days = 0 })
                end
            )
        end
    )
end

function LiBridgeServerAccount.GetBalance(identifier, cb)
    if not identifier then
        cb(0)
        return
    end

    LiBridgeServerAccount.GetAccountRow(identifier, function(row)
        cb(tonumber(row.balance) or 0)
    end)
end

function LiBridgeServerAccount.RemoveBalance(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        if cb then
            cb(false, 0, 'invalid_amount')
        end
        return
    end

    LiBridge.MySQL.Execute(
        [[UPDATE lifeinvader
          SET balance = balance - ?, updated_at = CURRENT_TIMESTAMP
          WHERE identifier = ? AND balance >= ?]],
        { amount, identifier, amount },
        function(affected)
            local rows = tonumber(affected) or 0
            if rows < 1 then
                LiBridgeServerAccount.GetBalance(identifier, function(current)
                    if cb then
                        cb(false, current, current < amount and 'insufficient_balance' or 'db_failed')
                    end
                end)
                return
            end

            LiBridgeServerAccount.GetBalance(identifier, function(nextBalance)
                if cb then
                    cb(true, nextBalance, nil)
                end
            end)
        end
    )
end

function LiBridgeServerAccount.AddBalance(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        if cb then
            cb(false, 0)
        end
        return
    end

    LiBridge.MySQL.Execute(
        [[UPDATE lifeinvader
          SET balance = balance + ?, updated_at = CURRENT_TIMESTAMP
          WHERE identifier = ?]],
        { amount, identifier },
        function(affected)
            local rows = tonumber(affected) or 0
            if rows > 0 then
                LiBridgeServerAccount.GetBalance(identifier, function(nextBalance)
                    if cb then
                        cb(true, nextBalance)
                    end
                end)
                return
            end

            LiBridge.MySQL.Insert(
                'INSERT INTO lifeinvader (identifier, balance) VALUES (?, ?)',
                { identifier, amount },
                function()
                    if cb then
                        cb(true, amount)
                    end
                end
            )
        end
    )
end

function LiBridgeServerAccount.Deposit(source, amount, payFrom, cb)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        local response = { ok = false, error = 'invalid_amount' }
        if cb then
            cb(response)
        end
        return response
    end

    local depositCfg = Config.Deposit or {}
    payFrom = tostring(payFrom or 'bank')

    if payFrom == 'cash' and depositCfg.cash == false then
        local response = { ok = false, error = 'cash_disabled' }
        if cb then
            cb(response)
        end
        return response
    end
    if payFrom == 'bank' and depositCfg.bank == false then
        local response = { ok = false, error = 'bank_disabled' }
        if cb then
            cb(response)
        end
        return response
    end

    local canPay, resolved = LiBridgeServerFinance.CanPay(source, amount, payFrom)
    if not canPay or not resolved then
        local response = { ok = false, error = 'insufficient_funds' }
        if cb then
            cb(response)
        end
        return response
    end

    if not LiBridgeServerFinance.RemoveMoney(source, resolved, amount) then
        local response = { ok = false, error = 'payment_failed' }
        if cb then
            cb(response)
        end
        return response
    end

    local identifier = LiBridge.Server.GetIdentifier(source)
    if not identifier then
        LiBridgeServerFinance.AddMoney(source, resolved, amount)
        local response = { ok = false, error = 'no_identifier' }
        if cb then
            cb(response)
        end
        return response
    end

    if cb then
        LiBridgeServerAccount.AddBalance(identifier, amount, function(ok, balance)
            if not ok then
                LiBridgeServerFinance.AddMoney(source, resolved, amount)
                cb({ ok = false, error = 'db_failed' })
                return
            end
            cb({ ok = true, balance = balance })
        end)
        return
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
        Wait(50)
    end

    return response
end

LiBridge.Server.RegisterCallback('ec_lifeinvader:deposit', function(source, amount, payFrom)
    return LiBridgeServerAccount.Deposit(source, amount, payFrom)
end)

RegisterNetEvent('ec_lifeinvader:server:deposit', function(requestId, amount, payFrom)
    local src = source
    LiBridgeServerAccount.Deposit(src, amount, payFrom, function(result)
        TriggerClientEvent('ec_lifeinvader:client:depositResult', src, requestId, result)
    end)
end)
