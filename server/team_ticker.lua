--[[ ec_lifeinvader — Team: Live-Ticker (Premium-Anzeigen) ]]

local function mapFeedTickerRow(row)
    local title = tostring(row.title or '')
    local enabled = row.ticker_enabled == 1 or row.ticker_enabled == true
    local isRunning = row.is_running == 1 or row.is_running == true

    return {
        id = tonumber(row.id),
        feedId = tonumber(row.id),
        title = title,
        message = LiBridgeServerFeeds.FormatTickerLine(title),
        enabled = enabled,
        sortOrder = tonumber(row.ticker_sort_order) or 999999,
        createdAt = row.created_at,
        tickerUntil = row.ticker_until,
        isRunning = isRunning,
        isLive = isRunning and enabled,
    }
end

local function respondWithPreview(src, requestId, payload)
    LiBridgeServerFeeds.GetTickerItems(function(lines)
        payload.previewLines = lines
        payload.activeCount = payload.activeCount or 0
        payload.maxSlots = LiBridgeServerFeeds.GetTickerMaxSlots()
        LiBridgeServerTeam.Respond(src, requestId, payload)
    end)
end

RegisterNetEvent('ec_lifeinvader:server:teamListTicker', function(requestId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, title, ticker_until, ticker_enabled, ticker_sort_order, created_at,
                 (ticker_until > NOW()) AS is_running
          FROM lifeinvader_feeds
          WHERE ticker_until IS NOT NULL
          ORDER BY COALESCE(ticker_sort_order, 999999) ASC, created_at DESC]],
        {},
        function(rows)
            local items = {}
            for _, row in ipairs(rows or {}) do
                items[#items + 1] = mapFeedTickerRow(row)
            end

            LiBridgeServerFeeds.CountActiveTickerAds(function(activeCount)
                respondWithPreview(src, requestId, {
                    ok = true,
                    items = items,
                    activeCount = activeCount,
                })
            end)
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamUpdateTicker', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end

    data = data or {}
    local feedId = tonumber(data.id)
    if not feedId then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    local wantEnabled = data.enabled ~= false

    local function applyUpdate()
        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader_feeds SET ticker_enabled = ? WHERE id = ? AND ticker_until IS NOT NULL',
            { wantEnabled and 1 or 0, feedId },
            function(affected)
                if (tonumber(affected) or 0) < 1 then
                    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                    return
                end

                LiBridgeServerFeeds.CountActiveTickerAds(function(activeCount)
                    respondWithPreview(src, requestId, {
                        ok = true,
                        activeCount = activeCount,
                    })
                end)
            end
        )
    end

    if not wantEnabled then
        applyUpdate()
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, ticker_until FROM lifeinvader_feeds
          WHERE id = ? AND ticker_until IS NOT NULL AND ticker_until > NOW()]],
        { feedId },
        function(rows)
            if not rows or not rows[1] then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'ticker_expired' })
                return
            end

            LiBridgeServerFeeds.CountActiveTickerAds(function(activeCount)
                local maxSlots = LiBridgeServerFeeds.GetTickerMaxSlots()
                if activeCount >= maxSlots then
                    LiBridgeServerTeam.Respond(src, requestId, {
                        ok = false,
                        error = 'ticker_slots_full',
                        activeCount = activeCount,
                        maxSlots = maxSlots,
                    })
                    return
                end

                applyUpdate()
            end, feedId)
        end
    )
end)

-- Legacy-NUI-Callbacks (freie Texteinträge entfallen)
RegisterNetEvent('ec_lifeinvader:server:teamCreateTicker', function(requestId)
    local src = source
    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end
    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
end)

RegisterNetEvent('ec_lifeinvader:server:teamDeleteTicker', function(requestId)
    local src = source
    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end
    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
end)

RegisterNetEvent('ec_lifeinvader:server:teamReorderTicker', function(requestId, orderList)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end

    orderList = orderList or {}
    if #orderList == 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
        return
    end

    local index = 1

    local function applyNext()
        if index > #orderList then
            LiBridgeServerFeeds.CountActiveTickerAds(function(activeCount)
                respondWithPreview(src, requestId, {
                    ok = true,
                    activeCount = activeCount,
                })
            end)
            return
        end

        local entry = orderList[index]
        local id = tonumber(entry.id)
        local sortOrder = math.floor(tonumber(entry.sortOrder) or (index - 1))

        if not id then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
            return
        end

        LiBridge.MySQL.Execute(
            'UPDATE lifeinvader_feeds SET ticker_sort_order = ? WHERE id = ? AND ticker_until IS NOT NULL',
            { sortOrder, id },
            function()
                index = index + 1
                applyNext()
            end
        )
    end

    applyNext()
end)
