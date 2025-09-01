-- ============================================================
--  client.lua (HUD principal)
-- ============================================================

-- ======================
-- 1. VARIABLES GLOBALES
-- ======================
local vehicleHUDActive, playerHUDActive = false, false
local hunger, thirst, stress = 100, 100, 0
local seatbeltOn, showSeatbelt = false, false
local speedMultiplier = Config.UseMPH and 2.23694 or 3.6

-- Vehículo
local vehicle, numgears, topspeedGTA, topspeedms, acc, hash = nil, nil, nil, nil, nil, nil
local selectedgear, hbrake, currspeedlimit = 0, nil, nil
local manualon, incar, ready, realistic = true, false, false, false
local nos, nitroLevel, nitroActive = 0, 0, 0

-- HUD y pantallas especiales
local showAltitude = false
local inMulticharacter, inSpawnSelector = false, false

-- ======================
-- 2. GESTIÓN DEL HUD
-- ======================

local function hideAllHUD()
    vehicleHUDActive, playerHUDActive = false, false
    DisplayRadar(false)
    SendNUIMessage({ action = 'hideVehicleHUD' })
    SendNUIMessage({ action = 'hidePlayerHUD' })
end

local function shouldShowHUD()
    return not inMulticharacter and not inSpawnSelector and LocalPlayer.state.isLoggedIn
end

local function startHUD()
    if not shouldShowHUD() then return end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped) then
        DisplayRadar(false)
    else
        DisplayRadar(true)
        SendNUIMessage({ action = 'showVehicleHUD' })
    end

    TriggerEvent('hud:client:LoadMap')
    SendNUIMessage({ action = 'showPlayerHUD' })
    playerHUDActive = true
    loadPlayerNeeds()
end

-- ======================
-- 3. FUNCIONES UTILITARIAS
-- ======================

local lastCrossroadUpdate, lastCrossroadCheck = 0, {}

local function getCrossroads(vehicle)
    local updateTick = GetGameTimer()
    if updateTick - lastCrossroadUpdate > 1500 then
        local pos = GetEntityCoords(vehicle)
        local street1, street2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
        lastCrossroadUpdate = updateTick
        lastCrossroadCheck = {
            GetStreetNameFromHashKey(street1),
            GetStreetNameFromHashKey(street2)
        }
    end
    return lastCrossroadCheck
end

local function GetDirectionText(heading)
    if ((heading >= 0 and heading < 45) or (heading >= 315 and heading < 360)) then
        return "N"
    elseif (heading >= 45 and heading < 135) then
        return "W"
    elseif (heading >= 135 and heading < 225) then
        return "S"
    elseif (heading >= 225 and heading < 315) then
        return "E"
    end
end

-- ======================
-- 4. CICLO PRINCIPAL HUD
-- ======================

CreateThread(function()
    while true do
        local stamina, ped = 0, PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if not shouldShowHUD() then
            if vehicleHUDActive or playerHUDActive then hideAllHUD() end
            Wait(1000) goto continue
        end

        if not IsPauseMenuActive() then
            if not playerHUDActive then SendNUIMessage({ action = 'showPlayerHUD' }) end

            local playerId = PlayerId()
            if not IsEntityInWater(ped) then
                stamina = (100 - GetPlayerSprintStaminaRemaining(playerId))
            else
                stamina = (GetPlayerUnderwaterTimeRemaining(playerId) * 10)
            end

            -- HUD del jugador
            SendNUIMessage({
                action = 'updatePlayerHUD',
                health = (GetEntityHealth(ped) - 100),
                armor = GetPedArmour(ped),
                thirst = thirst,
                hunger = hunger,
                stamina = stamina,
                stress = stress,
                voice = LocalPlayer.state['proximity'].distance,
                talking = NetworkIsPlayerTalking(PlayerId()),
            })

            -- HUD del vehículo
            if IsPedInAnyHeli(ped) or IsPedInAnyPlane(ped) then
                if not vehicleHUDActive then
                    vehicleHUDActive = true
                    DisplayRadar(true)
                    TriggerEvent('hud:client:LoadMap')
                    SendNUIMessage({ action = 'showVehicleHUD' })
                end
                local crossroads = getCrossroads(vehicle)
                SendNUIMessage({
                    action = 'updateVehicleHUD',
                    speed = math.ceil(GetEntitySpeed(vehicle) * Config.speedMultiplier),
                    fuel = math.ceil(GetVehicleFuelLevel(vehicle)),
                    gear = getinfo(getSelectedGear()),
                    street1 = crossroads[1],
                    street2 = crossroads[2],
                    direction = GetDirectionText(GetEntityHeading(vehicle)),
                    seatbeltOn = seatbeltOn,
                    showSeatbelt = showSeatbelt,
                    nos = nitroLevel,
                    altitude = math.ceil(GetEntityCoords(ped).z * 0.5),
                    altitudetexto = "ALT"
                })
            elseif IsPedInAnyVehicle(ped) then
                if not vehicleHUDActive then
                    vehicleHUDActive = true
                    DisplayRadar(true)
                    TriggerEvent('hud:client:LoadMap')
                    SendNUIMessage({ action = 'showVehicleHUD' })
                end
                local crossroads = getCrossroads(vehicle)
                SendNUIMessage({
                    action = 'updateVehicleHUD',
                    speed = math.ceil(GetEntitySpeed(vehicle) * Config.speedMultiplier),
                    fuel = math.ceil(GetVehicleFuelLevel(vehicle)),
                    gear = GetVehicleCurrentGear(vehicle), -- ← cambio aquí
                    street1 = crossroads[1],
                    street2 = crossroads[2],
                    direction = GetDirectionText(GetEntityHeading(vehicle)),
                    seatbeltOn = seatbeltOn,
                    showSeatbelt = showSeatbelt,
                    nos = nitroLevel,
                    altitude = math.ceil(GetEntityCoords(ped).z * 0.5),
                    altitudetexto = "ALT"
                })

            elseif vehicleHUDActive then
                vehicleHUDActive = false
                DisplayRadar(false)
                SendNUIMessage({ action = 'hideVehicleHUD' })
            end
        else
            hideAllHUD()
        end

        SetBigmapActive(false, false)
        SetRadarZoom(1000)

        ::continue::
        Wait(Config.updateDelay)
    end
end)

