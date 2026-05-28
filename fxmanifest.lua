fx_version 'cerulean'
game 'gta5'

author 'EuroCent'
name 'ec_lifeinvader'
description 'LifeInvader — Werbeanzeigen-System für FiveM'
version '1.1.20'

shared_scripts {
    'config.lua',
    'locales/*.lua',
    'shared/locales.lua',
    'shared/bridge.lua',
}

ui_page 'html/index.html'

files {
    'html/**',
    'sql/*.sql',
}

client_scripts {
    'framework/client/custom.lua',
    'framework/client/ox_target.lua',
    'framework/client/qb_target.lua',
    'framework/client/esx.lua',
    'framework/client/native.lua',
    'framework/client/init.lua',
    'client/nui.lua',
    'client/phone.lua',
    'client/notifications.lua',
    'client/locations.lua',
    'client/blip_test.lua',
    'client/main.lua',
}

-- Bei mysql-async: '@mysql-async/lib/MySQL.lua' vor server_scripts einbinden.
server_scripts {
    'framework/server/mysql.lua',
    'framework/server/database.lua',
    'framework/server/custom.lua',
    'framework/server/esx.lua',
    'framework/server/qbcore.lua',
    'framework/server/qbox.lua',
    'framework/server/finance.lua',
    'framework/server/inventory.lua',
    'framework/server/permissions.lua',
    'framework/server/init.lua',
    'server/ad_slots.lua',
    'server/feeds.lua',
    'server/feeds_actions.lua',
    'server/team_slots.lua',
    'server/account.lua',
    'server/phone.lua',
    'server/nui.lua',
    'server/main.lua',
    'server/world_debug.lua',
    'server/blip_test.lua',
    'server/version_check.lua',
}
