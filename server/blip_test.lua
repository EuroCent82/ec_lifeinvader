RegisterNetEvent('ec_lifeinvader:server:blipTestLog', function(message)
    local src = source
    local name = src > 0 and (GetPlayerName(src) or ('ID ' .. src)) or 'Server'
    print(('^3[ec_lifeinvader:blip_test]^0 %s: %s'):format(name, tostring(message or '')))
end)
