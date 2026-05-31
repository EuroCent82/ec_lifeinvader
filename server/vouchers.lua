--[[ ec_lifeinvader — Gutscheine: Validierung & Einlösung (nur bei Anzeigen-Buchung) ]]

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
        cb(false, 'empty_code', nil, nil, false)
        return
    end

    if not identifier then
        cb(false, 'no_identifier', nil, nil, false)
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT v.id, v.code, v.value, v.max_uses, v.uses_count, v.enabled,
                 COALESCE(v.per_player_once, 0) AS per_player_once,
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
                cb(false, 'not_found', nil, nil, false)
                return
            end

            local value = tonumber(row.value) or 0
            local voucherId = tonumber(row.id)
            local perPlayerOnce = row.per_player_once == 1 or row.per_player_once == true

            if not (row.enabled == 1 or row.enabled == true) then
                cb(false, 'disabled', value, voucherId, perPlayerOnce)
                return
            end

            if not (row.not_expired == 1 or row.not_expired == true) then
                cb(false, 'expired', value, voucherId, perPlayerOnce)
                return
            end

            local maxUses = row.max_uses and tonumber(row.max_uses) or nil
            local usesCount = tonumber(row.uses_count) or 0
            if maxUses and usesCount >= maxUses then
                cb(false, 'exhausted', value, voucherId, perPlayerOnce)
                return
            end

            if perPlayerOnce and tonumber(row.player_redeemed) and tonumber(row.player_redeemed) > 0 then
                cb(false, 'already_redeemed', value, voucherId, perPlayerOnce)
                return
            end

            cb(true, nil, value, voucherId, perPlayerOnce)
        end
    )
end

local function incrementUses(voucherId, cb)
    LiBridge.MySQL.Execute(
        [[UPDATE lifeinvader_vouchers
          SET uses_count = uses_count + 1, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
            AND enabled = 1
            AND (expires_at IS NULL OR expires_at > NOW())
            AND (max_uses IS NULL OR uses_count < max_uses)]],
        { voucherId },
        function(affected)
            cb((tonumber(affected) or 0) >= 1)
        end
    )
end

function LiBridgeServerVouchers.ConsumeForAd(identifier, code, amountDue, cb)
    amountDue = math.max(0, math.floor(tonumber(amountDue) or 0))
    code = LiBridgeServerVouchers.NormalizeCode(code)

    if code == '' then
        cb(true, nil, 0)
        return
    end

    if not LiBridgeServerVouchers.Enabled() then
        cb(false, 'feature_disabled', 0)
        return
    end

    LiBridgeServerVouchers.EvaluateCode(code, identifier, function(valid, errorKey, value, voucherId, perPlayerOnce)
        if not valid then
            cb(false, errorKey or 'invalid_voucher', 0)
            return
        end

        local discount = math.min(tonumber(value) or 0, amountDue)

        local function finalizeUses()
            incrementUses(voucherId, function(ok)
                if not ok then
                    cb(false, 'exhausted', 0)
                    return
                end
                cb(true, nil, discount)
            end)
        end

        if perPlayerOnce then
            LiBridge.MySQL.Insert(
                'INSERT INTO lifeinvader_voucher_redemptions (voucher_id, identifier) VALUES (?, ?)',
                { voucherId, identifier },
                function(redemptionId)
                    if not redemptionId then
                        cb(false, 'already_redeemed', 0)
                        return
                    end
                    finalizeUses()
                end
            )
            return
        end

        finalizeUses()
    end)
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
