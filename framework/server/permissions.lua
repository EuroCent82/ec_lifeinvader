LiBridgeServerPermissions = LiBridgeServerPermissions or {}

local function permissionCfg(key)
    local cfg = Config.Permissions or {}
    return cfg[key]
end

local function hasAce(source, ace)
    if type(ace) ~= 'string' or ace == '' then
        return false
    end
    return IsPlayerAceAllowed(source, ace)
end

local function groupAllowed(source, groups)
    if type(groups) ~= 'table' or #groups == 0 then
        return false
    end

    local fw = LiBridge.Framework()
    local playerGroup

    if fw == 'esx' then
        playerGroup = LiBridgeServerEsx.GetGroup(source)
    elseif fw == 'qbox' then
        playerGroup = LiBridgeServerQbox.GetGroup(source)
    else
        playerGroup = LiBridgeServerQbcore.GetGroup(source)
    end

    if not playerGroup then
        return false
    end

    playerGroup = string.lower(tostring(playerGroup))
    for i = 1, #groups do
        if playerGroup == string.lower(tostring(groups[i])) then
            return true
        end
    end
    return false
end

local function jobAllowed(source, jobs)
    if type(jobs) ~= 'table' or #jobs == 0 then
        return false
    end

    local fw = LiBridge.Framework()
    local jobName

    if fw == 'esx' then
        local xPlayer = LiBridgeServerEsx.GetPlayer(source)
        jobName = xPlayer and xPlayer.job and xPlayer.job.name
    else
        local player = fw == 'qbox' and LiBridgeServerQbox.GetPlayer(source) or LiBridgeServerQbcore.GetPlayer(source)
        jobName = player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
    end

    if not jobName then
        return false
    end

    jobName = string.lower(tostring(jobName))
    for i = 1, #jobs do
        if jobName == string.lower(tostring(jobs[i])) then
            return true
        end
    end
    return false
end

function LiBridgeServerPermissions.Has(source, key)
    local rule = permissionCfg(key)

    if rule == nil or rule == true then
        return true
    end
    if rule == false then
        return false
    end
    if type(rule) ~= 'table' then
        return true
    end

    if rule.ace and hasAce(source, rule.ace) then
        return true
    end
    if groupAllowed(source, rule.groups) then
        return true
    end
    if jobAllowed(source, rule.jobs) then
        return true
    end

    if rule.default == true then
        return true
    end

    return false
end
