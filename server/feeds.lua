LiBridge = LiBridge or {}
LiBridgeServerFeeds = LiBridgeServerFeeds or {}

function LiBridgeServerFeeds.FormatLivId(id)
    return ('LIV-%s'):format(tostring(id or 0))
end

local function formatDateTimeLabel(value)
    if not value then
        return '—'
    end

    if type(value) == 'number' then
        return os.date('%d.%m.%Y %H:%M', value)
    end

    local text = tostring(value)
    local y, m, d, h, min = text:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+)')
    if y then
        return ('%s.%s.%s %s:%s'):format(d, m, y, h, min)
    end

    return text
end

local function resolveFeedStatus(row)
    if row.status == 'deleted' then
        return 'deleted'
    end
    if row.status == 'blocked' then
        return 'blocked'
    end

    local expires = row.expires_at
    if type(expires) == 'string' then
        local y, m, d, h, min, sec = expires:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)')
        if y then
            local expiresAt = os.time({
                year = tonumber(y),
                month = tonumber(m),
                day = tonumber(d),
                hour = tonumber(h),
                min = tonumber(min),
                sec = tonumber(sec),
            })
            if expiresAt and expiresAt < os.time() then
                return 'expired'
            end
        end
    end

    if row.status == 'active' then
        return 'active'
    end

    return 'expired'
end

local function durationLabelFromHours(hours)
    hours = tonumber(hours) or 24
    for _, entry in ipairs(Config.Durations or {}) do
        if tonumber(entry.hours) == hours then
            return entry.label
        end
    end
    if hours < 24 then
        return ('%d Stunden'):format(hours)
    end
    if hours % 24 == 0 then
        return ('%d Tage'):format(hours / 24)
    end
    return ('%d Stunden'):format(hours)
end

local function anonymDaysMaxForHours(hours)
    local capHours = (Config.PremiumFeatures.anonym or {}).maxHours or 48
    local capDays = math.max(1, math.floor(capHours / 24))
    return math.min(math.max(1, math.ceil((tonumber(hours) or 24) / 24)), capDays)
end

local function decodePremium(raw)
    if type(raw) == 'table' then
        return raw
    end
    if type(raw) == 'string' and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            return decoded
        end
    end
    return nil
end

