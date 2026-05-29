--[[ ec_lifeinvader — Team: Spielersuche (online) ]]

local function normalize(text)
    return string.lower(tostring(text or ''):gsub('%s+', ' '))
end

local function matchesQuery(query, ...)
    if query == '' then
        return false
    end

    for i = 1, select('#', ...) do
        local value = normalize(select(i, ...))
        if value ~= '' and value:find(query, 1, true) then
            return true
        end
    end

    return false
end

local function collectOnlinePlayers(query)
    local results = {}
    local q = normalize(query)

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            local identifier = LiBridge.Server.GetIdentifier(src)
            local charName = LiBridge.Server.GetCharacterName(src) or ''
            local fivemName = GetPlayerName(src) or ''

            if matchesQuery(q, identifier, charName, fivemName) then
                results[#results + 1] = {
                    source = src,
                    identifier = identifier,
                    characterName = charName,
                    fivemName = fivemName,
                    label = charName ~= '' and charName or fivemName,
                }
            end
        end
    end

    table.sort(results, function(a, b)
        return (a.label or '') < (b.label or '')
    end)

    return results
end

RegisterNetEvent('ec_lifeinvader:server:teamSearchPlayers', function(requestId, query)
    local src = source

    if not LiBridgeServerTeam.Guard(src, requestId) then
        return
    end

    query = tostring(query or '')
    if #query < 2 then
        LiBridgeServerTeam.Respond(src, requestId, { ok = false, error = 'query_too_short' })
        return
    end

    local players = collectOnlinePlayers(query)
    LiBridgeServerTeam.Respond(src, requestId, {
        ok = true,
        players = players,
        count = #players,
    })
end)
