--[[ ec_lifeinvader — Team: Kategorien ]]

local function slugify(text)
    text = string.lower(tostring(text or ''))
    text = text:gsub('[äÄ]', 'ae'):gsub('[öÖ]', 'oe'):gsub('[üÜ]', 'ue'):gsub('ß', 'ss')
    text = text:gsub('[^%w]+', '-'):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
    return text
end

local function mapCategoryRow(row)
    return {
        slug = row.slug,
        label = row.label,
        icon = row.icon or 'ellipsis',
    }
end

local function broadcastPlayerCategories()
    LiBridgeServerFeeds.GetCategories(function(rows)
        local categories = {}
        for _, row in ipairs(rows or {}) do
            categories[#categories + 1] = mapCategoryRow(row)
        end
        TriggerClientEvent('ec_lifeinvader:client:categoriesUpdated', -1, categories)
    end)
end

local function slugTaken(slug, excludeId, cb)
    local query = 'SELECT id FROM lifeinvader_categories WHERE slug = ?'
    local params = { slug }

    if excludeId then
        query = query .. ' AND id <> ?'
        params[#params + 1] = excludeId
    end

    query = query .. ' LIMIT 1'

    LiBridge.MySQL.Query(query, params, function(rows)
        cb(rows and rows[1] ~= nil)
    end)
end

RegisterNetEvent('ec_lifeinvader:server:teamListCategories', function(requestId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'categories') then
        return
    end

    LiBridge.MySQL.Query(
        [[SELECT id, slug, label, icon, enabled, sort_order
          FROM lifeinvader_categories
          ORDER BY sort_order ASC, label ASC]],
        {},
        function(rows)
            local categories = {}
            for _, row in ipairs(rows or {}) do
                categories[#categories + 1] = {
                    id = tonumber(row.id),
                    slug = row.slug,
                    label = row.label,
                    icon = row.icon or 'ellipsis',
                    enabled = row.enabled == 1 or row.enabled == true,
                    sortOrder = tonumber(row.sort_order) or 0,
                }
            end

            LiBridgeServerTeam.Respond(src, requestId, { ok = true, categories = categories })
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamSetCategoryEnabled', function(requestId, categoryId, enabled)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'categories') then
        return
    end

    categoryId = tonumber(categoryId)
    if not categoryId then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    LiBridge.MySQL.Execute(
        'UPDATE lifeinvader_categories SET enabled = ? WHERE id = ?',
        { enabled == true and 1 or 0, categoryId },
        function(affected)
            if (tonumber(affected) or 0) < 1 then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            LiBridgeServerTeam.Respond(src, requestId, { ok = true })
            broadcastPlayerCategories()
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamUpdateCategory', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'categories') then
        return
    end

    data = data or {}
    local categoryId = tonumber(data.id)
    if not categoryId then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    local label = tostring(data.label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local slug = slugify(data.slug ~= '' and data.slug or label)
    local icon = tostring(data.icon or 'ellipsis'):gsub('^%s+', ''):gsub('%s+$', '')
    local enabled = data.enabled ~= false
    local sortOrder = math.floor(tonumber(data.sortOrder) or 0)

    if label == '' or slug == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
        return
    end

    slugTaken(slug, categoryId, function(taken)
        if taken then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'duplicate_slug' })
            return
        end

    LiBridge.MySQL.Execute(
        [[UPDATE lifeinvader_categories
          SET slug = ?, label = ?, icon = ?, enabled = ?, sort_order = ?
          WHERE id = ?]],
        { slug, label, icon, enabled and 1 or 0, sortOrder, categoryId },
        function(affected)
            if (tonumber(affected) or 0) < 1 then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            LiBridgeServerTeam.Respond(src, requestId, {
                ok = true,
                category = {
                    id = categoryId,
                    slug = slug,
                    label = label,
                    icon = icon,
                    enabled = enabled,
                    sortOrder = sortOrder,
                },
            })
            broadcastPlayerCategories()
        end
    )
    end)
end)

RegisterNetEvent('ec_lifeinvader:server:teamDeleteCategory', function(requestId, categoryId)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'categories') then
        return
    end

    categoryId = tonumber(categoryId)
    if not categoryId then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_id' })
        return
    end

    LiBridge.MySQL.Query(
        'SELECT slug FROM lifeinvader_categories WHERE id = ? LIMIT 1',
        { categoryId },
        function(rows)
            local row = rows and rows[1]
            if not row then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                return
            end

            local slug = row.slug
            LiBridge.MySQL.Query(
                [[SELECT COUNT(*) AS count
                  FROM lifeinvader_feeds
                  WHERE category = ?
                    AND status = 'active'
                    AND expires_at > NOW()]],
                { slug },
                function(countRows)
                    local count = tonumber(countRows and countRows[1] and countRows[1].count) or 0
                    if count > 0 then
                        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'category_in_use' })
                        return
                    end

                    LiBridge.MySQL.Execute(
                        'DELETE FROM lifeinvader_categories WHERE id = ?',
                        { categoryId },
                        function(affected)
                            if (tonumber(affected) or 0) < 1 then
                                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'not_found' })
                                return
                            end

                            LiBridgeServerTeam.Respond(src, requestId, { ok = true, deletedId = categoryId })
                            broadcastPlayerCategories()
                        end
                    )
                end
            )
        end
    )
end)

RegisterNetEvent('ec_lifeinvader:server:teamReorderCategories', function(requestId, orderList)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'categories') then
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
            LiBridgeServerTeam.Respond(src, requestId, { ok = true })
            broadcastPlayerCategories()
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
            'UPDATE lifeinvader_categories SET sort_order = ? WHERE id = ?',
            { sortOrder, id },
            function()
                index = index + 1
                applyNext()
            end
        )
    end

    applyNext()
end)

RegisterNetEvent('ec_lifeinvader:server:teamCreateCategory', function(requestId, data)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId, 'categories') then
        return
    end

    data = data or {}
    local label = tostring(data.label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local slug = slugify(data.slug ~= '' and data.slug or label)
    local icon = tostring(data.icon or 'ellipsis'):gsub('^%s+', ''):gsub('%s+$', '')

    if label == '' or slug == '' then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'invalid_input' })
        return
    end

    local enabled = data.enabled ~= false
    local createdBy = LiBridge.Server.GetIdentifier(src)

    slugTaken(slug, nil, function(taken)
        if taken then
            LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'duplicate_slug' })
            return
        end

    LiBridge.MySQL.Query('SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM lifeinvader_categories', {}, function(result)
        local sortOrder = tonumber(result and result[1] and result[1].next_order) or 0

    LiBridge.MySQL.Insert(
        [[INSERT INTO lifeinvader_categories (slug, label, icon, enabled, sort_order, created_by)
          VALUES (?, ?, ?, ?, ?, ?)]],
        { slug, label, icon, enabled and 1 or 0, sortOrder, createdBy },
        function(insertId)
            if not insertId then
                LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'duplicate_or_db_failed' })
                return
            end

            LiBridgeServerTeam.Respond(src, requestId, {
                ok = true,
                category = {
                    id = insertId,
                    slug = slug,
                    label = label,
                    icon = icon,
                    enabled = enabled,
                    sortOrder = sortOrder,
                },
            })
            broadcastPlayerCategories()
        end
    )
    end)
    end)
end)
