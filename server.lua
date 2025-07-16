local ESX = exports["es_extended"]:getSharedObject()

local jogadores = {}
local ultimoUpdate = {}
local pagamentoRodando = false

-- Configurações ajustáveis
local SALARIO_BASE = 5000           -- Valor base do salário pago a cada ciclo
local BONUS_POR_INTERVALO = 100     -- Bônus por cada intervalo ativo
local INTERVALO_BONUS = 60          -- Intervalo para bônus em segundos (ex: a cada 60s ativo ganha bônus)
local BONUS_MAXIMO = 500            -- Bônus máximo acumulado por ciclo
local TEMPO_PAGAMENTO = 300         -- Tempo entre pagamentos em segundos (5 minutos)
local TEMPO_AFk_LIMITE = 120        -- Tempo limite para considerar jogador AFK em segundos (2 minutos)

-- Função para obter identifier do jogador (license ou steam)
local function getIdentifier(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 7) == "license" or id:sub(1, 5) == "steam" then
            return id
        end
    end
    return "unknown_" .. tostring(src)
end

-- Evento: jogador carregado no servidor
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(source)
    local src = source
    if type(src) ~= "number" or src <= 0 then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local id = getIdentifier(src)
    local now = os.time()

    Citizen.CreateThread(function()
        local row
        local success, err = pcall(function()
            row = MySQL.single.await("SELECT total_active_seconds FROM player_online_time WHERE identifier = ?", { id })
            if not row then
                MySQL.insert.await("INSERT INTO player_online_time (identifier) VALUES (?)", { id })
                row = { total_active_seconds = 0 }
            end
        end)
        if not success then
            print("[ERROR] Falha ao buscar ou inserir tempo online para", id, err)
            row = { total_active_seconds = 0 }
        end

        jogadores[src] = {
            identifier = id,
            tempoEntrada = now,
            ultimoMovimento = now,
            tempoAFK = 0,
            acumuladoDB = row.total_active_seconds
        }
        print("[INFO] Jogador registrado para pagamento:", src)
    end)
end)

-- Evento: jogador saiu do servidor
AddEventHandler("playerDropped", function()
    local src = source
    if type(src) ~= "number" or src <= 0 then return end

    local dados = jogadores[src]
    if not dados then return end

    local agora = os.time()
    local tempoSessao = agora - dados.tempoEntrada - dados.tempoAFK
    local novoTotal = dados.acumuladoDB + tempoSessao

    local success, err = pcall(function()
        MySQL.update.await("UPDATE player_online_time SET total_active_seconds = ? WHERE identifier = ?", {
            novoTotal, dados.identifier
        })
    end)
    if not success then
        print("[ERROR] Falha ao salvar tempo online no playerDropped para", dados.identifier, err)
    end

    jogadores[src] = nil
    ultimoUpdate[src] = nil
    print("[INFO] Jogador removido e tempo salvo:", src)
end)

-- Evento: atualiza movimento (chamado pelo client para detectar atividade)
RegisterNetEvent("online_paycheck:atualizarMovimento")
AddEventHandler("online_paycheck:atualizarMovimento", function()
    local src = source
    if type(src) ~= "number" or src <= 0 then return end

    local dados = jogadores[src]
    if not dados then return end

    local agora = os.time()

    -- Anti-spam: só atualiza se passou pelo menos 5 segundos desde último update
    if ultimoUpdate[src] and (agora - ultimoUpdate[src] < 5) then return end
    ultimoUpdate[src] = agora

    local parado = agora - dados.ultimoMovimento
    if parado > TEMPO_AFk_LIMITE then
        dados.tempoAFK = dados.tempoAFK + TEMPO_AFk_LIMITE
    end

    dados.ultimoMovimento = agora
end)

-- Thread para monitorar tempo AFK automaticamente e somar tempo parado
CreateThread(function()
    while true do
        Wait(5000) -- a cada 5 segundos
        local agora = os.time()

        for src, dados in pairs(jogadores) do
            if dados.ultimoMovimento then
                local parado = agora - dados.ultimoMovimento
                if parado > TEMPO_AFk_LIMITE then
                    dados.tempoAFK = dados.tempoAFK + 5
                end
            end
        end
    end
end)

