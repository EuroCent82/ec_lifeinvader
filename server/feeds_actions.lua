--[[ ec_lifeinvader — Anzeige schalten / löschen ]]

LiBridgeServerFeeds = LiBridgeServerFeeds or {}

local function trim(value)
    if value == nil then
        return ''
    end
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function findDuration(durationId)
    for _, entry in ipairs(Config.Durations or {}) do
        if entry.id == durationId then
            return entry
        end
    end
    return nil
end

local function adDaysMax(hours)
    return math.max(1, math.ceil((tonumber(hours) or 24) / 24))
end

local function anonymDaysMax(hours)
    local capHours = (Config.PremiumFeatures.anonym or {}).maxHours or 48
    local capDays = math.max(1, math.floor(capHours / 24))
    return math.min(adDaysMax(hours), capDays)
end

local function premiumCost(premium, hours)
    local total = 0
    local features = Config.PremiumFeatures or {}
    local maxDays = adDaysMax(hours)

    if type(premium) ~= 'table' then
        return 0
    end

    if premium.spotlight and type(premium.spotlight.days) == 'number' then
        local days = math.max(1, math.min(math.floor(premium.spotlight.days), maxDays))
        total = total + ((features.spotlight and features.spotlight.costPerDay or 0) * days)
    end

    if premium.anonym and type(premium.anonym.days) == 'number' then
        local days = math.max(1, math.min(math.floor(premium.anonym.days), anonymDaysMax(hours)))
        total = total + ((features.anonym and features.anonym.costPerDay or 0) * days)
    end

    if premium.liveticker and type(premium.liveticker.days) == 'number' then
        local days = math.max(1, math.min(math.floor(premium.liveticker.days), maxDays))
        total = total + ((features.liveticker and features.liveticker.costPerDay or 0) * days)
    end

    return total
end

function LiBridgeServerFeeds.CalculatePrice(data)
    local duration = findDuration(data and data.durationId)
    if not duration then
        return nil, 'invalid_duration'
    end

    local title = trim(data.title)
    local content = trim(data.content)
    local category = trim(data.category)

    if title == '' then
        return nil, 'invalid_title'
    end
    if #title > (Config.MaxTitleLength or 40) then
        return nil, 'title_too_long'
    end
    if content == '' then
        return nil, 'invalid_content'
    end
    if #content > (Config.MaxContentLength or 500) then
        return nil, 'content_too_long'
    end
    if category == '' then
        return nil, 'invalid_category'
    end

    local base = tonumber(duration.baseCost) or 0
    local text = #content * (Config.CharCost or 0)
    local premium = premiumCost(data.premium, duration.hours)

    return base + text + premium, nil
end

local function buildPremiumJson(premium, hours)
    if type(premium) ~= 'table' then
        return nil
    end

    local encoded = {}
    local maxDays = adDaysMax(hours)

    if premium.spotlight and type(premium.spotlight.days) == 'number' then
        encoded.spotlight = { days = math.max(1, math.min(math.floor(premium.spotlight.days), maxDays)) }
    end
    if premium.anonym and type(premium.anonym.days) == 'number' then
        encoded.anonym = { days = math.max(1, math.min(math.floor(premium.anonym.days), anonymDaysMax(hours))) }
    end
    if premium.liveticker and type(premium.liveticker.days) == 'number' then
        encoded.liveticker = { days = math.max(1, math.min(math.floor(premium.liveticker.days), maxDays)) }
    end

    if next(encoded) == nil then
        return nil
    end

    return json.encode(encoded)
end

local function sqlIntervalDays(days)
    days = math.max(1, math.floor(tonumber(days) or 1))
    return ('DATE_ADD(NOW(), INTERVAL %d DAY)'):format(days)
end

