--[[ ec_lifeinvader — Team: Rückerstattungen ]]

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function refundsConfig()
    return Config.Refunds or {}
end

local function mapRefundRow(row)
    return {
        id = tonumber(row.id),
        feedId = row.feed_id and tonumber(row.feed_id) or nil,
        identifier = row.identifier,
        amount = tonumber(row.amount) or 0,
        reason = row.reason,
        issuedBy = row.issued_by,
        createdAt = row.created_at,
    }
end

RegisterNetEvent('ec_lifeinvader:server:teamListRefunds', function(requestId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'refunds') then
        return
    end

    if refundsConfig().enabled == false then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, feed_id, identifier, amount, reason, issued_by, created_at
          FROM lifeinvader_refunds
          ORDER BY id DESC
          LIMIT 60]],
        {},
        function(rows)
            local refunds = {}
            for _, row in ipairs(rows or {}) do
                refunds[#refunds + 1] = mapRefundRow(row)
            end

            LiBridgeServerTeam.Respond(src, requestId, { ok = true, refunds = refunds })
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamLookupAdRefund', function(requestId, adId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'refunds') then
        return
    end

    adId = math.floor(tonumber(adId) or 0)
    if adId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, identifier, author_name, title, price_paid, status, created_at, expires_at
          FROM lifeinvader_feeds WHERE id = ? LIMIT 1]],
        { adId },
        function(rows)
            local row = rows and rows[1]
            if not row then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            LiBridge.MySQL.Query(
                'SELECT id FROM lifeinvader_refunds WHERE feed_id = ? LIMIT 1',
                { adId },
                function(refundRows)
                    local alreadyRefunded = refundRows and refundRows[1] ~= nil
                    local fullAmount = tonumber(row.price_paid) or 0
                    local remaining = LiBridgeServerFeeds.CalculateRemainingCredit(row)

                    LiBridgeServerTeam.Respond(src, requestId, {
                        ok = true,
                        ad = {
                            id = tonumber(row.id),
                            livId = LiBridgeServerFeeds.FormatLivId(row.id),
                            title = row.title,
                            authorName = row.author_name,
                            identifier = row.identifier,
                            pricePaid = fullAmount,
                            remainingCredit = remaining,
                            status = LiBridgeServerFeeds.FormatHistoryRow(row).status,
                            alreadyRefunded = alreadyRefunded,
                        },
                    })
                end
            )
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamIssueRefund', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'refunds') then
        return
    end

    if refundsConfig().enabled == false then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'feature_disabled' })
        return
    end

    data = data or {}
    local adId = math.floor(tonumber(data.feedId) or 0)
    if adId <= 0 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    local mode = tostring(data.mode or 'full')
    local reason = trim(data.reason or '')
    if reason == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'reason_required' })
        return
    end
    reason = reason:sub(1, 255)

    local issuedBy = LiBridge.Server.GetIdentifier(src) or 'team'

    LiBridge.MySQL.Query(
        [[SELECT id, identifier, author_name, title, price_paid, status, created_at, expires_at
          FROM lifeinvader_feeds WHERE id = ? LIMIT 1]],
        { adId },
        function(rows)
            local row = rows and rows[1]
            if not row then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            LiBridge.MySQL.Query(
                'SELECT id FROM lifeinvader_refunds WHERE feed_id = ? LIMIT 1',
                { adId },
                function(refundRows)
                    if refundRows and refundRows[1] then
                        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'already_refunded' })
                        return
                    end

                    local fullAmount = tonumber(row.price_paid) or 0
                    local remaining = LiBridgeServerFeeds.CalculateRemainingCredit(row)
                    local amount

                    if mode == 'remaining' then
                        amount = remaining
                    elseif mode == 'custom' then
                        amount = math.floor(tonumber(data.amount) or 0)
                    else
                        amount = fullAmount
                    end

                    if amount <= 0 then
                        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_amount' })
                        return
                    end

                    if mode == 'custom' and amount > fullAmount then
                        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_amount' })
                        return
                    end

                    local targetIdentifier = row.identifier

                    LiBridgeServerAccount.AddBalance(targetIdentifier, amount, function(ok, newBalance)
                        if not ok then
                            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                            return
                        end

                        LiBridge.MySQL.Insert(
                            [[INSERT INTO lifeinvader_refunds (feed_id, identifier, amount, reason, issued_by)
                              VALUES (?, ?, ?, ?, ?)]],
                            { adId, targetIdentifier, amount, reason, issuedBy },
                            function(insertId)
                                if not insertId then
                                    LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'db_failed' })
                                    return
                                end

                                local closeAd = data.closeAd ~= false
                                if closeAd and row.status ~= 'deleted' then
                                    LiBridge.MySQL.Execute(
                                        "UPDATE lifeinvader_feeds SET status = 'deleted' WHERE id = ?",
                                        { adId }
                                    )
                                end

                                LiBridgeServerTeam.Respond(src, requestId, {
                                    ok = true,
                                    refund = {
                                        id = insertId,
                                        feedId = adId,
                                        identifier = targetIdentifier,
                                        amount = amount,
                                        reason = reason,
                                        issuedBy = issuedBy,
                                    },
                                    balance = newBalance,
                                })
                            end
                        )
                    end)
                end
            )
        end
    )
end)
