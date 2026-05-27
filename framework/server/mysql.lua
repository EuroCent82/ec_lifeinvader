LiBridge = LiBridge or {}
LiBridge.MySQL = LiBridge.MySQL or {}

local function flavour()
    return LiBridge.MySql()
end

function LiBridge.MySQL.WaitReady()
    if flavour() == 'mysql-async' then
        while GetResourceState('mysql-async') ~= 'started' do
            Wait(200)
        end
        return
    end

    while GetResourceState('oxmysql') ~= 'started' do
        Wait(200)
    end
end

function LiBridge.MySQL.IsReady()
    if flavour() == 'mysql-async' then
        return GetResourceState('mysql-async') == 'started' and MySQL and MySQL.Async ~= nil
    end
    return GetResourceState('oxmysql') == 'started'
end

function LiBridge.MySQL.Query(query, params, cb)
    params = params or {}

    if flavour() == 'mysql-async' then
        if not (MySQL and MySQL.Async and MySQL.Async.fetchAll) then
            LiBridge.Debug('mysql-async nicht bereit')
            return
        end
        MySQL.Async.fetchAll(query, params, cb or function() end)
        return
    end

    exports.oxmysql:query(query, params, cb or function() end)
end

function LiBridge.MySQL.Single(query, params, cb)
    params = params or {}

    if flavour() == 'mysql-async' then
        if not (MySQL and MySQL.Async and MySQL.Async.fetchScalar) then
            return
        end
        MySQL.Async.fetchScalar(query, params, cb or function() end)
        return
    end

    exports.oxmysql:scalar(query, params, cb or function() end)
end

function LiBridge.MySQL.Execute(query, params, cb)
    params = params or {}

    if flavour() == 'mysql-async' then
        if not (MySQL and MySQL.Async and MySQL.Async.execute) then
            return
        end
        MySQL.Async.execute(query, params, cb or function() end)
        return
    end

    exports.oxmysql:update(query, params, cb or function() end)
end

function LiBridge.MySQL.Insert(query, params, cb)
    params = params or {}

    if flavour() == 'mysql-async' then
        if not (MySQL and MySQL.Async and MySQL.Async.insert) then
            return
        end
        MySQL.Async.insert(query, params, cb or function() end)
        return
    end

    exports.oxmysql:insert(query, params, cb or function() end)
end
