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

function LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, cb)
    cb = cb or function() end

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

function LiBridgeServerAdSlots.BuildPolicyForUi()
    local cfg = adSlotsConfig()
    local options = cfg.teamGrantOptions or { 1, 8 }
    local grantOptions = {}

    for i = 1, #options do
        local value = math.floor(tonumber(options[i]) or 0)
        if value > 0 then
            grantOptions[#grantOptions + 1] = value
        end
    end

    if #grantOptions == 0 then
        grantOptions = { 1, 8 }
    end

    return {
        defaultMax = LiBridgeServerAdSlots.GetDefaultMax(),
        minimum = math.max(1, math.floor(tonumber(cfg.minimum) or 1)),
        maximum = math.max(1, math.floor(tonumber(cfg.maximum) or 10)),
        teamCanAdjust = cfg.teamCanAdjust ~= false,
        teamGrantOptions = grantOptions,
    }
end
