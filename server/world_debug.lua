--[[ ec_lifeinvader — Welt-Spawn-Debug (Server-Konsole) ]]

local function worldDebugEnabled()
    if Config.Debug == true then
        return true
    end
    local world = Config.World or {}
    return world.debug == true
end

local function playerLabel(source)
    if source == 0 then
        return 'console'
    end
    local name = GetPlayerName(source)
    if name and name ~= '' then
        return ('%s [%d]'):format(name, source)
    end
    return ('player [%d]'):format(source)
end

RegisterNetEvent('ec_lifeinvader:server:worldDebug', function(payload)
    if not worldDebugEnabled() then
        return
    end

    if type(payload) ~= 'table' then
        print('^1[ec_lifeinvader:world]^0 Ungültiger Debug-Payload')
        return
    end

    local src = source
    local reason = tostring(payload.reason or '?')
    local complete = payload.worldComplete == true

    print('^5[ec_lifeinvader:world]^0 ───────────────────────────────────────')
    print(('^5[ec_lifeinvader:world]^0 Spieler: %s | Grund: %s | vollständig: %s'):format(
        playerLabel(src),
        reason,
        complete and 'JA' or 'NEIN'
    ))

    local blips = payload.blips or {}
    print(('^5[ec_lifeinvader:world]^0 Blips: %d gesetzt (global enabled: %s)'):format(
        tonumber(payload.blipCount) or #blips,
        tostring(payload.blipGlobalEnabled)
    ))

    for i = 1, #blips do
        local b = blips[i]
        if type(b) == 'table' then
            print(('^5[ec_lifeinvader:world]^0   [%d] id=%s name="%s" sprite=%s color=%s @ %.2f, %.2f, %.2f blipHandle=%s'):format(
                i,
                tostring(b.locationId or '?'),
                tostring(b.label or '?'),
                tostring(b.sprite or '?'),
                tostring(b.color or '?'),
                tonumber(b.x) or 0.0,
                tonumber(b.y) or 0.0,
                tonumber(b.z) or 0.0,
                tostring(b.handle or '?')
            ))
        end
    end

    local npcs = payload.npcs or {}
    print(('^5[ec_lifeinvader:world]^0 NPCs: %d Einträge'):format(#npcs))

    for i = 1, #npcs do
        local n = npcs[i]
        if type(n) == 'table' then
            print(('^5[ec_lifeinvader:world]^0   [%d] id=%s model=%s ok=%s entity=%s @ %.2f, %.2f, %.2f | %s'):format(
                i,
                tostring(n.locationId or '?'),
                tostring(n.model or '?'),
                tostring(n.success == true),
                tostring(n.entity or '—'),
                tonumber(n.x) or 0.0,
                tonumber(n.y) or 0.0,
                tonumber(n.z) or 0.0,
                tostring(n.detail or '')
            ))
        end
    end

    local objects = payload.objects or {}
    if #objects > 0 then
        print(('^5[ec_lifeinvader:world]^0 Objekte: %d'):format(#objects))
        for i = 1, #objects do
            local o = objects[i]
            if type(o) == 'table' then
                print(('^5[ec_lifeinvader:world]^0   [%d] id=%s model=%s ok=%s @ %.2f, %.2f, %.2f | %s'):format(
                    i,
                    tostring(o.locationId or '?'),
                    tostring(o.model or '?'),
                    tostring(o.success == true),
                    tonumber(o.x) or 0.0,
                    tonumber(o.y) or 0.0,
                    tonumber(o.z) or 0.0,
                    tostring(o.detail or '')
                ))
            end
        end
    end

    print('^5[ec_lifeinvader:world]^0 ───────────────────────────────────────')
end)

CreateThread(function()
    if worldDebugEnabled() then
        print('^5[ec_lifeinvader:world]^0 Debug aktiv — Client meldet Blips/NPCs an diese Konsole (Config.Debug oder Config.World.debug)')
    end
end)
