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

local function mapVoucherRow(row)
    return {
        id = tonumber(row.id),
        code = row.code,
        value = tonumber(row.value) or 0,
        expiresAt = row.expires_at,
        maxUses = row.max_uses and tonumber(row.max_uses) or nil,
        usesCount = tonumber(row.uses_count) or 0,
        enabled = row.enabled == 1 or row.enabled == true,
        createdBy = row.created_by,
        createdAt = row.created_at,
    }
end

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
        [[SELECT id, code, value, expires_at, max_uses, uses_count, enabled, created_by, created_at
          FROM lifeinvader_vouchers
          ORDER BY id DESC
          LIMIT 50]],
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

    local createdBy = LiBridge.Server.GetIdentifier(src) or 'team'
    local code = generateVoucherCode()

    LiBridge.MySQL.Insert(
        [[INSERT INTO lifeinvader_vouchers (code, value, expires_at, max_uses, enabled, created_by)
          VALUES (?, ?, ?, ?, 1, ?)]],
        { code, value, expiresAt, maxUses, createdBy },
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
                    createdBy = createdBy,
                },
            })
        end
    )
end)
