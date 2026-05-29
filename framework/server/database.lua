LiBridge = LiBridge or {}
LiBridgeServerDatabase = LiBridgeServerDatabase or {}

--- Alle Tabellen aus install_*.sql — wird einzeln gegen information_schema geprüft.
local REQUIRED_TABLES = {
    'lifeinvader',
    'lifeinvader_feeds',
    'lifeinvader_categories',
    'lifeinvader_vouchers',
    'lifeinvader_voucher_redemptions',
    'lifeinvader_refunds',
}

local INSTALL_BY_FRAMEWORK = {
    esx = 'sql/install_esx.sql',
    qbcore = 'sql/install_qbcore.sql',
    qbox = 'sql/install_qbox.sql',
}

local FAKE_BY_FRAMEWORK = {
    esx = 'sql/fake_esx.sql',
    qbcore = 'sql/fake_qbcore.sql',
    qbox = 'sql/fake_qbox.sql',
}

--- Spalten-Patches für bestehende Installationen (information_schema).
local SCHEMA_PATCHES = {
    {
        table = 'lifeinvader_feeds',
        column = 'ticker_until',
        label = 'lifeinvader_feeds.ticker_until',
        alter = 'ALTER TABLE lifeinvader_feeds ADD COLUMN ticker_until TIMESTAMP NULL DEFAULT NULL AFTER anonym_until',
    },
    {
        table = 'lifeinvader',
        column = 'ad_slot_bonus',
        label = 'lifeinvader.ad_slot_bonus',
        alter = 'ALTER TABLE lifeinvader ADD COLUMN ad_slot_bonus INT NOT NULL DEFAULT 0 AFTER balance',
    },
}

local function fakeEnabled()
    if Config.fake == true then
        return true
    end
    local cfg = Config.Database or {}
    return cfg.fake == true
end

local function dbConfig()
    return Config.Database or {}
end

function LiBridgeServerDatabase.RequiredTables()
    return REQUIRED_TABLES
end

function LiBridgeServerDatabase.ResolveInstallFile()
    local cfg = dbConfig()
    if type(cfg.installFile) == 'string' and cfg.installFile ~= '' then
        return cfg.installFile
    end

    return INSTALL_BY_FRAMEWORK[LiBridge.Framework()]
end