-- ======================
-- 5. NECESIDADES
-- ======================

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    thirst, hunger = newThirst, newHunger
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    stress = newStress
end)

-- ======================
-- 6. EFECTOS DE ESTRÉS
-- ======================

-- 🔹 Función para efectos visuales
local function DoScreenEffect(type, intensity, duration)
    if type == "blur" then
        TriggerScreenblurFadeIn(0)
        Wait(intensity)
        TriggerScreenblurFadeOut(duration)
    elseif type == "shake" then
        ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", intensity)
        Wait(duration)
        StopGameplayCamShaking(true)
    end
end

-- 🔹 Ganar estrés por disparos
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 4) and IsPedShooting(ped) then
            local weapon = GetSelectedPedWeapon(ped)
            if not Config.WhitelistedWeaponStress[weapon] and not Config.DisableStress then
                if math.random() < (Config.StressChance or 0.1) then
                    TriggerServerEvent('hud:server:GainStress', 1)
                end
            end
            Wait(250) -- evitar spam
        else
            Wait(50)
        end
    end
end)

-- 🔹 Ganar estrés por alta velocidad
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if not Config.DisableStress and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            local class = tostring(GetVehicleClass(veh))
            local model = GetEntityModel(veh)

            if Config.VehClassStress[class] and not Config.WhitelistedVehicles[model] then
                local speed = GetEntitySpeed(veh) * (Config.UseMPH and 2.23694 or 3.6)
                local limit = seatbeltOn and (Config.MinimumSpeed or 130) or (Config.MinimumSpeedUnbuckled or 100)
                if speed >= limit then
                    TriggerServerEvent('hud:server:GainStress', 1)
                end
            end
            Wait(5000) -- chequeo cada 5s
        else
            Wait(1000)
        end
    end
end)

-- 🔹 Efectos por intensidad de estrés (blur)
CreateThread(function()
    while true do
        Wait(1000)
        if stress >= Config.MinimumStress and not IsPauseMenuActive() then
            for _, v in pairs(Config.Intensity['blur']) do
                if stress >= v.min and stress < v.max then
                    DoScreenEffect("blur", v.intensity, 2000)
                end
            end
        end
    end
end)

-- 🔹 Efectos por intervalos de estrés (shake)
CreateThread(function()
    while true do
        Wait(1000)
        if stress >= Config.MinimumStress and not IsPauseMenuActive() then
            for _, v in pairs(Config.EffectInterval) do
                if stress >= v.min and stress < v.max then
                    Wait(v.timeout)
                    if stress >= v.min and stress < v.max then
                        DoScreenEffect("shake", 0.2, 2000)
                    end
                end
            end
        else
            Wait(5000)
        end
    end
end)

-- 🔹 Actualizar la variable stress cuando el servidor lo envía
RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    stress = newStress
    -- debug opcional:
    -- print("Nuevo stress recibido:", stress)
end)


-- ======================
-- 7. CINTURÓN DE SEGURIDAD
-- ======================

local seatbeltEjectSpeed = 45.0       -- velocidad mínima (m/s) para salir disparado
local seatbeltEjectAccel = 100.0      -- aceleración mínima para salir disparado
local wasInCar = false
local speedBuffer, velBuffer = {}, {}

-- 🔹 Activar/desactivar el cinturón manualmente
RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end

    seatbeltOn = not seatbeltOn

    if seatbeltOn then
        QBCore.Functions.Notify("Cinturón abrochado", "success")
    else
        QBCore.Functions.Notify("Cinturón desabrochado", "error")
    end

    -- 🔹 Enviar a NUI el estado actualizado
    SendNUIMessage({
        action = "updateSeatbelt",
        seatbeltOn = seatbeltOn
    })
end)

