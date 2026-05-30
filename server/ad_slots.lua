--[[ ec_lifeinvader — Aktive Anzeigen-Slots pro Spieler ]]

LiBridgeServerAdSlots = LiBridgeServerAdSlots or {}

local function adSlotsConfig()
    return Config.AdSlots or {}
end

local function clampMax(value)
    local cfg = adSlotsConfig()
    local minimum = math.max(1, math.floor(tonumber(cfg.minimum) or 1))
    local maximum = math.max(minimum, math.floor(tonumber(cfg.maximum) or 10))
    local clamped = math.floor(tonumber(value) or minimum)
    if clamped < minimum then
        return minimum
    end
    if clamped > maximum then
        return maximum
    end
    return clamped
end

function LiBridgeServerAdSlots.GetDefaultMax()
    local cfg = adSlotsConfig()
    return clampMax(tonumber(cfg.defaultMax) or 2)
end

function LiBridgeServerAdSlots.EnsureAccountRow(identifier, cb)
    if not identifier then
        cb(false, 0)
        return
    end

    LiBridge.MySQL.Query(
        'SELECT ad_slot_bonus FROM lifeinvader WHERE identifier = ? LIMIT 1',
        { identifier },
        function(result)
            if result and result[1] then
                cb(true, tonumber(result[1].ad_slot_bonus) or 0)
                return
            end

            LiBridge.MySQL.Insert(
                'INSERT INTO lifeinvader (identifier, balance, ad_slot_bonus) VALUES (?, 0, 0)',
                { identifier },
                function()
                    cb(true, 0)
                end
            )
        end
    )
end

function LiBridgeServerAdSlots.GetMaxActiveAds(identifier, cb)
    LiBridgeServerAdSlots.EnsureAccountRow(identifier, function(ok, bonus)
        if not ok then
            cb(LiBridgeServerAdSlots.GetDefaultMax())
            return
        end

        local maxAds = LiBridgeServerAdSlots.GetDefaultMax() + math.max(0, math.floor(bonus or 0))
        cb(clampMax(maxAds))
    end)
end

function LiBridgeServerAdSlots.GetActiveAdCount(identifier, cb)
    if not identifier then
        cb(0)
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT COUNT(*) AS count
          FROM lifeinvader_feeds
          WHERE identifier = ?
            AND status = 'active'
            AND expires_at > NOW()]],
        { identifier },
        function(result)
            local count = 0
            if result and result[1] then
                count = tonumber(result[1].count or result[1]['COUNT(*)']) or 0
            end
            cb(count)
        end
    )
end

function LiBridgeServerAdSlots.BuildSlotInfoFromAccount(accountRow, activeCount)
    local bonus = math.max(0, math.floor(tonumber(accountRow and accountRow.ad_slot_bonus) or 0))
    local maxAds = clampMax(LiBridgeServerAdSlots.GetDefaultMax() + bonus)
    local active = math.max(0, math.floor(tonumber(activeCount) or 0))

    return {
        active = active,
        max = maxAds,
        bonus = bonus,
        defaultMax = LiBridgeServerAdSlots.GetDefaultMax(),
        canPost = active < maxAds,
    }
end

function LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, cb, accountRow, activeCount)
    cb = cb or function() end

    if accountRow ~= nil and activeCount ~= nil then
        cb(LiBridgeServerAdSlots.BuildSlotInfoFromAccount(accountRow, activeCount))
        return
    end

    LiBridgeServerAdSlots.GetActiveAdCount(identifier, function(active)
        LiBridgeServerAdSlots.GetMaxActiveAds(identifier, function(maxAds)
            LiBridgeServerAdSlots.EnsureAccountRow(identifier, function(ok, bonus)
                cb({
                    active = active,
                    max = maxAds,
                    bonus = ok and bonus or 0,
                    defaultMax = LiBridgeServerAdSlots.GetDefaultMax(),
                    canPost = active < maxAds,
                })
            end)
        end)
    end)
