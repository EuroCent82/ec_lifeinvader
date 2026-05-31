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

local function premiumCost(premium, hours, anonymous)
    local total = 0
    local features = Config.PremiumFeatures or {}
    local maxDays = adDaysMax(hours)

    if anonymous == true then
        total = total + ((features.anonym and features.anonym.costPerDay or 0) * maxDays)
    elseif type(premium) == 'table' and premium.anonym and type(premium.anonym.days) == 'number' then
        local days = math.max(1, math.min(math.floor(premium.anonym.days), anonymDaysMax(hours)))
        total = total + ((features.anonym and features.anonym.costPerDay or 0) * days)
    end

    if type(premium) ~= 'table' then
        return total
    end

    if premium.spotlight and type(premium.spotlight.days) == 'number' then
        local days = math.max(1, math.min(math.floor(premium.spotlight.days), maxDays))
        total = total + ((features.spotlight and features.spotlight.costPerDay or 0) * days)
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
    local premium = premiumCost(data.premium, duration.hours, data.anonymous == true)

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

local function respondPostWithSlots(identifier, src, requestId, payload)
    LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, function(slotInfo)
        payload.adSlots = slotInfo
        respondPost(src, requestId, payload)
    end)
end

local function requireAdSlot(identifier, src, requestId, onAllowed)
    LiBridgeServerAdSlots.CanPostNewAd(identifier, function(canPost, active, max)
        if not canPost then
            respondPost(src, requestId, {
                ok = false,
                error = 'ad_slot_limit',
                active = active,
                max = max,
            })
            return
        end

        onAllowed()
    end)
end

local function sqlAnonymUntil(hours)
    hours = math.max(1, math.floor(tonumber(hours) or 24))
    return ('DATE_ADD(NOW(), INTERVAL %d HOUR)'):format(hours)
end

local function resolveAnonymSql(hours, isAnonymous, premium)
    if isAnonymous then
        return sqlAnonymUntil(hours)
    end
    if type(premium) == 'table' and premium.anonym and premium.anonym.days then
        return sqlIntervalDays(premium.anonym.days)
    end
    return 'NULL'
end

local function respondDelete(src, requestId, payload)
    TriggerClientEvent('ec_lifeinvader:client:deleteAdResult', src, requestId, payload)
end

local postAdContinue

