fx_version 'cerulean'
game 'gta5'

author 'EuroCent'
name 'ec_lifeinvader'
description 'LifeInvader — Werbeanzeigen-System für FiveM'
version '0.1.0'

shared_scripts {
    'config.lua',
}

ui_page 'html/index.html'

files {
    'html/**',
    'sql/*.sql',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
    'server/version_check.lua',
}
