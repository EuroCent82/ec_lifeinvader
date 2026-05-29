--[[ ec_lifeinvader — Max. Anzeigen-Laufzeit (Tage) pro Spieler ]]

LiBridgeServerAdDuration = LiBridgeServerAdDuration or {}

local function durationConfig()
    return Config.AdDuration or {}
end

local function clampDays(value)
    local cfg = durationConfig()
    local minimum = math.max(1, math.floor(tonumber(cfg.minimum) or 1))
    local maximum = math.max(minimum, math.floor(tonumber(cfg.maximum) or 30))
    local clamped = math.floor(tonumber(value) or minimum)
    if clamped < minimum then
        return minimum
    end
    if clamped > maximum then
        return maximum
    end
    return clamped
end

function LiBridgeServerAdDuration.GetDefaultMaxDays()
    return clampDays(tonumber(durationConfig().defaultMaxDays) or 7)
end

function LiBridgeServerAdDuration.EnsureAccountRow(identifier, cb)
    if not identifier then
        cb(false, 0)
        return
    end

    LiBridge.MySQL.Query(
        'SELECT ad_duration_bonus_days FROM lifeinvader WHERE identifier = ? LIMIT 1',
        { identifier },
        function(result)
            if result and result[1] then
                cb(true, tonumber(result[1].ad_duration_bonus_days) or 0)
                return
            end

            LiBridge.MySQL.Insert(
                'INSERT INTO lifeinvader (identifier, balance, ad_slot_bonus, ad_duration_bonus_days) VALUES (?, 0, 0, 0)',
                { identifier },
                function()
                    cb(true, 0)
                end
            )
        end
    )
end

function LiBridgeServerAdDuration.GetMaxDays(identifier, cb)
    LiBridgeServerAdDuration.EnsureAccountRow(identifier, function(ok, bonus)
        if not ok then
            cb(LiBridgeServerAdDuration.GetDefaultMaxDays())
            return
        end

        local maxDays = LiBridgeServerAdDuration.GetDefaultMaxDays() + math.max(0, math.floor(bonus or 0))
        cb(clampDays(maxDays))
    end)
end

function LiBridgeServerAdDuration.GetPlayerInfo(identifier, cb)
    LiBridgeServerAdDuration.GetMaxDays(identifier, function(maxDays)
        LiBridgeServerAdDuration.EnsureAccountRow(identifier, function(ok, bonus)
            cb({
                maxDays = maxDays,
                bonusDays = ok and bonus or 0,
                defaultMaxDays = LiBridgeServerAdDuration.GetDefaultMaxDays(),
                maxHours = maxDays * 24,
            })
        end)
    end)
end

local function parseDurationOptions(cfg, key, fallback)
    local options = {}
    for _, option in ipairs(cfg[key] or fallback) do
        local value = math.floor(tonumber(option) or 0)
        if value > 0 then
            options[#options + 1] = value
        end
    end
    if #options == 0 then
        return fallback
    end
    return options
end

function LiBridgeServerAdDuration.BuildPolicyForUi()
    local cfg = durationConfig()

    return {
        defaultMaxDays = LiBridgeServerAdDuration.GetDefaultMaxDays(),
        minimum = math.max(1, math.floor(tonumber(cfg.minimum) or 1)),
        maximum = math.max(1, math.floor(tonumber(cfg.maximum) or 30)),
        teamCanAdjust = cfg.teamCanAdjust ~= false,
        teamGrantOptions = parseDurationOptions(cfg, 'teamGrantOptions', { 1, 7 }),
        teamRemoveOptions = parseDurationOptions(cfg, 'teamRemoveOptions', { 1, 7 }),
    }
end

function LiBridgeServerAdDuration.AddBonusDays(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if not identifier or amount <= 0 then
        if cb then
            cb(false, 'invalid_amount')
        end
        return
    end

    LiBridgeServerAdDuration.EnsureAccountRow(identifier, function(ok, currentBonus)
        if not ok then
            if cb then
                cb(false, 'db_failed')
            end
            return
        end

        local maximum = math.max(1, math.floor(tonumber(durationConfig().maximum) or 30))
        local defaultMax = LiBridgeServerAdDuration.GetDefaultMaxDays()
        local nextBonus = math.max(0, currentBonus + amount)
        local effectiveMax = clampDays(defaultMax + nextBonus)

        if effectiveMax >= maximum then
            nextBonus = math.max(0, maximum - defaultMax)
        end

        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader SET ad_duration_bonus_days = ?, updated_at = CURRENT_TIMESTAMP WHERE identifier = ?',
            { nextBonus, identifier },
            function(affected)
                if (tonumber(affected) or 0) < 1 then
                    if cb then
                        cb(false, 'db_failed')
                    end
                    return
                end

                LiBridgeServerAdDuration.GetPlayerInfo(identifier, function(info)
                    if cb then
                        cb(true, nil, info)
                    end
                end)
            end
        )
    end)
end

function LiBridgeServerAdDuration.RemoveBonusDays(identifier, amount, cb)
    amount = math.floor(tonumber(amount) or 0)
    if not identifier or amount <= 0 then
        if cb then
            cb(false, 'invalid_amount')
        end
        return
    end

    LiBridgeServerAdDuration.EnsureAccountRow(identifier, function(ok, currentBonus)
        if not ok then
            if cb then
                cb(false, 'db_failed')
            end
            return
        end

        local nextBonus = math.max(0, math.floor(currentBonus or 0) - amount)

        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader SET ad_duration_bonus_days = ?, updated_at = CURRENT_TIMESTAMP WHERE identifier = ?',
            { nextBonus, identifier },
            function(affected)
                if (tonumber(affected) or 0) < 1 then
                    if cb then
                        cb(false, 'db_failed')
                    end
                    return
                end

                LiBridgeServerAdDuration.GetPlayerInfo(identifier, function(info)
                    if cb then
                        cb(true, nil, info)
                    end
                end)
            end
        )
    end)
end

function LiBridgeServerAdDuration.ValidateDurationHours(identifier, hours, cb)
    hours = math.floor(tonumber(hours) or 0)
    LiBridgeServerAdDuration.GetMaxDays(identifier, function(maxDays)
        local maxHours = maxDays * 24
        cb(hours > 0 and hours <= maxHours, maxHours)
    end)
end
