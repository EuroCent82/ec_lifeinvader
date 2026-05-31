--[[ ec_lifeinvader — Gutscheine: Validierung & Einlösung ]]

LiBridgeServerVouchers = LiBridgeServerVouchers or {}

local function vouchersCfg()
    return Config.Vouchers or {}
end

function LiBridgeServerVouchers.Enabled()
    return vouchersCfg().enabled ~= false
end

function LiBridgeServerVouchers.NormalizeCode(code)
    if type(code) ~= 'string' then
        return ''
    end

    code = code:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    code = code:gsub('%s+', '')
    return code
end

local function respond(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:voucherResult', src, requestId, payload)
end

function LiBridgeServerVouchers.EvaluateCode(code, identifier, cb)
    code = LiBridgeServerVouchers.NormalizeCode(code)

    if code == '' then
        cb(false, 'empty_code', nil, nil)
        return
    end

    if not identifier then
        cb(false, 'no_identifier', nil, nil)
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT v.id, v.code, v.value, v.max_uses, v.uses_count, v.enabled, v.bound_identifier,
                 (v.expires_at IS NULL OR v.expires_at > NOW()) AS not_expired,
                 (SELECT COUNT(*) FROM lifeinvader_voucher_redemptions r
                  WHERE r.voucher_id = v.id AND r.identifier = ?) AS player_redeemed
          FROM lifeinvader_vouchers v
          WHERE v.code = ?
          LIMIT 1]],
        { identifier, code },
        function(rows)
            local row = rows and rows[1]
            if not row then
                cb(false, 'not_found', nil, nil)
                return
            end

            local value = tonumber(row.value) or 0
            local voucherId = tonumber(row.id)

            if not (row.enabled == 1 or row.enabled == true) then
                cb(false, 'disabled', value, voucherId)
                return
            end

            if not (row.not_expired == 1 or row.not_expired == true) then
                cb(false, 'expired', value, voucherId)
                return
            end

            local maxUses = row.max_uses and tonumber(row.max_uses) or nil
            local usesCount = tonumber(row.uses_count) or 0
            if maxUses and usesCount >= maxUses then
                cb(false, 'exhausted', value, voucherId)
                return
            end

            local bound = row.bound_identifier
            if bound and bound ~= '' and bound ~= identifier then
                cb(false, 'bound_player', value, voucherId)
                return
            end

            if tonumber(row.player_redeemed) and tonumber(row.player_redeemed) > 0 then
                cb(false, 'already_redeemed', value, voucherId)
                return
            end

            cb(true, nil, value, voucherId)
        end
    )
end

local function redeemAfterEvaluate(src, requestId, identifier, code, voucherId, value)
    LiBridge.MySQL.Insert(
        'INSERT INTO lifeinvader_voucher_redemptions (voucher_id, identifier) VALUES (?, ?)',
        { voucherId, identifier },
        function(redemptionId)
            if not redemptionId then
                respond(src, requestId, { ok = false, error = 'already_redeemed' })
                return
            end

            LiBridge.MySQL.Execute(
                [[UPDATE lifeinvader_vouchers
                  SET uses_count = uses_count + 1, updated_at = CURRENT_TIMESTAMP
                  WHERE id = ?
                    AND enabled = 1
                    AND (expires_at IS NULL OR expires_at > NOW())
                    AND (max_uses IS NULL OR uses_count < max_uses)]],
                { voucherId },
                function(affected)
                    if (tonumber(affected) or 0) < 1 then
                        LiBridge.MySQL.Execute(
                            'DELETE FROM lifeinvader_voucher_redemptions WHERE id = ?',
                            { redemptionId },
                            function() end
                        )
                        respond(src, requestId, { ok = false, error = 'exhausted' })
                        return
                    end

                    LiBridgeServerAccount.AddBalance(identifier, value, function(ok, balance)
                        if not ok then
                            respond(src, requestId, { ok = false, error = 'balance_failed' })
                            return
                        end

                        respond(src, requestId, {
                            ok = true,
                            redeemed = true,
                            value = value,
                            balance = balance,
                            code = code,
                        })
                    end)
                end
            )
        end
    )
end

RegisterNetEvent('ec_lifeinvader:server:validateVoucher', function(requestId, code)
    local src = source

    if not LiBridgeServerVouchers.Enabled() then
        respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respond(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    LiBridgeServerBlacklist.IsBanned(identifier, function(banned)
        if banned then
            respond(src, requestId, { ok = false, error = 'blacklisted' })
            return
        end

        LiBridgeServerVouchers.EvaluateCode(code, identifier, function(valid, errorKey, value)
            if not valid then
                respond(src, requestId, {
                    ok = true,
                    valid = false,
                    error = errorKey,
                    value = value,
                })
                return
            end

            respond(src, requestId, {
                ok = true,
                valid = true,
                value = value,
                code = LiBridgeServerVouchers.NormalizeCode(code),
            })
        end)
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:redeemVoucher', function(requestId, code)
    local src = source

    if not LiBridgeServerVouchers.Enabled() then
        respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respond(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    LiBridgeServerBlacklist.IsBanned(identifier, function(banned)
        if banned then
            respond(src, requestId, { ok = false, error = 'blacklisted' })
            return
        end

        local normalized = LiBridgeServerVouchers.NormalizeCode(code)
        LiBridgeServerVouchers.EvaluateCode(normalized, identifier, function(valid, errorKey, value, voucherId)
            if not valid then
                respond(src, requestId, { ok = false, error = errorKey or 'invalid_voucher' })
                return
            end

            redeemAfterEvaluate(src, requestId, identifier, normalized, voucherId, value)
        end)
    end)
end)
