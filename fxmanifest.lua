fx_version 'cerulean'
game 'gta5'

name 'meteo-crimesservice-demo'
description 'Reference / template crime service for the meteo-crimetablet Services app'
author 'Meteo Studios'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/rename.lua',
    'shared/config.lua',
    'shared/achievements.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/cl_main.lua',
}

server_scripts {
    'server/sv_main.lua',
}

lua54 'yes'
