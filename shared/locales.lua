LiLocales = LiLocales or {}
Locales = Locales or {}

local function configuredLang()
    local lang = tostring((Config and Config.Lang) or 'de'):lower()
    if lang == '' then
        return 'de'
    end
    return lang
end

local function firstAvailableLang()
    if Locales['de'] then
        return 'de'
    end
    if Locales['en'] then
        return 'en'
    end
    for key in pairs(Locales) do
        return key
    end
    return nil
end

function LiLocales.GetLanguage()
    return configuredLang()
end

function LiLocales.ResolveTable(lang)
    local requested = tostring(lang or configuredLang()):lower()
    return Locales[requested] or Locales[firstAvailableLang()] or {}
end

local function resolveKey(localeTable, key)
    local current = localeTable
    for part in tostring(key):gmatch('[^%.]+') do
        if type(current) ~= 'table' then
            return nil
        end
        current = current[part]
    end
    return current
end

function LiLocales.Translate(key, ...)
    local lang = configuredLang()
    local localeTable = LiLocales.ResolveTable(lang)
    local template = resolveKey(localeTable, key)

    if type(template) ~= 'string' then
        local fallback = resolveKey(LiLocales.ResolveTable('en'), key)
        template = type(fallback) == 'string' and fallback or key
    end

    if select('#', ...) > 0 then
        local ok, text = pcall(string.format, template, ...)
        if ok then
            return text
        end
    end

    return template
end

function LiLocales.GetUiTable()
    local ui = LiLocales.ResolveTable(configuredLang()).ui
    if type(ui) == 'table' then
        return ui
    end
    local fallbackUi = LiLocales.ResolveTable('en').ui
    return type(fallbackUi) == 'table' and fallbackUi or {}
end

_L = LiLocales.Translate
