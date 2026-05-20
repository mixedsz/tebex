fx_version 'adamant'
game 'gta5'
description 'Flake Tebex claiming system'

lua54 'yes'

dependencies {
    'ox_lib',
    'oxmysql',
}

-- Load config files first
shared_scripts {
    'config/packages.lua'
}

-- Then load other shared scripts
shared_scripts {
    '@ox_lib/init.lua'
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    './modules/discord_webhook/server.lua',
    './server.lua',
    './modules/**/*.lua'
}

server_exports {
    'LogPackageCreation',
    'LogPackageClaim',
    'LogCodeGeneration',
    'LogCodeRedemption'
}

client_scripts {
    './client.lua',
    './modules/**/*.lua'
}

escrow_ignore {
    'config/packages.lua',
    'framework.lua',
    'discord_webhook_config.json',
    'README.md'
}