postAdContinue = function(src, requestId, data, identifier)
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
    if phone == 'Keine Nummer' or phone == '—' then
        phone = ''
    end
    if phone ~= '' and phone:match('[^0-9]') then
        respondPost(src, requestId, { ok = false, error = 'phone_invalid' })
        return
    end
    if phone == '' then
        phone = LiBridgeServerInventory.GetPhoneNumber(src) or ''
        if phone ~= '' and phone:match('[^0-9]') then
            phone = phone:gsub('[^0-9]', '')
        end
    end

    local grossPrice, priceErr = LiBridgeServerFeeds.CalculatePrice(data)
    if not grossPrice then
        respondPost(src, requestId, { ok = false, error = priceErr or 'invalid_price' })
        return
    end

    local authorName = LiBridge.Server.GetCharacterName(src) or GetPlayerName(src) or 'Unbekannt'
    local isAnonymous = data.anonymous == true
    local premiumJson = buildPremiumJson(data.premium, duration.hours)

    local spotlightSql = 'NULL'
    local anonymSql = resolveAnonymSql(duration.hours, isAnonymous, data.premium)
    local tickerSql = 'NULL'

    if type(data.premium) == 'table' then
        if data.premium.spotlight and data.premium.spotlight.days then
            spotlightSql = sqlIntervalDays(data.premium.spotlight.days)
        end
        if data.premium.liveticker and data.premium.liveticker.days then
            tickerSql = sqlIntervalDays(data.premium.liveticker.days)
        end
    end

    local renewFromId = tonumber(data.renewFromId)
    local extendFromId = tonumber(data.extendFromId)
    local wantsTicker = tickerSql ~= 'NULL'

    if renewFromId and extendFromId then
        respondPost(src, requestId, { ok = false, error = 'invalid_request' })
        return
    end

    local function ensureTickerCapacity(excludeFeedId, cb)
        if not wantsTicker then
            cb()
            return
        end

        LiBridgeServerFeeds.CountActiveTickerAds(function(count)
            if count >= LiBridgeServerFeeds.GetTickerMaxSlots() then
                respondPost(src, requestId, {
                    ok = false,
                    error = 'ticker_slots_full',
                    maxSlots = LiBridgeServerFeeds.GetTickerMaxSlots(),
                })
                return
            end
            cb()
        end, excludeFeedId)
    end

    local function applyVoucherThenCharge(chargePrice, continueFn)
        chargePrice = math.max(0, math.floor(tonumber(chargePrice) or 0))

        local voucherCode = LiBridgeServerVouchers.NormalizeCode(data.voucherCode or '')
        if voucherCode == '' or not LiBridgeServerVouchers or not LiBridgeServerVouchers.Enabled() then
            continueFn(chargePrice)
            return
        end

        LiBridgeServerVouchers.ConsumeForAd(identifier, voucherCode, chargePrice, function(ok, err, discount)
            if not ok then
                respondPost(src, requestId, { ok = false, error = err or 'invalid_voucher' })
                return
            end

            continueFn(math.max(0, chargePrice - (discount or 0)))
        end)
    end

    local function finishPost(chargePrice)
        chargePrice = math.max(0, math.floor(tonumber(chargePrice) or 0))

        local clientPrice = math.floor(tonumber(data.price) or -1)
        if clientPrice >= 0 and math.abs(clientPrice - chargePrice) > 1 then
            respondPost(src, requestId, { ok = false, error = 'price_mismatch' })
            return
        end

    LiBridgeServerAccount.RemoveBalance(identifier, chargePrice, function(paid, balance, payErr)
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
            chargePrice,
        }, function(insertId)
            if not insertId then
                LiBridgeServerAccount.AddBalance(identifier, chargePrice, function() end)
                respondPost(src, requestId, { ok = false, error = 'db_failed' })
                return
            end

            LiBridgeServerFeeds.BroadcastFeedNotification({
                author = isAnonymous and 'Anonym' or authorName,
                title = trim(data.title),
            }, src)

            LiBridgeServerFeeds.RefetchPlayerFeed(identifier, function(ads, history)
                respondPostWithSlots(identifier, src, requestId, {
                    ok = true,
                    balance = balance,
                    ads = ads,
                    history = history,
                })
            end)
        end)
    end)
    end

    if extendFromId then
        LiBridge.MySQL.Query(
            [[SELECT id, identifier, author_name, title, content, category, phone, anonymous,
                     premium, spotlight_until, anonym_until, ticker_until,
                     duration_hours, price_paid, status, created_at, expires_at
              FROM lifeinvader_feeds
              WHERE id = ?
              LIMIT 1]],
            { extendFromId },
            function(rows)
                local row = rows and rows[1]
                if not LiBridgeServerFeeds.CanExtendRow(row, identifier) then
                    respondPost(src, requestId, { ok = false, error = 'extend_invalid' })
                    return
                end

                LiBridgeServerAdDuration.ValidateDurationHours(identifier, duration.hours, function(durationOk, maxHours)
                    if not durationOk then
                        respondPost(src, requestId, { ok = false, error = 'duration_limit', maxHours = maxHours })
                        return
                    end

                local credit = LiBridgeServerFeeds.CalculateRemainingCredit(row)
                local chargePrice = math.max(0, grossPrice - credit)

                ensureTickerCapacity(extendFromId, function()
                    local tickerEnabledClause = wantsTicker and ', ticker_enabled = 1' or ''
                    applyVoucherThenCharge(chargePrice, function(finalPrice)
                        local clientPrice = math.floor(tonumber(data.price) or -1)
                        if clientPrice >= 0 and math.abs(clientPrice - finalPrice) > 1 then
                            respondPost(src, requestId, { ok = false, error = 'price_mismatch' })
                            return
                        end

                        LiBridgeServerAccount.RemoveBalance(identifier, finalPrice, function(paid, balance, payErr)
                            if not paid then
                                respondPost(src, requestId, {
                                    ok = false,
                                    error = payErr == 'insufficient_balance' and 'insufficient_balance' or 'payment_failed',
                                    balance = balance,
                                })
                                return
                            end

                            local updateQuery = ([[
                                UPDATE lifeinvader_feeds SET
                                    author_name = ?,
                                    title = ?,
                                    content = ?,
                                    category = ?,
                                    phone = ?,
                                    anonymous = ?,
                                    premium = ?,
                                    duration_hours = duration_hours + ?,
                                    price_paid = price_paid + ?,
                                    expires_at = DATE_ADD(expires_at, INTERVAL %d HOUR),
                                    spotlight_until = %s,
                                    anonym_until = %s,
                                    ticker_until = %s%s
                                WHERE id = ? AND identifier = ? AND status = 'active'
                            ]]):format(duration.hours, spotlightSql, anonymSql, tickerSql, tickerEnabledClause)

                            LiBridge.MySQL.Execute(updateQuery, {
                                authorName,
                                trim(data.title),
                                trim(data.content),
                                trim(data.category),
                                phone,
                                isAnonymous and 1 or 0,
                                premiumJson,
                                duration.hours,
                                finalPrice,
                                extendFromId,
                                identifier,
                            }, function(affected)
                                local rowsAffected = tonumber(affected) or 0
                                if rowsAffected < 1 then
                                    LiBridgeServerAccount.AddBalance(identifier, finalPrice, function() end)
                                    respondPost(src, requestId, { ok = false, error = 'db_failed' })
                                    return
                                end

                                LiBridgeServerFeeds.RefetchPlayerFeed(identifier, function(ads, history)
                                    respondPostWithSlots(identifier, src, requestId, {
                                        ok = true,
                                        balance = balance,
                                        ads = ads,
                                        history = history,
                                        extensionCredit = credit,
                                        charged = finalPrice,
                                    })
                                end)
                            end)
                        end)
                    end)
                end)
                end)
            end
        )
        return
    end

    if renewFromId then
        LiBridge.MySQL.Query(
            [[SELECT id, identifier, status, expires_at
              FROM lifeinvader_feeds
              WHERE id = ?
              LIMIT 1]],
            { renewFromId },
            function(rows)
                if not LiBridgeServerFeeds.CanRenewRow(rows and rows[1], identifier) then
                    respondPost(src, requestId, { ok = false, error = 'renew_invalid' })
                    return
                end
                LiBridgeServerAdDuration.ValidateDurationHours(identifier, duration.hours, function(durationOk, maxHours)
                    if not durationOk then
                        respondPost(src, requestId, { ok = false, error = 'duration_limit', maxHours = maxHours })
                        return
                    end

                    requireAdSlot(identifier, src, requestId, function()
                        ensureTickerCapacity(nil, function()
                            applyVoucherThenCharge(grossPrice, finishPost)
                        end)
                    end)
                end)
            end
        )
        return
    end

    LiBridgeServerAdDuration.ValidateDurationHours(identifier, duration.hours, function(durationOk, maxHours)
        if not durationOk then
            respondPost(src, requestId, { ok = false, error = 'duration_limit', maxHours = maxHours })
            return
        end

        requireAdSlot(identifier, src, requestId, function()
            ensureTickerCapacity(nil, function()
                applyVoucherThenCharge(grossPrice, finishPost)
            end)
        end)
    end)
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

    LiBridgeServerBlacklist.IsBanned(identifier, function(banned)
        if banned then
            respondPost(src, requestId, { ok = false, error = 'blacklisted' })
            return
        end

        postAdContinue(src, requestId, data, identifier)
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
                    LiBridgeServerAdSlots.GetPlayerAdSlotInfo(identifier, function(slotInfo)
                        LiBridgeServerFeeds.RefetchPlayerFeed(identifier, function(ads, history)
                            respondDelete(src, requestId, {
                                ok = true,
                                ads = ads,
                                history = history,
                                adSlots = slotInfo,
                            })
                        end)
                    end)
                end
            )
        end
    )
end)
