# 📄 Script: Online Paycheck Bonus (FiveM ESX)

Este script recompensa jogadores ativos no servidor com um pagamento automático, que aumenta conforme o tempo online sem estar AFK.

## 🚀 Descrição Geral

* Jogadores recebem um **salário base** e um **bônus extra** proporcional ao tempo online.
* O tempo AFK é descontado do tempo total.
* Os pagamentos são realizados automaticamente a cada X segundos.
* O tempo total ativo do jogador é salvo numa base de dados.
* O tempo é **resetado diariamente às 04:00** para manter o sistema limpo.

## ⚙️ Configurações Principais

```lua
SALARIO_BASE = 1000
BONUS_POR_INTERVALO = 100
INTERVALO_BONUS = 60 -- em segundos
BONUS_MAXIMO = 500
TEMPO_PAGAMENTO = 60 -- em segundos
TEMPO_AFk_LIMITE = 120 -- em segundos
```

---

## 🔧 Funções e Componentes

### `getIdentifier(src)`

Procura o identificador exclusivo do jogador (Steam ou License).

### `esx:playerLoaded`

Evento chamado quando o jogador entra no servidor. Inicializa o  tempo ativo e puxa da base de dados o tempo anterior.

### `playerDropped`

Ao sair, o tempo ativo é salvo na base de dados, reduzindo o tempo AFK.

### `online_paycheck:atualizarMovimento`

Chamado pelo client. Verifica se o jogador está em movimento e, se não estiver, acumula tempo AFK.

### `Thread de pagamento`

A cada `TEMPO_PAGAMENTO`, verifica o tempo ativo e calcula:

* Salário total (base + bônus)
* Adiciona ao banco do jogador (ESX)
* Envia notificação com `okokNotify`
* Atualiza o tempo ativo na base de dados

### `Thread de reset diário`

Todos os dias às 04:00 da manhã, zera o tempo total ativo de todos os jogadores na base de dados.

---

## 📝 Melhorias Futuras se for o caso !

| Item                             | Descrição                                                                 |
| -------------------------------- | ------------------------------------------------------------------------- |
| Detecção de AFK mais precisa     | Monitorar movimento da câmera/mouse e animações, não apenas teclas.       |
| Proteção contra crash exploit    | Registrar tempo parciais com mais frequência ou salvamento intermediário. |
| Comando admin                    | Criar comando `/resettempo` ou `/checktempo` para gestão e suporte.       |
| Logs em ficheiro                 | Armazenar logs locais com `SaveResourceFile` para auditoria.              |
| Otimização para muitos jogadores | Em servidores grandes, dividir o processamento em blocos para evitar lag. |

---

## 📂 SQL Necessária

```sql
CREATE TABLE IF NOT EXISTS player_online_time (
    identifier VARCHAR(50) PRIMARY KEY,
    total_active_seconds INT DEFAULT 0
);
```

> ✉️ Nota: O script é compatível com ESX e usa MySQL async/oxmysql.

---

**Autor**: VaNdAl