local function respondPost(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:postAdResult', src, requestId, payload)
end

local function respondDelete(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:deleteAdResult', src, requestId, payload)
end

RegisterNetEvent('ec_lifeinvader:server:postAd', function(requestId, data)
    local src = source
    data = data or {}

    if not LiBridge.Server.HasPermission(src, 'post') then
        respondPost(src, requestId, { ok = false, error = 'no_permission' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respondPost(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    local duration = findDuration(data.durationId)
    if not duration then
        respondPost(src, requestId, { ok = false, error = 'invalid_duration' })
        return
    end

    local phoneCfg = Config.Phone or {}
    if phoneCfg.requirePhoneItem == true and not LiBridgeServerInventory.PlayerHasPhone(src) then
        respondPost(src, requestId, { ok = false, error = 'no_phone_item' })
        return
    end

    local phone = trim(data.phone)
    if phone == '' or phone == 'Keine Nummer' then
        phone = LiBridgeServerInventory.GetPhoneNumber(src) or ''
    end
    if phone == '' then
        respondPost(src, requestId, { ok = false, error = 'phone_missing' })
        return
    end

    local price, priceErr = LiBridgeServerFeeds.CalculatePrice(data)
    if not price then
        respondPost(src, requestId, { ok = false, error = priceErr or 'invalid_price' })
        return
    end

    local clientPrice = math.floor(tonumber(data.price) or -1)
    if clientPrice >= 0 and math.abs(clientPrice - price) > 1 then
        respondPost(src, requestId, { ok = false, error = 'price_mismatch' })
        return
    end

    local authorName = LiBridge.Server.GetCharacterName(src) or GetPlayerName(src) or 'Unbekannt'
    local isAnonymous = data.anonymous == true or (type(data.premium) == 'table' and data.premium.anonym ~= nil)
    local premiumJson = buildPremiumJson(data.premium, duration.hours)

    local spotlightSql = 'NULL'
    local anonymSql = 'NULL'
    local tickerSql = 'NULL'

    if type(data.premium) == 'table' then
        if data.premium.spotlight and data.premium.spotlight.days then
            spotlightSql = sqlIntervalDays(data.premium.spotlight.days)
        end
        if data.premium.anonym and data.premium.anonym.days then
            anonymSql = sqlIntervalDays(data.premium.anonym.days)
        end
        if data.premium.liveticker and data.premium.liveticker.days then
            tickerSql = sqlIntervalDays(data.premium.liveticker.days)
        end
    end

    LiBridgeServerAccount.RemoveBalance(identifier, price, function(paid, balance, payErr)
        if not paid then
            respondPost(src, requestId, {
                ok = false,
                error = payErr == 'insufficient_balance' and 'insufficient_balance' or 'payment_failed',
                balance = balance,
            })
            return
        end

        local insertQuery = ([[
            INSERT INTO lifeinvader_feeds (
                identifier, author_name, title, content, category, phone,
                anonymous, premium, duration_hours, price_paid, status,
                spotlight_until, anonym_until, ticker_until, expires_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', %s, %s, %s, DATE_ADD(NOW(), INTERVAL %d HOUR))
        ]]):format(spotlightSql, anonymSql, tickerSql, duration.hours)

        LiBridge.MySQL.Insert(insertQuery, {
            identifier,
            authorName,
            trim(data.title),
            trim(data.content),
            trim(data.category),
            phone,
            isAnonymous and 1 or 0,
            premiumJson,
            duration.hours,
            price,
        }, function(insertId)
            if not insertId then
                LiBridgeServerAccount.AddBalance(identifier, price, function() end)
                respondPost(src, requestId, { ok = false, error = 'db_failed' })
                return
            end

            LiBridgeServerFeeds.BroadcastFeedNotification({
                author = isAnonymous and 'Anonym' or authorName,
                title = trim(data.title),
            }, src)

            LiBridgeServerFeeds.GetActiveAds(identifier, function(ads)
                respondPost(src, requestId, {
                    ok = true,
                    balance = balance,
                    ads = ads,
                })
            end)
        end)
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:deleteAd', function(requestId, adId)
    local src = source
    adId = tonumber(adId)

    if not adId then
        respondDelete(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    local identifier = LiBridge.Server.GetIdentifier(src)
    if not identifier then
        respondDelete(src, requestId, { ok = false, error = 'no_identifier' })
        return
    end

    LiBridge.MySQL.Query(
        'SELECT id, identifier FROM lifeinvader_feeds WHERE id = ? AND status <> ? LIMIT 1',
        { adId, 'deleted' },
        function(rows)
            local row = rows and rows[1]
            if not row then
                respondDelete(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            local isOwner = row.identifier == identifier
            local isAdmin = LiBridge.Server.HasPermission(src, 'admin')

            if not isOwner and not isAdmin then
                respondDelete(src, requestId, { ok = false, error = 'no_permission' })
                return
            end

            LiBridge.MySQL.Execute(
                "UPDATE lifeinvader_feeds SET status = 'deleted' WHERE id = ?",
                { adId },
                function()
                    LiBridgeServerFeeds.GetActiveAds(identifier, function(ads)
                        respondDelete(src, requestId, {
                            ok = true,
                            ads = ads,
                        })
                    end)
                end
            )
        end
    )
end)
