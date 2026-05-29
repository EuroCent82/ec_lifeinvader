--[[ ec_lifeinvader — Team: Tablet von überall öffnen ]]

local function remoteOpenConfig()
    return Config.TeamRemoteOpen or {}
end

CreateThread(function()
    local cfg = remoteOpenConfig()
    if cfg.enabled == false then
        return
    end

    local command = cfg.command or 'lifeinvader'
    if command == '' then
        return
    end

    RegisterCommand(command, function()
        if EcLifeInvader and EcLifeInvader.IsNuiOpen and EcLifeInvader.IsNuiOpen() then
            return
        end

        TriggerServerEvent('ec_lifeinvader:server:teamRemoteOpen')
    end, false)

    if cfg.help ~= false then
        TriggerEvent('chat:addSuggestion', '/' .. command, cfg.helpText or 'LifeInvader Team-Tablet öffnen')
    end
end)