end

function LiBridgeServerAdSlots.CanPostNewAd(identifier, cb)
    LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, function(info)
        cb(info.canPost == true, info.active, info.max)
    end)
end

local function parseOptionList(cfg, grantKey, removeKey, grantDefault, removeDefault)
    local grantOptions = {}
    for _, option in ipairs(cfg[grantKey] or grantDefault) do
        local value = math.floor(tonumber(option) or 0)
        if value > 0 then
            grantOptions[#grantOptions + 1] = value
        end
    end
    if #grantOptions == 0 then
        grantOptions = grantDefault
    end

    local removeOptions = {}
    for _, option in ipairs(cfg[removeKey] or removeDefault) do
        local value = math.floor(tonumber(option) or 0)
        if value > 0 then
            removeOptions[#removeOptions + 1] = value
        end
    end
    if #removeOptions == 0 then
        removeOptions = removeDefault
    end

    return grantOptions, removeOptions
end

function LiBridgeServerAdSlots.AddBonusSlots(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if not identifier or amount <= 0 then
        if cb then
            cb(false, 'invalid_amount')
        end
        return
    end

    LiBridgeServerAdSlots.EnsureAccountRow(identifier, function(ok, currentBonus)
        if not ok then
            if cb then
                cb(false, 'db_failed')
            end
            return
        end

        local cfg = adSlotsConfig()
        local maximum = math.max(1, math.floor(tonumber(cfg.maximum) or 10))
        local defaultMax = LiBridgeServerAdSlots.GetDefaultMax()
        local nextBonus = math.max(0, currentBonus + amount)
        local effectiveMax = clampMax(defaultMax + nextBonus)

        if effectiveMax >= maximum then
            nextBonus = math.max(0, maximum - defaultMax)
        end

        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader SET ad_slot_bonus = ?, updated_at = CURRENT_TIMESTAMP WHERE identifier = ?',
            { nextBonus, identifier },
            function(affected)
                local rows = tonumber(affected) or 0
                if rows < 1 then
                    if cb then
                        cb(false, 'db_failed')
                    end
                    return
                end

                LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, function(info)
                    if cb then
                        cb(true, nil, info)
                    end
                end)
            end
        )
    end)
end

function LiBridgeServerAdSlots.RemoveBonusSlots(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if not identifier or amount <= 0 then
        if cb then
            cb(false, 'invalid_amount')
        end
        return
    end

    LiBridgeServerAdSlots.EnsureAccountRow(identifier, function(ok, currentBonus)
        if not ok then
            if cb then
                cb(false, 'db_failed')
            end
            return
        end

        local nextBonus = math.max(0, math.floor(currentBonus or 0) - amount)

        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader SET ad_slot_bonus = ?, updated_at = CURRENT_TIMESTAMP WHERE identifier = ?',
            { nextBonus, identifier },
            function(affected)
                if (tonumber(affected) or 0) < 1 then
                    if cb then
                        cb(false, 'db_failed')
                    end
                    return
                end

                LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, function(info)
                    if cb then
                        cb(true, nil, info)
                    end
                end)
            end
        )
    end)
end

function LiBridgeServerAdSlots.BuildPolicyForUi()
    local cfg = adSlotsConfig()
    local grantOptions, removeOptions = parseOptionList(cfg, 'teamGrantOptions', 'teamRemoveOptions', { 1, 8 }, { 1, 8 })

    return {
        defaultMax = LiBridgeServerAdSlots.GetDefaultMax(),
        minimum = math.max(1, math.floor(tonumber(cfg.minimum) or 1)),
        maximum = math.max(1, math.floor(tonumber(cfg.maximum) or 8)),
        teamCanAdjust = cfg.teamCanAdjust ~= false,
        teamGrantOptions = grantOptions,
        teamRemoveOptions = removeOptions,
    }
end
