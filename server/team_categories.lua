--[[ ec_lifeinvader — Team: Kategorien ]]

local function slugify(text)
    text = string.lower(tostring(text or ''))
    text = text:gsub('[äÄ]', 'ae'):gsub('[öÖ]', 'oe'):gsub('[üÜ]', 'ue'):gsub('ß', 'ss')
    text = text:gsub('[^%w]+', '-'):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
    return text
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
        end
    )
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

    local createdBy = LiBridge.Server.GetIdentifier(src)

    LiBridge.MySQL.Insert(
        [[INSERT INTO lifeinvader_categories (slug, label, icon, enabled, sort_order, created_by)
          VALUES (?, ?, ?, 1, 0, ?)]],
        { slug, label, icon, createdBy },
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
                    enabled = true,
                    sortOrder = 0,
                },
            })
        end
    )
end)
