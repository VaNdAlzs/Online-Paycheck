local ESX = exports["es_extended"]:getSharedObject()

local jogadores = {}
local ultimoUpdate = {}
local pagamentoRodando = false

-- Configurações
local SALARIO_BASE           = 1000
local BONUS_POR_INTERVALO    = 100
local INTERVALO_BONUS        = 60        -- 1 minuto
local BONUS_MAXIMO           = 500
local TEMPO_PAGAMENTO        = 60        -- 1 minuto
local TEMPO_AFk_LIMITE       = 120       -- 2 minutos

-- Obter Steam ou License
local function getIdentifier(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1,7) == "license" or id:sub(1,5) == "steam" then
            return id
        end
    end
    return ("unknown_%s"):format(src)
end

-- Quando o jogador entra (ESX)
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(source)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local id = getIdentifier(src)
    local now = os.time()

    MySQL.single("SELECT total_active_seconds FROM player_online_time WHERE identifier = ?", { id }, function(row)
        if not row then
            MySQL.insert.await("INSERT INTO player_online_time (identifier) VALUES (?)", { id })
            row = { total_active_seconds = 0 }
        end

        jogadores[src] = {
            identifier = id,
            tempoEntrada = now,
            ultimoMovimento = now,
            tempoAFK = 0,
            acumuladoDB = row.total_active_seconds
        }
    end)
end)

-- Quando o jogador sai
AddEventHandler("playerDropped", function()
    local src = source
    local dados = jogadores[src]
    if not dados then return end

    local agora = os.time()
    local tempoSessao = agora - dados.tempoEntrada - dados.tempoAFK
    local novoTotal = dados.acumuladoDB + tempoSessao

    MySQL.update.await("UPDATE player_online_time SET total_active_seconds = ? WHERE identifier = ?", {
        novoTotal, dados.identifier
    })

    jogadores[src] = nil
    ultimoUpdate[src] = nil
end)

-- Atualizar movimento (evitar AFK)
RegisterNetEvent("online_paycheck:atualizarMovimento")
AddEventHandler("online_paycheck:atualizarMovimento", function()
    local src = source
    local dados = jogadores[src]
    if not dados then return end

    local agora = os.time()
    if ultimoUpdate[src] and (agora - ultimoUpdate[src] < 5) then
        return
    end
    ultimoUpdate[src] = agora

    local parado = agora - dados.ultimoMovimento
    if parado > TEMPO_AFk_LIMITE then
        dados.tempoAFK = dados.tempoAFK + parado
    end

    dados.ultimoMovimento = agora
end)

-- Thread de pagamento automático
CreateThread(function()
    if pagamentoRodando then return end
    pagamentoRodando = true

    while true do
        Wait(TEMPO_PAGAMENTO * 1000)

        for src, p in pairs(jogadores) do
            if GetPlayerPing(src) <= 0 then
                jogadores[src] = nil
                ultimoUpdate[src] = nil
            else
                local agora = os.time()
                local tempoTotal = agora - p.tempoEntrada
                local tempoAtivo = math.max(0, tempoTotal - p.tempoAFK)

                local bonusMultiplicador = math.floor(tempoAtivo / INTERVALO_BONUS)
                local bonusCalculado = math.min(BONUS_MAXIMO, bonusMultiplicador * BONUS_POR_INTERVALO)
                local valor = SALARIO_BASE + bonusCalculado

                local xPlayer = ESX.GetPlayerFromId(src)
                if xPlayer then
                    xPlayer.addAccountMoney('bank', valor)
                    TriggerClientEvent("okokNotify:Alert", src, "Salário", ("Recebeu $%d no banco pelo tempo ativo."):format(valor), 5000, "success")
                    print(("[SALÁRIO] Jogador %s recebeu $%d (ativo: %ds, AFK: %ds)"):format(src, valor, tempoAtivo, p.tempoAFK))
                end

                -- Atualizar base de dados
                local novoTotal = p.acumuladoDB + tempoAtivo
                MySQL.update("UPDATE player_online_time SET total_active_seconds = ?, last_reset = CURRENT_DATE() WHERE identifier = ?", {
                    novoTotal, p.identifier
                })

                -- Reset da sessão
                p.acumuladoDB = novoTotal
                p.tempoEntrada = agora
                p.ultimoMovimento = agora
                p.tempoAFK = 0
            end
        end
    end
end)

-- Thread para reset diário às 04:00
CreateThread(function()
    while true do
        local hora = tonumber(os.date("%H"))
        local minuto = tonumber(os.date("%M"))

        if hora == 4 and minuto == 0 then
            MySQL.update.await("UPDATE player_online_time SET total_active_seconds = 0, last_reset = CURRENT_DATE()")
            print("[INFO] Tempo online de todos os jogadores foi resetado.")
            Wait(60000) -- Espera 1 minuto para evitar execução múltipla
        else
            Wait(30000) -- Verifica a cada 30s
        end
    end
end)
