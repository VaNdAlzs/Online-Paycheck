fx_version 'cerulean'
game 'gta5'

description 'Pagamento proporcional ao tempo online (com ESX, BD, anti-AFK e okokNotify)'
author 'VaNdAl'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@es_extended/imports.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}