function LiBridgeServerFeeds.BuildInvoiceBreakdown(row)
    local hours = tonumber(row.duration_hours) or 24
    local durationLabel = durationLabelFromHours(hours)
    local baseCost = 0

    for _, entry in ipairs(Config.Durations or {}) do
        if tonumber(entry.hours) == hours then
            baseCost = tonumber(entry.baseCost) or 0
            break
        end
    end

    local content = row.content or ''
    local textCost = #content * (Config.CharCost or 0)
    local items = {}

    items[#items + 1] = {
        label = ('Grundpreis · %s'):format(durationLabel),
        amount = baseCost,
    }

    if textCost > 0 then
        items[#items + 1] = {
            label = ('Anzeigentext · %d Zeichen'):format(#content),
            amount = textCost,
        }
    end

    local premium = decodePremium(row.premium)
    local features = Config.PremiumFeatures or {}
    local maxDays = math.max(1, math.ceil(hours / 24))

    if premium and premium.spotlight and premium.spotlight.days then
        local days = math.max(1, math.min(math.floor(premium.spotlight.days), maxDays))
        local perDay = (features.spotlight and features.spotlight.costPerDay) or 0
        items[#items + 1] = {
            label = 'Premium Spotlight',
            detail = ('%d Tag(e) × $%s'):format(days, perDay),
            amount = perDay * days,
        }
    end

    if premium and premium.anonym and premium.anonym.days then
        local days = math.max(1, math.min(math.floor(premium.anonym.days), anonymDaysMaxForHours(hours)))
        local perDay = (features.anonym and features.anonym.costPerDay) or 0
        items[#items + 1] = {
            label = 'Anonym posten',
            detail = ('%d Tag(e) × $%s'):format(days, perDay),
            amount = perDay * days,
        }
    end

    if premium and premium.liveticker and premium.liveticker.days then
        local days = math.max(1, math.min(math.floor(premium.liveticker.days), maxDays))
        local perDay = (features.liveticker and features.liveticker.costPerDay) or 0
        items[#items + 1] = {
            label = 'Live-Ticker',
            detail = ('%d Tag(e) × $%s'):format(days, perDay),
            amount = perDay * days,
        }
    end

    return {
        items = items,
        total = tonumber(row.price_paid) or 0,
    }
end

local function premiumLinesFromJson(premium)
    local decoded = premium
    if type(premium) == 'string' and premium ~= '' then
        local ok, parsed = pcall(json.decode, premium)
        if ok and type(parsed) == 'table' then
            decoded = parsed
        end
    end

    if type(decoded) ~= 'table' then
        return {}
    end

    local lines = {}
    local features = Config.PremiumFeatures or {}

    if decoded.spotlight and decoded.spotlight.days then
        lines[#lines + 1] = ('Premium Spotlight: %d Tag(e)'):format(decoded.spotlight.days)
    end
    if decoded.anonym and decoded.anonym.days then
        lines[#lines + 1] = ('Anonym posten: %d Tag(e)'):format(decoded.anonym.days)
    end
    if decoded.liveticker and decoded.liveticker.days then
        lines[#lines + 1] = ('Live-Ticker: %d Tag(e)'):format(decoded.liveticker.days)
    end

    if #lines == 0 and next(decoded) ~= nil then
        lines[#lines + 1] = 'Premium-Paket gebucht'
    end

    return lines
end

local function relativeTimestamp(createdAt)
    if not createdAt then
        return 'Kürzlich'
    end

    if type(createdAt) == 'number' then
        local diff = os.time() - createdAt
        if diff < 60 then
            return 'Gerade eben'
        end
        if diff < 3600 then
            return ('Vor %d Min.'):format(math.floor(diff / 60))
        end
        if diff < 86400 then
            return ('Vor %d Std.'):format(math.floor(diff / 3600))
        end
        return ('Vor %d Tag(en)'):format(math.floor(diff / 86400))
    end

    return tostring(createdAt)
end

function LiBridgeServerFeeds.FormatAdRow(row, viewerIdentifier)
    local premium = decodePremium(row.premium)
    local spotlightActive = row.spotlight_until and true or false
    if row.spotlight_until then
        -- oxmysql may return string timestamp
        spotlightActive = true
    end

    local author = row.author_name or 'Unbekannt'
    if row.anonymous == 1 or row.anonymous == true then
        author = 'Anonym'
    end

    return {
        id = row.id,
        livId = LiBridgeServerFeeds.FormatLivId(row.id),
        title = row.title,
        content = row.content,
        category = row.category,
        author = author,
        phone = row.phone or '',
        timestamp = relativeTimestamp(row.created_at),
        premium = spotlightActive or (premium and premium.spotlight ~= nil),
        isMine = viewerIdentifier ~= nil and row.identifier == viewerIdentifier,
        ownerIdentifier = row.identifier,
    }
end

function LiBridgeServerFeeds.FormatHistoryRow(row)
    local status = resolveFeedStatus(row)
    local author = row.author_name or 'Unbekannt'
    if row.anonymous == 1 or row.anonymous == true then
        author = 'Anonym'
    end

    local premium = decodePremium(row.premium)
    local spotlightActive = row.spotlight_until and true or false

    return {
        id = row.id,
        livId = LiBridgeServerFeeds.FormatLivId(row.id),
        title = row.title,
        content = row.content,
        category = row.category,
        author = author,
        phone = row.phone or '',
        timestamp = relativeTimestamp(row.created_at),
        premium = spotlightActive or (premium and premium.spotlight ~= nil),
        status = status,
        createdAtLabel = formatDateTimeLabel(row.created_at),
        expiresAtLabel = formatDateTimeLabel(row.expires_at),
        durationLabel = durationLabelFromHours(row.duration_hours),
        durationHours = row.duration_hours,
        pricePaid = row.price_paid or 0,
        premiumLines = premiumLinesFromJson(row.premium),
        invoice = LiBridgeServerFeeds.BuildInvoiceBreakdown(row),
        premiumDraft = premium,
        ownerIdentifier = row.identifier,
    }
end

function LiBridgeServerFeeds.CanRenewRow(row, identifier)
    if not row or not identifier or row.identifier ~= identifier then
        return false
    end

    local status = resolveFeedStatus(row)
    return status == 'expired' or status == 'deleted'
end

function LiBridgeServerFeeds.GetPlayerFeedHistory(identifier, cb)
    if not identifier then
        cb({})
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, identifier, author_name, title, content, category, phone, anonymous,
                 premium, spotlight_until, duration_hours, price_paid, status,
                 created_at, expires_at
          FROM lifeinvader_feeds
          WHERE identifier = ?
          ORDER BY created_at DESC
          LIMIT 80]],
        { identifier },
        function(result)
            local history = {}
            for _, row in ipairs(result or {}) do
                history[#history + 1] = LiBridgeServerFeeds.FormatHistoryRow(row)
            end
            cb(history)
        end
    )
end

function LiBridgeServerFeeds.GetCategories(cb)
    LiBridge.MySQL.Query(
        [[SELECT slug, label, icon
          FROM lifeinvader_categories
          WHERE enabled = 1
          ORDER BY sort_order ASC, label ASC]],
        {},
        function(result)
            cb(result or {})
        end
    )
end

function LiBridgeServerFeeds.GetActiveAds(viewerIdentifier, cb)
    LiBridge.MySQL.Query(
        [[SELECT id, identifier, author_name, title, content, category, phone, anonymous,
                 premium, spotlight_until, created_at, expires_at
          FROM lifeinvader_feeds
          WHERE status = 'active' AND expires_at > NOW()
          ORDER BY (spotlight_until IS NOT NULL AND spotlight_until > NOW()) DESC, created_at DESC]],
        {},
        function(result)
            local ads = {}
            for _, row in ipairs(result or {}) do
                ads[#ads + 1] = LiBridgeServerFeeds.FormatAdRow(row, viewerIdentifier)
            end
            cb(ads)
        end
    )
end

function LiBridgeServerFeeds.GetTickerItems(cb)
    local items = {}
    local cfg = Config.Ticker or {}

    if cfg.enabled ~= false and type(cfg.items) == 'table' then
        for i = 1, #cfg.items do
            items[#items + 1] = cfg.items[i]
        end
    end

    LiBridge.MySQL.Query(
        [[SELECT title, author_name
          FROM lifeinvader_feeds
          WHERE status = 'active'
            AND ticker_until IS NOT NULL
            AND ticker_until > NOW()
          ORDER BY ticker_until DESC
          LIMIT 12]],
        {},
        function(result)
            for _, row in ipairs(result or {}) do
                items[#items + 1] = ('+++ %s — %s +++'):format(row.title, row.author_name)
            end
            cb(items)
        end
    )
end

function LiBridgeServerFeeds.LoadOpenData(viewerIdentifier, cb)
    LiBridgeServerFeeds.GetCategories(function(categories)
        LiBridgeServerFeeds.GetActiveAds(viewerIdentifier, function(ads)
            LiBridgeServerFeeds.GetTickerItems(function(ticker)
                LiBridgeServerFeeds.GetPlayerFeedHistory(viewerIdentifier, function(history)
                    cb({
                        categories = categories,
                        ads = ads,
                        ticker = ticker,
                        history = history,
                    })
                end)
            end)
        end)
    end)
end

function LiBridgeServerFeeds.BuildUiConfig()
    return {
        durations = Config.Durations or {},
        charCost = Config.CharCost or 2,
        maxTitleLength = Config.MaxTitleLength or 40,
        maxContentLength = Config.MaxContentLength or 500,
        premiumFeatures = Config.PremiumFeatures or {},
        deposit = Config.Deposit or { cash = true, bank = true },
        withdraw = Config.Withdraw or { cash = true, bank = false },
    }
end

function LiBridgeServerFeeds.BroadcastFeedNotification(payload, excludeSource)
    local c = Config.FeedNotifications or {}
    if c.enabled == false then
        return
    end

    for _, src in ipairs(GetPlayers()) do
        local sourceId = tonumber(src)
        if sourceId and (excludeSource == nil or sourceId ~= tonumber(excludeSource)) then
            TriggerClientEvent('ec_lifeinvader:client:feedPostedNotify', sourceId, payload or {})
        end
    end
end