-- Thread para salvar tempo acumulado periodicamente (a cada 60s)
CreateThread(function()
    while true do
        Wait(60000) -- a cada 1 minuto

        for src, dados in pairs(jogadores) do
            local agora = os.time()
            local tempoSessao = agora - dados.tempoEntrada - dados.tempoAFK
            if tempoSessao > 0 then
                local novoTotal = dados.acumuladoDB + tempoSessao
                local success, err = pcall(function()
                    MySQL.update.await("UPDATE player_online_time SET total_active_seconds = ? WHERE identifier = ?", {
                        novoTotal, dados.identifier
                    })
                end)
                if success then
                    dados.acumuladoDB = novoTotal
                    dados.tempoEntrada = agora
                    dados.tempoAFK = 0
                else
                    print("[ERROR] Falha ao salvar tempo acumulado periodicamente para", dados.identifier, err)
                end
            end
        end
    end
end)

-- Thread que realiza o pagamento automático proporcional ao tempo online ativo em lotes para evitar travamentos
CreateThread(function()
    if pagamentoRodando then return end
    pagamentoRodando = true

    local batchSize = 10 -- quantidade de jogadores processados por ciclo
    while true do
        Wait(TEMPO_PAGAMENTO * 1000) -- espera o intervalo configurado

        local jogadoresArray = {}
        for k in pairs(jogadores) do
            table.insert(jogadoresArray, k)
        end

        for i = 1, #jogadoresArray, batchSize do
            for j = i, math.min(i + batchSize - 1, #jogadoresArray) do
                local src = jogadoresArray[j]
                local p = jogadores[src]
                if not p then
                    jogadores[src] = nil
                    ultimoUpdate[src] = nil
                else
                    local xPlayer = ESX.GetPlayerFromId(src)
                    if not xPlayer then
                        jogadores[src] = nil
                        ultimoUpdate[src] = nil
                        print("[INFO] Jogador removido por desconexão:", src)
                    else
                        local agora = os.time()
                        local tempoTotal = agora - p.tempoEntrada
                        local tempoAtivo = math.max(0, tempoTotal - p.tempoAFK)

                        if tempoAtivo > 0 then
                            local bonusMultiplicador = math.floor(tempoAtivo / INTERVALO_BONUS)
                            local bonusCalculado = math.min(BONUS_MAXIMO, bonusMultiplicador * BONUS_POR_INTERVALO)
                            local valor = SALARIO_BASE + bonusCalculado

                            xPlayer.addAccountMoney('bank', valor)
                            TriggerClientEvent("okokNotify:Alert", src, "Salário", ("Recebeu $%d no banco pelo tempo ativo."):format(valor), 5000, "success")
                            print(("[SALÁRIO] %s recebeu $%d | Ativo: %ds | AFK: %ds"):format(src, valor, tempoAtivo, p.tempoAFK))

                            local novoTotal = p.acumuladoDB + tempoAtivo
                            local success, err = pcall(function()
                                MySQL.update.await("UPDATE player_online_time SET total_active_seconds = ?, last_reset = CURRENT_DATE() WHERE identifier = ?", {
                                    novoTotal, p.identifier
                                })
                            end)
                            if success then
                                p.acumuladoDB = novoTotal
                            else
                                print("[ERROR] Falha ao atualizar tempo acumulado no pagamento para", p.identifier, err)
                            end
                        else
                            print("[INFO] Jogador", src, "não recebeu salário (tempo ativo 0).")
                        end

                        -- Reseta contador da sessão após pagamento
                        p.tempoEntrada = agora
                        p.ultimoMovimento = agora
                        p.tempoAFK = 0
                    end
                end
            end
            Wait(100) -- Pausa para evitar travamentos caso muitos jogadores
        end
    end
end)

-- Evento para resetar a tabela diariamente (pode ser chamado por um cron externo ou manualmente)
RegisterNetEvent("online_paycheck:resetarTabela")
AddEventHandler("online_paycheck:resetarTabela", function()
    local src = source
    if type(src) ~= "number" or src <= 0 then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.getGroup or xPlayer.getGroup() ~= "admin" then
        print("[AVISO] Jogador " .. src .. " tentou resetar tabela sem permissão.")
        return
    end

    local success, err = pcall(function()
        MySQL.update.await("UPDATE player_online_time SET total_active_seconds = 0, last_reset = CURRENT_DATE()")
    end)
    if success then
        print("[INFO] Tabela player_online_time resetada pelo admin " .. src)
    else
        print("[ERROR] Falha ao resetar tabela player_online_time:", err)
    end
end)