local function stripLineComments(content)
    local lines = {}
    for line in content:gmatch('[^\r\n]+') do
        if not line:match('^%s*%-%-') then
            lines[#lines + 1] = line
        end
    end
    return table.concat(lines, '\n')
end

function LiBridgeServerDatabase.ParseStatements(content)
    local body = stripLineComments(content)
    local statements = {}

    for chunk in body:gmatch('([^;]+);') do
        local statement = chunk:match('^%s*(.-)%s*$')
        if statement and statement ~= '' then
            statements[#statements + 1] = statement
        end
    end

    return statements
end

local function rowTableName(row)
    if not row then
        return nil
    end
    return row.table_name or row.TABLE_NAME or row.name or row.NAME
end

function LiBridgeServerDatabase.GetMissingTables(cb)
    local placeholders = {}
    for _ = 1, #REQUIRED_TABLES do
        placeholders[#placeholders + 1] = '?'
    end

    local query = ([[
        SELECT table_name AS name
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name IN (%s)
    ]]):format(table.concat(placeholders, ', '))

    LiBridge.MySQL.Query(query, REQUIRED_TABLES, function(result)
        local present = {}

        for _, row in ipairs(result or {}) do
            local name = rowTableName(row)
            if name then
                present[string.lower(name)] = true
            end
        end

        local missing = {}
        for _, name in ipairs(REQUIRED_TABLES) do
            if not present[name] then
                missing[#missing + 1] = name
            end
        end

        cb(missing)
    end)
end

function LiBridgeServerDatabase.IsFullyInstalled(cb)
    LiBridgeServerDatabase.GetMissingTables(function(missing)
        cb(#missing == 0, missing)
    end)
end

local function runStatements(statements, index, cb)
    if index > #statements then
        cb(true)
        return
    end

    LiBridge.MySQL.Query(statements[index], {}, function()
        runStatements(statements, index + 1, cb)
    end)
end

local function executeInstall(filePath, missingBefore, cb)
    local resource = GetCurrentResourceName()
    local content = LoadResourceFile(resource, filePath)

    if not content or content == '' then
        print(('^1[ec_lifeinvader]^0 SQL-Datei nicht gefunden oder leer: %s'):format(filePath))
        cb(false, 'missing_file')
        return
    end

    local statements = LiBridgeServerDatabase.ParseStatements(content)
    if #statements == 0 then
        print(('^1[ec_lifeinvader]^0 Keine SQL-Statements in %s'):format(filePath))
        cb(false, 'empty_file')
        return
    end

    runStatements(statements, 1, function(ok)
        if not ok then
            cb(false, 'failed')
            return
        end

        LiBridgeServerDatabase.GetMissingTables(function(stillMissing)
            if #stillMissing > 0 then
                print(('^1[ec_lifeinvader]^0 Nach Install fehlen noch Tabellen: %s'):format(
                    table.concat(stillMissing, ', ')
                ))
                cb(false, 'incomplete')
                return
            end

            print(('^2[ec_lifeinvader]^0 Datenbank-Schema ausgeführt (%s)%s'):format(
                filePath,
                #missingBefore > 0 and (' — neu angelegt: ' .. table.concat(missingBefore, ', ')) or ''
            ))
            cb(true, 'installed')
        end)
    end)
end

function LiBridgeServerDatabase.Install(cb)
    cb = cb or function() end

    local cfg = dbConfig()
    if cfg.autoInstall == false then
        LiBridge.Debug('Datenbank autoInstall deaktiviert — übersprungen')
        cb(true, 'disabled')
        return
    end

    local filePath = LiBridgeServerDatabase.ResolveInstallFile()
    if not filePath then
        print(('^3[ec_lifeinvader]^0 Kein Install-SQL für Framework „%s“ — bitte Config.Database.installFile setzen'):format(
            LiBridge.Framework()
        ))
        cb(false, 'no_mapping')
        return
    end

    LiBridgeServerDatabase.GetMissingTables(function(missing)
        if #missing == 0 then
            if cfg.skipIfInstalled ~= false then
                LiBridge.Debug(
                    'Alle',
                    #REQUIRED_TABLES,
                    'Datenbank-Tabellen vorhanden — nichts anzulegen'
                )
                cb(true, 'complete')
                return
            end

            LiBridge.Debug('Alle Tabellen vorhanden — erzwinge SQL-Lauf (skipIfInstalled = false)')
            executeInstall(filePath, {}, cb)
            return
        end

        print(('^3[ec_lifeinvader]^0 Fehlende Tabellen (%d/%d): %s'):format(
            #missing,
            #REQUIRED_TABLES,
            table.concat(missing, ', ')
        ))

        executeInstall(filePath, missing, cb)
    end)
end

function LiBridgeServerDatabase.SchemaPatches()
    return SCHEMA_PATCHES
end

local function columnExists(tableName, columnName, cb)
    LiBridge.MySQL.Query(
        ([[SELECT COUNT(*) AS count FROM information_schema.columns
          WHERE table_schema = DATABASE()
            AND table_name = ?
            AND column_name = ?]]),
        { tableName, columnName },
        function(result)
            local count = 0
            if result and result[1] then
                count = tonumber(result[1].count or result[1]['COUNT(*)']) or 0
            end
            cb(count > 0)
        end
    )
end

local function ensureColumn(patch, cb)
    cb = cb or function() end

    columnExists(patch.table, patch.column, function(exists)
        if exists then
            cb(true, false)
            return
        end

        LiBridge.MySQL.Query(patch.alter, {}, function()
            LiBridge.Debug(('Schema-Patch: %s hinzugefügt'):format(patch.label))
            cb(true, true)
        end)
    end)
end

local function collectMissingPatches(index, missing, cb)
    if index > #SCHEMA_PATCHES then
        cb(missing)
        return
    end

    local patch = SCHEMA_PATCHES[index]
    columnExists(patch.table, patch.column, function(exists)
        if not exists then
            missing[#missing + 1] = patch.label
        end
        collectMissingPatches(index + 1, missing, cb)
    end)
end

function LiBridgeServerDatabase.GetMissingSchemaPatches(cb)
    collectMissingPatches(1, {}, cb)
end

--- @param cb fun(report: table)
function LiBridgeServerDatabase.GetSchemaReport(cb)
    cb = cb or function() end

    LiBridgeServerDatabase.GetMissingTables(function(missingTables)
        LiBridgeServerDatabase.GetMissingSchemaPatches(function(missingPatches)
            local presentTables = {}
            for _, name in ipairs(REQUIRED_TABLES) do
                local found = true
                for _, miss in ipairs(missingTables) do
                    if miss == name then
                        found = false
                        break
                    end
                end
                if found then
                    presentTables[#presentTables + 1] = name
                end
            end

            cb({
                ok = #missingTables == 0 and #missingPatches == 0,
                framework = LiBridge.Framework(),
                installFile = LiBridgeServerDatabase.ResolveInstallFile(),
                requiredTables = REQUIRED_TABLES,
                presentTables = presentTables,
                missingTables = missingTables,
                missingPatches = missingPatches,
                patchCount = #SCHEMA_PATCHES,
            })
        end)
    end)
end

function LiBridgeServerDatabase.EnsureSchemaPatches(cb)
    cb = cb or function() end

    local function runPatch(index, applied)
        if index > #SCHEMA_PATCHES then
            cb(true, applied)
            return
        end

        ensureColumn(SCHEMA_PATCHES[index], function(ok, wasApplied)
            if not ok then
                cb(false, applied)
                return
            end
            if wasApplied then
                applied[#applied + 1] = SCHEMA_PATCHES[index].label
            end
            runPatch(index + 1, applied)
        end)
    end

    runPatch(1, {})
end

function LiBridgeServerDatabase.RepairSchema(cb)
    cb = cb or function() end

    LiBridgeServerDatabase.Install(function(installOk, installReason)
        if not installOk and installReason ~= 'disabled' and installReason ~= 'complete' then
            cb(false, 'install_failed', installReason)
            return
        end

        LiBridgeServerDatabase.EnsureSchemaPatches(function(patchOk, applied)
            if not patchOk then
                cb(false, 'patch_failed', nil, applied)
                return
            end

            LiBridgeServerDatabase.GetSchemaReport(function(report)
                cb(report.ok == true, report.ok and 'ok' or 'incomplete', report, applied)
            end)
        end)
    end)
end

function LiBridgeServerDatabase.SeedFake(cb)
    cb = cb or function() end

    if not fakeEnabled() then
        cb(true, 'disabled')
        return
    end

    local filePath = FAKE_BY_FRAMEWORK[LiBridge.Framework()]
    if not filePath then
        cb(false, 'no_fake_file')
        return
    end

    LiBridge.MySQL.Query('SELECT COUNT(*) AS count FROM lifeinvader_categories', {}, function(result)
        local count = 0
        if result and result[1] then
            count = tonumber(result[1].count or result[1]['COUNT(*)']) or 0
        end

        if count > 0 then
            LiBridge.Debug('Demo-Daten bereits vorhanden — fake SQL übersprungen')
            cb(true, 'exists')
            return
        end

        executeInstall(filePath, { 'demo-seed' }, function(ok, reason)
            if ok then
                print(('^2[ec_lifeinvader]^0 Demo-Daten geladen (%s)'):format(filePath))
            end
            cb(ok, reason)
        end)
    end)
end

function LiBridgeServerDatabase.FinishSetup(cb)
    cb = cb or function() end

    LiBridgeServerDatabase.EnsureSchemaPatches(function(patchOk)
        if not patchOk then
            cb(false, 'patch_failed')
            return
        end

        LiBridgeServerDatabase.SeedFake(function(ok, reason)
            cb(ok, reason)
        end)
    end)
end