-- 🔹 Lógica de accidentes y eyección si no hay cinturón
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local car = GetVehiclePedIsIn(ped, false)

        if car ~= 0 and (wasInCar or IsCarVehicle(car)) then
            wasInCar = true
            local speed = GetEntitySpeed(car)
            local velocity = GetEntityVelocity(car)

            -- guardamos histórico
            speedBuffer[2] = speedBuffer[1]
            speedBuffer[1] = speed

            velBuffer[2] = velBuffer[1]
            velBuffer[1] = velocity

            if speedBuffer[2] ~= nil
               and not seatbeltOn
               and GetEntitySpeedVector(car, true).y > 1.0
               and speedBuffer[1] > (seatbeltEjectSpeed / 2.237) then

                local acc = (speedBuffer[2] - speedBuffer[1]) / GetFrameTime()
                if acc > (seatbeltEjectAccel * 9.81) then
                    -- eyección del jugador
                    local coords = GetEntityCoords(ped)
                    local forward = GetEntityForwardVector(ped)
                    SetEntityCoords(ped, coords.x + forward.x, coords.y + forward.y, coords.z + 0.5, true, true, true)
                    SetEntityVelocity(ped, velBuffer[2].x, velBuffer[2].y, velBuffer[2].z)
                    SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
                end
            end

            -- bloqueamos salir del coche si cinturón está puesto
            if seatbeltOn then
                DisableControlAction(0, 75, true)  -- E
                DisableControlAction(27, 75, true)
            end
        else
            if wasInCar then
                wasInCar = false
                seatbeltOn = false
                SendNUIMessage({ action = "updateSeatbelt", seatbeltOn = false })
            end
        end
        Wait(0)
    end
end)

-- 🔹 Detectar si es coche terrestre (evitamos bici/moto/heli/etc.)
function IsCarVehicle(vehicle)
    local vc = GetVehicleClass(vehicle)
    return (vc >= 0 and vc <= 7) or vc == 9 or vc == 12 or vc == 17 or vc == 18 or vc == 20
end


-- ======================
-- 8. EVENTOS CORE
-- ======================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500) startHUD()
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    Wait(500)
    inMulticharacter, inSpawnSelector = false, false
    startHUD()
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    inMulticharacter = true
    hideAllHUD()
end)

RegisterNetEvent('qb-multicharacter:client:closeNUI', function()
    inMulticharacter = false
end)

RegisterNetEvent('qb-spawn:client:openUI', function()
    inSpawnSelector = true
    hideAllHUD()
end)

RegisterNetEvent('qb-spawn:client:closeUI', function()
    inSpawnSelector = false
end)

-- ======================
-- 9. PERSONALIZACIÓN DE MINIMAPA
-- ======================

RegisterNetEvent("hud:client:LoadMap", function()
    Wait(100)

    -- Constantes base
    local DEFAULT_ASPECT = 1920.0 / 1080.0

    -- Resolución y aspect ratio actuales
    local resX, resY = GetActiveScreenResolution()
    local aspect = resX / resY

    -- Safezone (GTA lo expresa 0.90–1.00). Creamos un pequeño offset.
    local safe = GetSafeZoneSize()
    local safePadding = (1.0 - safe) -- 0.0 cuando safe=1.0
    local safeX = safePadding * 0.03   -- ajusta fino si lo ves necesario
    local safeY = safePadding * 0.03

    -- Compensación para ultrawide: si aspect > 16:9, desplazamos a la derecha
    local minimapOffset = 0.0
    if aspect > DEFAULT_ASPECT then
        -- factor suave; súbelo/bájalo si usas 21:9 o 32:9 muy extremos
        minimapOffset = (aspect - DEFAULT_ASPECT) * 0.05
    end

    -- Carga del diccionario de textura cuadrada
    RequestStreamedTextureDict("squaremap", false)
    local tries = 0
    while not HasStreamedTextureDictLoaded("squaremap") and tries < 50 do
        Wait(10)
        tries = tries + 1
    end

    -- Minimapa cuadrado
    SetMinimapClipType(0)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
    AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "squaremap", "radarmasksm")

    -- Anchors y tamaño (valores base, fáciles de tunear)
    local baseX = 0.020 + minimapOffset + safeX
    local baseY = -0.030 - safeY

    -- width/height del componente principal
    local w, h = 0.150, 0.160

    -- 🎯 Posiciones/tamaños coherentes entre componentes
    SetMinimapComponentPosition("minimap",       "L", "B", baseX,           baseY,        w,      h)
    SetMinimapComponentPosition("minimap_mask",  "L", "B", baseX,           baseY + 0.070, 0.535, 0.360)
    SetMinimapComponentPosition("minimap_blur",  "L", "B", baseX - 0.030,   baseY + 0.060, 0.260, 0.315)

    -- Oculta el norte grande y fuerza refresco del minimapa una sola vez
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetRadarBigmapEnabled(true, false)
    Wait(50)
    SetRadarBigmapEnabled(false, false)
end)

-- (Opcional) Limpia cuando se pare el recurso para no dejar el mask reemplazado
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        RemoveReplaceTexture("platform:/textures/graphics", "radarmasksm")
        RemoveReplaceTexture("platform:/textures/graphics", "radarmask1g")
    end
end)




