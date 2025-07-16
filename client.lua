local lastUpdate = 0
local COOLDOWN = 5 -- segundos

Citizen.CreateThread(function()
    while true do
        Wait(500) -- verifica a cada 0.5s para boa responsividade

        local ped = PlayerPedId()
        local agora = GetGameTimer() / 1000 -- tempo em segundos

        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            -- Teclas de movimento: W(32), S(33), A(34), D(35)
            if IsControlPressed(0, 32) or IsControlPressed(0, 33) or IsControlPressed(0, 34) or IsControlPressed(0, 35) then
                if (agora - lastUpdate) >= COOLDOWN then
                    TriggerServerEvent("online_paycheck:atualizarMovimento")
                    lastUpdate = agora
                end
            end
        end
    end
end)
