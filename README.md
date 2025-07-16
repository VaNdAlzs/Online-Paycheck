# Online Paycheck Script (FiveM / ESX)

## Descrição

Este script implementa um sistema de pagamento automático baseado no tempo de atividade online dos jogadores em servidores FiveM com framework ESX. O pagamento é proporcional ao tempo em que o jogador está ativo (não AFK), com bônus para tempo contínuo online.

### Funcionalidades principais:

- Registra o tempo ativo de cada jogador usando identificador único (license ou steam).
- Detecta e desconta tempo AFK (sem movimento).
- Realiza pagamentos automáticos periódicos na conta bancária do jogador.
- Bônus por tempo ativo contínuo dentro de intervalos configuráveis.
- Reset diário do tempo acumulado.
- Persistência dos dados no banco de dados MySQL para manter histórico entre sessões.
- Comunicação eficiente entre client e server para atualização de movimento.
- Proteções básicas contra spam de eventos e jogadores tentando "farmar" parados.

---

## Configurações ajustáveis

| Variável           | Descrição                                | Valor padrão       |
|--------------------|------------------------------------------|--------------------|
| `SALARIO_BASE`     | Valor base do salário a cada pagamento  | 5000               |
| `BONUS_POR_INTERVALO` | Bônus ganho a cada intervalo ativo      | 100                |
| `INTERVALO_BONUS`  | Intervalo de tempo em segundos para bônus | 60                 |
| `BONUS_MAXIMO`     | Valor máximo do bônus por ciclo         | 500                |
| `TEMPO_PAGAMENTO`  | Intervalo entre pagamentos em segundos  | 300 (5 minutos)    |
| `TEMPO_AFk_LIMITE` | Tempo limite para considerar jogador AFK | 120 (2 minutos)    |

---

## Melhorias implementadas

1. **Anti-spam e controle de frequência**  
   - No client e server, evento de atualização de movimento é limitado a no mínimo 5 segundos entre chamadas para evitar flood.

2. **Persistência robusta e inicialização assíncrona**  
   - Busca e cria registros no banco se necessário ao entrar no servidor, usando async/await para garantir sincronização correta.

3. **Detecção aprimorada de AFK**  
   - Thread dedicada verifica periodicamente se o jogador está parado e soma o tempo AFK, descontando do pagamento.

4. **Atualização segura do banco ao desconectar e pagar**  
   - Atualiza o tempo ativo no banco ao desconectar e a cada ciclo de pagamento, garantindo integridade dos dados.

5. **Resets diários automáticos**  
   - Reset do tempo acumulado às 4h da manhã para manter dados atualizados e evitar acumulação infinita.

6. **Melhoria na lógica de pagamento**  
   - Cálculo de bônus baseado em tempo ativo real com teto máximo, adicionando transparência e equilíbrio.

7. **Client otimizado**  
   - Client detecta movimentação do jogador a cada 5 segundos e envia evento somente quando detecta teclas de movimento pressionadas, sincronizando perfeitamente com o servidor.

---

## Sugestões para futuros updates

- **Validação mais robusta no servidor**  
  Validar padrões de movimento para evitar que jogadores burlem o sistema enviando eventos manualmente.

- **Pagamento máximo diário**  
  Definir um teto máximo de salário pago por dia para evitar abusos em longas sessões.

- **Salvamento periódico no banco**  
  Salvar o tempo ativo em intervalos regulares para minimizar perda em quedas inesperadas.

- **Batch update no banco**  
  Fazer atualizações agrupadas para melhorar desempenho em servidores com muitos jogadores.

- **Melhoria na identificação do jogador**  
  Suporte a múltiplos identificadores e verificação anti-fraude para evitar spoofing.

- **Interface administrativa**  
  Comandos para verificar tempo online, saldo acumulado e forçar resets.

- **Eventos customizados e logs**  
  Logs detalhados para auditoria, detecção de anomalias e suporte a moderação.

---

## Considerações finais

Este script oferece uma base sólida para sistemas de pagamento baseados em tempo online ativo em servidores ESX, com bom equilíbrio entre desempenho, segurança e usabilidade. Pode ser ampliado e adaptado conforme a necessidade do servidor e a complexidade desejada.

---

## Instalação

1. Coloque os arquivos do script em sua pasta `resources`.
2. Adicione `start online_paycheck` no seu `server.cfg`.
3. Configure as tabelas necessárias no banco MySQL:
```sql
CREATE TABLE IF NOT EXISTS player_online_time (
    identifier VARCHAR(50) PRIMARY KEY,
    total_active_seconds BIGINT DEFAULT 0,
    last_reset DATE DEFAULT NULL
);


**Autor**: VaNdAl
