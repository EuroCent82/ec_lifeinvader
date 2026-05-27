--[[ ec_lifeinvader — Server ]]

CreateThread(function()
    LiBridge.Debug('Server geladen — Framework:', LiBridge.Framework())
end)

RegisterCommand('ec_li_testnotify', function(source, args)
    if source ~= 0 and not LiBridge.Server.HasPermission(source, 'admin') then
        return
    end

    local title = table.concat(args or {}, ' ')
    if title == '' then
        title = 'Frische Anzeige aus Los Santos'
    end

    LiBridgeServerFeeds.BroadcastFeedNotification({
        author = source == 0 and 'System' or (LiBridge.Server.GetCharacterName(source) or GetPlayerName(source) or 'Unbekannt'),
        title = title,
    }, nil)
end, false)
