fx_version 'adamant'
game 'gta5'

description 'Flake Tebex Redeem System'
version '2.0.0'
author 'flake'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'framework.lua',
    'server.lua',
}

client_scripts {
    'client.lua',
}

escrow_ignore {
    'config.lua',
    'framework.lua',
}
