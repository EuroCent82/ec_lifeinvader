LiBridge = LiBridge or {}
LiBridgeServerFeeds = LiBridgeServerFeeds or {}

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
                cb({
                    categories = categories,
                    ads = ads,
                    ticker = ticker,
                })
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
