--[[ ec_lifeinvader — Team: Gutscheine ]]

local function voucherConfig()
    return Config.Vouchers or {}
end

local function randomDigits(length)
    local out = {}
    for _ = 1, length do
        out[#out + 1] = tostring(math.random(0, 9))
    end
    return table.concat(out)
end

local function generateVoucherCode()
    local cfg = voucherConfig()
    local prefix = cfg.prefix or 'LIV'
    local digits = math.max(3, math.floor(tonumber(cfg.segmentDigits) or 4))
    local count = math.max(1, math.floor(tonumber(cfg.segmentCount) or 2))

    local parts = { prefix }
    for _ = 1, count do
        parts[#parts + 1] = randomDigits(digits)
    end

    return table.concat(parts, '-')
end

local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end
    return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function mapVoucherRow(row)
    return {
        id = tonumber(row.id),
        code = row.code,
        value = tonumber(row.value) or 0,
        expiresAt = row.expires_at,
        maxUses = row.max_uses and tonumber(row.max_uses) or nil,
        usesCount = tonumber(row.uses_count) or 0,
        enabled = row.enabled == 1 or row.enabled == true,
        boundIdentifier = row.bound_identifier,
        internalNote = row.internal_note,
        createdBy = row.created_by,
        createdAt = row.created_at,
    }
end

local VOUCHER_SELECT = [[SELECT id, code, value, expires_at, max_uses, uses_count, enabled,
    bound_identifier, internal_note, created_by, created_at
    FROM lifeinvader_vouchers]]

RegisterNetEvent('ec_lifeinvader:server:teamListVouchers', function(requestId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'vouchers') then
        return
    end

    if voucherConfig().enabled == false then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    LiBridge.MySQL.Query(
        VOUCHER_SELECT .. [[ ORDER BY id DESC LIMIT 50]],
        {},
        function(rows)
            local vouchers = {}
            for _, row in ipairs(rows or {}) do
                vouchers[#vouchers + 1] = mapVoucherRow(row)
            end

            LiBridgeServerTeam.Respond(src, requestId, { ok = true, vouchers = vouchers })
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamCreateVoucher', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'vouchers') then
        return
    end

    if voucherConfig().enabled == false then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    data = data or {}
    local value = math.floor(tonumber(data.value) or tonumber((voucherConfig().defaults or {}).value) or 0)
    if value <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_value' })
        return
    end

    local maxUses = data.maxUses
    if maxUses ~= nil then
        maxUses = math.floor(tonumber(maxUses) or 0)
        if maxUses <= 0 then
            maxUses = nil
        end
    end

    local expiresAt = data.expiresAt
    if expiresAt == '' or expiresAt == false then
        expiresAt = nil
    end

    local playerBound = data.playerBound == true
    local boundIdentifier = playerBound and trim(data.boundIdentifier) or nil
    if playerBound and boundIdentifier == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_identifier' })
        return
    end

    if not playerBound then
        boundIdentifier = nil
    end

    local internalNote = trim(data.internalNote)
    if internalNote == '' then
        internalNote = nil
    end

    local createdBy = LiBridge.Server.GetIdentifier(src) or 'team'
    local code = generateVoucherCode()

    LiBridge.MySQL.Insert(
        [[INSERT INTO lifeinvader_vouchers
          (code, value, expires_at, max_uses, enabled, bound_identifier, internal_note, created_by)
          VALUES (?, ?, ?, ?, 1, ?, ?, ?)]],
        { code, value, expiresAt, maxUses, boundIdentifier, internalNote, createdBy },
        function(insertId)
            if not insertId then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                return
            end

            LiBridgeServerTeam.Respond(src, requestId, {
                ok = true,
                voucher = {
                    id = insertId,
                    code = code,
                    value = value,
                    expiresAt = expiresAt,
                    maxUses = maxUses,
                    usesCount = 0,
                    enabled = true,
                    boundIdentifier = boundIdentifier,
                    internalNote = internalNote,
                    createdBy = createdBy,
                },
            })
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamSetVoucherEnabled', function(requestId, voucherId, enabled)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'vouchers') then
        return
    end

    voucherId = math.floor(tonumber(voucherId) or 0)
    if voucherId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    local nextEnabled = enabled == true and 1 or 0

    LiBridge.MySQL.Execute(
        'UPDATE lifeinvader_vouchers SET enabled = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        { nextEnabled, voucherId },
        function(affected)
            if (tonumber(affected) or 0) < 1 then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            LiBridgeServerTeam.Respond(src, requestId, {
                ok = true,
                id = voucherId,
                enabled = nextEnabled == 1,
            })
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamDeleteVoucher', function(requestId, voucherId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'vouchers') then
        return
    end

    voucherId = math.floor(tonumber(voucherId) or 0)
    if voucherId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    LiBridge.MySQL.Execute(
        'DELETE FROM lifeinvader_vouchers WHERE id = ?',
        { voucherId },
        function(affected)
            if (tonumber(affected) or 0) < 1 then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            LiBridgeServerTeam.Respond(src, requestId, { ok = true, deletedId = voucherId })
        end
    )
end)
