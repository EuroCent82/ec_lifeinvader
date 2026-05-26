--[[ GitHub-Releases-Vergleich — bei onResourceStart. ]]

EcLifeInvader = EcLifeInvader or {}

local DEFAULT_REPO = 'EuroCent82/ec_lifeinvader'
local PREFIX = '^3[ec_lifeinvader]^0'

local function versionCheckCfg()
    local c = rawget(Config, 'VersionCheck')
    if type(c) == 'table' then
        return c
    end
    return {
        enabled = true,
        repository = DEFAULT_REPO,
        delayMs = 1500,
        printWhenUpToDate = true,
        logErrors = true,
    }
end

local function normalizeVersion(raw)
    if type(raw) ~= 'string' or raw == '' then
        return nil
    end
    return raw:gsub('^v', ''):match('(%d+%.%d+%.%d+)')
end

local function semverParts(v)
    local maj, min, pat = (v or ''):match('^(%d+)%.(%d+)%.(%d+)$')
    if not maj then
        return nil
    end
    return tonumber(maj), tonumber(min), tonumber(pat)
end

local function isOlderSemver(current, latest)
    local ca, cb, cc = semverParts(current)
    local la, lb, lc = semverParts(latest)
    if not ca or not la then
        return false
    end
    local cv = { ca, cb, cc }
    local lv = { la, lb, lc }
    for i = 1, 3 do
        if cv[i] ~= lv[i] then
            return cv[i] < lv[i]
        end
    end
    return false
end

local function printVersionBanner(current, latest, url, upToDate)
    print('')
    if upToDate then
        print(('%s Versionscheck: ^2Aktuell %s^0 (neueste Version).'):format(PREFIX, current))
    else
        print(('%s Versionscheck: ^1Aktuell %s^0 | ^2Neuer %s^0'):format(PREFIX, current, latest))
        if url and url ~= '' then
            print(('%s %s^0'):format(PREFIX, url))
        end
    end
    print('')
end

local function fetchLatestRelease(cfg, current)
    local repo = type(cfg.repository) == 'string' and cfg.repository:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if repo == '' then
        repo = DEFAULT_REPO
    end

    local headers = {
        ['User-Agent'] = ('ec_lifeinvader/%s (FiveM version-check)'):format(current),
        ['Accept'] = 'application/vnd.github+json',
    }

    PerformHttpRequest(
        ('https://api.github.com/repos/%s/releases/latest'):format(repo),
        function(status, body)
            if status ~= 200 or type(body) ~= 'string' or body == '' then
                if cfg.logErrors ~= false or Config.Debug then
                    print(('%s Versionscheck: GitHub nicht erreichbar (HTTP %s).^0'):format(PREFIX, tostring(status)))
                end
                return
            end

            local ok, data = pcall(json.decode, body)
            if not ok or type(data) ~= 'table' then
                if cfg.logErrors ~= false or Config.Debug then
                    print(('%s Versionscheck: Antwort von GitHub ungültig.^0'):format(PREFIX))
                end
                return
            end
            if data.prerelease then
                return
            end

            local latest = normalizeVersion(data.tag_name or data.name or '')
            if not latest then
                if cfg.logErrors ~= false or Config.Debug then
                    print(('%s Versionscheck: Release-Tag nicht lesbar.^0'):format(PREFIX))
                end
                return
            end

            local url = data.html_url or ('https://github.com/%s/releases/latest'):format(repo)

            if isOlderSemver(current, latest) then
                printVersionBanner(current, latest, url, false)
            elseif cfg.printWhenUpToDate then
                printVersionBanner(current, latest, url, true)
            end
        end,
        'GET',
        '',
        headers
    )
end

function EcLifeInvader.RunVersionCheck()
    local cfg = versionCheckCfg()
    if cfg.enabled == false then
        return
    end

    local resource = GetCurrentResourceName()
    local current = normalizeVersion(GetResourceMetadata(resource, 'version', 0))
    if not current then
        print('^1[ec_lifeinvader]^0 Versionscheck: kein SemVer in fxmanifest `version`.^0')
        return
    end

    local delay = tonumber(cfg.delayMs) or 1500
    if delay < 0 then
        delay = 0
    end

    CreateThread(function()
        Wait(delay)
        print(('%s Versionscheck: installiert ^3%s^0 — vergleiche mit GitHub…^0'):format(PREFIX, current))
        fetchLatestRelease(cfg, current)
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    EcLifeInvader.RunVersionCheck()
end)
