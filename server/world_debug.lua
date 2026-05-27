--[[ ec_lifeinvader — Welt-Spawn-Log in der Server-Konsole ]]

local function worldDebugEnabled()
    if Config.Debug == true then
        return true
    end
    local world = Config.World or {}
    return world.debug == true
end

local function fmtCoord(x, y, z)
    return ('%.2f, %.2f, %.2f'):format(tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0)
end

RegisterNetEvent('ec_lifeinvader:server:worldDebug', function(payload)
    if not worldDebugEnabled() then
        return
    end

    if type(payload) ~= 'table' then
        return
    end

    local src = source
    local playerName = src > 0 and (GetPlayerName(src) or ('ID ' .. src)) or 'Server'
    local reason = tostring(payload.reason or '?')

    local blips = payload.blips or {}
    local npcs = payload.npcs or {}
    local objects = payload.objects or {}

    local blipOk = 0
    for i = 1, #blips do
        blipOk = blipOk + 1
    end

    local npcOk = 0
    for i = 1, #npcs do
        if npcs[i].ok == true then
            npcOk = npcOk + 1
        end
    end

    print('')
    print('^2[ec_lifeinvader]^0 ─── Welt-Spawn (' .. playerName .. ' | ' .. reason .. ') ───')
    print(('^2[ec_lifeinvader]^0 %d Blips gespawnt — Koordinaten:'):format(blipOk))

    for i = 1, #blips do
        local b = blips[i]
        print(('^2[ec_lifeinvader]^0   • %s "%s" @ %s'):format(
            tostring(b.id or '?'),
            tostring(b.name or 'LifeInvader'),
            fmtCoord(b.x, b.y, b.z)
        ))
    end

    if blipOk == 0 then
        print('^1[ec_lifeinvader]^0   (keine Blips)')
    end

    print(('^2[ec_lifeinvader]^0 %d NPCs gespawnt — Koordinaten:'):format(npcOk))

    for i = 1, #npcs do
        local n = npcs[i]
        local status = n.ok == true and '^2OK^0' or '^1FEHLT^0'
        local detail = n.detail and (' (' .. tostring(n.detail) .. ')') or ''
        print(('^2[ec_lifeinvader]^0   • %s [%s] Modell=%s @ %s%s'):format(
            tostring(n.id or '?'),
            status,
            tostring(n.model or '?'),
            fmtCoord(n.x, n.y, n.z),
            detail
        ))
    end

    if #npcs == 0 then
        print('^1[ec_lifeinvader]^0   (keine NPC-Standorte gemeldet)')
    elseif npcOk == 0 then
        print('^1[ec_lifeinvader]^0   WARNUNG: Kein NPC konnte gespawnt werden!')
    end

    if #objects > 0 then
        print(('^2[ec_lifeinvader]^0 %d Objekte — Koordinaten:'):format(#objects))
        for i = 1, #objects do
            local o = objects[i]
            local status = o.ok == true and '^2OK^0' or '^1FEHLT^0'
            print(('^2[ec_lifeinvader]^0   • %s [%s] @ %s'):format(
                tostring(o.id or '?'),
                status,
                fmtCoord(o.x, o.y, o.z)
            ))
        end
    end

    print('^2[ec_lifeinvader]^0 ─────────────────────────────────────────')
    print('')
end)

CreateThread(function()
    Wait(500)
    if worldDebugEnabled() then
        print('^2[ec_lifeinvader]^0 Welt-Debug aktiv — nach Spawn erscheinen Blip/NPC-Zeilen in dieser Konsole.')
    end
end)
