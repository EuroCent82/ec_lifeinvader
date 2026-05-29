--[[ ec_lifeinvader — livdb check / livdb fix (Datenbank-Schema) ]]

local function dbCheckCommand()
    local cfg = Config.Database or {}
    local name = cfg.checkCommand
    if type(name) ~= 'string' or name == '' then
        return 'livdb'
    end
    return name
end

local function canRunDbCheck(source)
    if source == 0 then
        return true
    end
    return LiBridge.Server.HasPermission(source, 'dbCheck')
        or LiBridge.Server.HasPermission(source, 'admin')
end

local function reply(source, message)
    if source == 0 then
        print(message)
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 59, 48 },
        multiline = true,
        args = { 'LifeInvader DB', message },
    })
end

local function printReport(source, report)
    local lines = {
        ('Framework: %s | Install: %s'):format(report.framework or '?', report.installFile or '?'),
        ('Tabellen: %d/%d OK'):format(#report.presentTables, #report.requiredTables),
    }

    if #report.missingTables > 0 then
        lines[#lines + 1] = 'FEHLEND: ' .. table.concat(report.missingTables, ', ')
    end

    if #report.missingPatches > 0 then
        lines[#lines + 1] = 'Spalten fehlen: ' .. table.concat(report.missingPatches, ', ')
    end

    if report.ok then
        lines[#lines + 1] = 'Status: OK'
    else
        lines[#lines + 1] = 'Status: Reparatur nötig (livdb fix)'
    end

    for i = 1, #lines do
        reply(source, lines[i])
    end
end

local function runCheck(source)
    LiBridgeServerDatabase.GetSchemaReport(function(report)
        printReport(source, report)
    end)
end

local function runFix(source)
    reply(source, 'Schema-Reparatur läuft…')

    LiBridgeServerDatabase.RepairSchema(function(ok, reason, report, applied)
        if not ok then
            reply(source, ('Reparatur fehlgeschlagen (%s)'):format(reason or 'unknown'))
            if report then
                printReport(source, report)
            end
            return
        end

        if applied and #applied > 0 then
            reply(source, 'Patches angewendet: ' .. table.concat(applied, ', '))
        end

        if report then
            printReport(source, report)
        else
            reply(source, 'Reparatur abgeschlossen.')
        end
    end)
end

RegisterCommand(dbCheckCommand(), function(source, args)
    if not canRunDbCheck(source) then
        if source ~= 0 then
            reply(source, 'Keine Berechtigung für livdb.')
        end
        return
    end

    local sub = string.lower(tostring(args[1] or 'check'))

    if sub == 'check' or sub == '' then
        runCheck(source)
        return
    end

    if sub == 'fix' or sub == 'repair' then
        runFix(source)
        return
    end

    reply(source, 'Nutze: livdb check | livdb fix')
end, false)
