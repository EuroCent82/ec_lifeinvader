LiBridge = LiBridge or {}
LiBridge.Server = LiBridge.Server or {}

function LiBridge.Server.GetFrameworkModule()
    local fw = LiBridge.Framework()
    if fw == 'qbcore' then
        return LiBridgeServerQbcore
    end
    if fw == 'qbox' then
        return LiBridgeServerQbox
    end
    if fw == 'standalone' then
        return nil
    end
    return LiBridgeServerEsx
end

function LiBridge.Server.GetPlayer(source)
    local mod = LiBridge.Server.GetFrameworkModule()
    if not mod or not mod.GetPlayer then
        return nil
    end
    return mod.GetPlayer(source)
end

function LiBridge.Server.GetIdentifier(source)
    local mod = LiBridge.Server.GetFrameworkModule()
    if mod and mod.GetIdentifier then
        local id = mod.GetIdentifier(source)
        if id then
            return id
        end
    end

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local ident = GetPlayerIdentifier(source, i)
        if ident and ident:find('license:') then
            return ident
        end
    end
    return nil
end

function LiBridge.Server.GetCharacterName(source)
    local mod = LiBridge.Server.GetFrameworkModule()
    if mod and mod.GetCharacterName then
        return mod.GetCharacterName(source)
    end
    return GetPlayerName(source)
end

function LiBridge.Server.HasPermission(source, key)
    return LiBridgeServerPermissions.Has(source, key)
end

function LiBridge.Server.RegisterCallback(name, handler)
    if LiBridgeServerCustom.Call('RegisterServerCallback', name, handler) then
        return true
    end

    if LiBridge.Library() == 'ox_lib' and lib and lib.callback and lib.callback.register then
        lib.callback.register(name, function(src, ...)
            return handler(src, ...)
        end)
        return true
    end

    local fw = LiBridge.Framework()
    if fw == 'esx' then
        return LiBridgeServerEsx.RegisterCallback(name, handler)
    end
    if fw == 'qbox' then
        return LiBridgeServerQbox.RegisterCallback(name, handler)
    end
    if fw == 'qbcore' then
        return LiBridgeServerQbcore.RegisterCallback(name, handler)
    end
    return false
end

function LiBridge.Server.Init()
    LiBridge.MySQL.WaitReady()

    local dbReady = false
    LiBridgeServerDatabase.Install(function(ok, reason)
        if not ok and reason ~= 'disabled' and reason ~= 'complete' then
            print('^1[ec_lifeinvader]^0 Datenbank-Installation fehlgeschlagen:', reason or 'unknown')
            dbReady = true
            return
        end

        LiBridgeServerDatabase.FinishSetup(function()
            dbReady = true
        end)
    end)

    while not dbReady do
        Wait(50)
    end

    LiBridgeServerInventory.RegisterOpenItem()
    LiBridge.Debug('Bridge initialisiert — Framework:', LiBridge.Framework(), 'Target:', LiBridge.Target(), 'Inventory:', LiBridge.Inventory(), 'MySQL:', LiBridge.MySql())
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    LiBridge.Server.Init()
end)
