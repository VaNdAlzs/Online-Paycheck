Citizen.CreateThread(function()
    while true do
        Wait(5000) -- Verifica a cada 5 segundos para melhor resposta

        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            -- Teclas de movimento: W(32), S(33), A(34), D(35)
            if IsControlPressed(0, 32) or IsControlPressed(0, 33) or IsControlPressed(0, 34) or IsControlPressed(0, 35) then
                TriggerServerEvent("online_paycheck:atualizarMovimento")
            end
        end
    end
end)
