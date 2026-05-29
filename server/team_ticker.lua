--[[ ec_lifeinvader — Team: Live-Ticker (eigene Einträge) ]]

local function mapTickerRow(row)
    return {
        id = tonumber(row.id),
        message = row.message,
        enabled = row.enabled == 1 or row.enabled == true,
        sortOrder = tonumber(row.sort_order) or 0,
        createdAt = row.created_at,
    }
end

local function seedFromConfigIfEmpty(cb)
    LiBridge.MySQL.Query('SELECT COUNT(*) AS count FROM lifeinvader_ticker', {}, function(result)
        local count = tonumber(result and result[1] and result[1].count) or 0
        if count > 0 then
            cb()
            return
        end

        local cfg = Config.Ticker or {}
        local items = cfg.items or {}
        if #items == 0 then
            cb()
            return
        end

        local index = 1
        local function insertNext()
            if index > #items then
                cb()
                return
            end

            LiBridge.MySQL.Insert(
                'INSERT INTO lifeinvader_ticker (message, enabled, sort_order) VALUES (?, 1, ?)',
                { items[index], index - 1 },
                function()
                    index = index + 1
                    insertNext()
                end
            )
        end

        insertNext()
    end)
end

RegisterNetEvent('ec_lifeinvader:server:teamListTicker', function(requestId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end

    seedFromConfigIfEmpty(function()
        LiBridge.MySQL.Query(
            [[SELECT id, message, enabled, sort_order, created_at
              FROM lifeinvader_ticker
              ORDER BY sort_order ASC, id ASC]],
            {},
            function(rows)
                local items = {}
                for _, row in ipairs(rows or {}) do
                    items[#items + 1] = mapTickerRow(row)
                end

                LiBridgeServerFeeds.GetTickerItems(function(lines)
                    LiBridgeServerTeam.Respond(src, requestId, {
                        ok = true,
                        items = items,
                        previewLines = lines,
                    })
                end)
            end
        )
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamCreateTicker', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end

    data = data or {}
    local message = tostring(data.message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if message == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
        return
    end

    LiBridge.MySQL.Query('SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM lifeinvader_ticker', {}, function(result)
        local sortOrder = tonumber(result and result[1] and result[1].next_order) or 0
        local createdBy = LiBridge.Server.GetIdentifier(src)

        LiBridge.MySQL.Insert(
            'INSERT INTO lifeinvader_ticker (message, enabled, sort_order, created_by) VALUES (?, 1, ?, ?)',
            { message, sortOrder, createdBy },
            function(insertId)
                if not insertId then
                    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                    return
                end

                LiBridgeServerFeeds.GetTickerItems(function(lines)
                    LiBridgeServerTeam.Respond(src, requestId, {
                        ok = true,
                        item = {
                            id = insertId,
                            message = message,
                            enabled = true,
                            sortOrder = sortOrder,
                        },
                        previewLines = lines,
                    })
                end)
            end
        )
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamUpdateTicker', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end

    data = data or {}
    local id = tonumber(data.id)
    local message = tostring(data.message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if not id or message == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
        return
    end

    LiBridge.MySQL.Execute(
        'UPDATE lifeinvader_ticker SET message = ?, enabled = ? WHERE id = ?',
        { message, data.enabled == false and 0 or 1, id },
        function(affected)
            if (tonumber(affected) or 0) < 1 then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            LiBridgeServerFeeds.GetTickerItems(function(lines)
                LiBridgeServerTeam.Respond(src, requestId, {
                    ok = true,
                    previewLines = lines,
                })
            end)
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamDeleteTicker', function(requestId, tickerId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'ticker') then
        return
    end

    tickerId = tonumber(tickerId)
    if not tickerId then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    LiBridge.MySQL.Execute('DELETE FROM lifeinvader_ticker WHERE id = ?', { tickerId }, function(affected)
        if (tonumber(affected) or 0) < 1 then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
            return
        end

        LiBridgeServerFeeds.GetTickerItems(function(lines)
            LiBridgeServerTeam.Respond(src, requestId, {
                ok = true,
                previewLines = lines,
            })
        end)
    end)
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
            LiBridgeServerFeeds.GetTickerItems(function(lines)
                LiBridgeServerTeam.Respond(src, requestId, {
                    ok = true,
                    previewLines = lines,
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
            'UPDATE lifeinvader_ticker SET sort_order = ? WHERE id = ?',
            { sortOrder, id },
            function()
                index = index + 1
                applyNext()
            end
        )
    end

    applyNext()
end)
