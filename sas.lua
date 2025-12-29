-- 🛡️ Adonis Bypass (ЗАПУСКАЕТСЯ ПЕРВЫМ)
--[[
    ? Adonis Bypass ?
    - @sb9r | Main Bypass   
    - @volnuk(..)    | Custom Console

    Created for public research, use at own risk.
--]]

-- Custom Console
getgenv().log = function(text, color)
    if not getgenv().lib then
        getgenv().lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/notpoiu/Scripts/main/utils/console/main.lua"))()
    end
    lib.custom_print({
        message = tostring(text),
        color = color or Color3.fromRGB(255, 255, 255)
    })
end

-- Main Bypass
local gc = getgc(true); if logged then log("[i] Reloading bypass..", nil) end; log("[✓] Bypass loaded!", Color3.fromRGB(88, 137, 184))
for i, v in getreg() do
    if typeof(v) == "thread" then
        local src = debug.info(v, 1, "s")
        if src == ".Core.Anti" then
            for i, v in gc do
                if typeof(v) == "table" then
                    local func = rawget(v, "Detected")
                    if typeof(func) == "function" then
                        if isfunctionhooked(func) then restorefunction(func) end
                        hookfunction(func, function(a, b, c)
                            log("[!] Blocked call.", Color3.fromRGB(232, 211, 142)); return task.wait(9e9)
                        end)
                        if isfunctionhooked(func) then getgenv().logged = true end
                    end
                end
            end
        end
    end
end

-- ЖДЕМ 2 СЕКУНДЫ чтобы байпас успел активироваться
task.wait(2)

-- Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharStats = ReplicatedStorage:WaitForChild("CharStats")
local localPlayer = Players.LocalPlayer

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "thw club",
    LoadingTitle = "Loading Interface...",
    LoadingSubtitle = "by thw",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "thw-club",
        FileName = "config"
    },
    KeySystem = false,
    KeySettings = {
        Title = "Key System",
        Subtitle = "Enter key",
        Note = "No method of obtaining the key is provided",
        FileName = "Key",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"Key1", "Key2"}
    }
})

-- Create Tabs
local RageTab = Window:CreateTab("Ragebot")
local ESPTab = Window:CreateTab("ESP")
local MiscTab = Window:CreateTab("Misc")

--==================== Ragebot Variables ====================
local aimbotEnabled = false
local autofireEnabled = false
local keyHeld = false
local fov = 100
local showFOV = false
local fovColor = Color3.new(1,1,1)
local wallCheckEnabled = true
local FriendList = {}

-- Настройки биндов (ПОЛНОСТЬЮ БЕЗ БИНДА ПО УМОЛЧАНИЮ)
local aimlockKey = nil  -- АБСОЛЮТНО НЕТ БИНДА
local aimlockKeyName = "Not Set"
local isRecordingKeybind = false
local lastKeyPressed = nil

-- Добавляем переменные для стабильного aimlock
local currentTarget = nil -- Текущая цель
local targetLocked = false -- Флаг блокировки цели

-- Глобальный RaycastParams для оптимизации
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = true

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 100
local lastMousePos = Vector2.new()
local lastFOV = fov

--==================== UI Elements ====================

-- Rage Tab
local AimlockToggle = RageTab:CreateToggle({
    Name = "Aimlock",
    CurrentValue = false,
    Flag = "AimlockToggle",
    Callback = function(Value)
        aimbotEnabled = Value
        if not Value then
            currentTarget = nil
            targetLocked = false
        end
    end,
})

-- 🔽 СОЗДАЕМ LABEL СРАЗУ ПОСЛЕ СОЗДАНИЯ TAB
local AimlockKeybindLabel = RageTab:CreateLabel("Aimlock Key: Not Set")

-- Кнопка для установки бинда
local SetAimlockKeyButton = RageTab:CreateButton({
    Name = "Set Aimlock Key",
    Callback = function()
        isRecordingKeybind = true
        AimlockKeybindLabel:Set("Press any keyboard key...")
        
        -- Показываем в уведомлении, что нужно нажать клавишу
        Rayfield:Notify({
            Title = "Recording Keybind",
            Content = "Press any keyboard key to set as aimlock key",
            Duration = 3,
            Image = 4483362458,
        })
        
        -- Таймер на случай, если пользователь передумал
        task.delay(5, function()
            if isRecordingKeybind then
                isRecordingKeybind = false
                AimlockKeybindLabel:Set("Aimlock Key: " .. aimlockKeyName)
                
                Rayfield:Notify({
                    Title = "Keybind Recording Cancelled",
                    Content = "Keybind recording timed out",
                    Duration = 2,
                    Image = 4483362458,
                })
            end
        end)
    end,
})

local AutofireToggle = RageTab:CreateToggle({
    Name = "Autofire",
    CurrentValue = false,
    Flag = "AutofireToggle",
    Callback = function(Value)
        autofireEnabled = Value
    end,
})

local WallcheckToggle = RageTab:CreateToggle({
    Name = "Wallcheck",
    CurrentValue = true,
    Flag = "WallcheckToggle",
    Callback = function(Value)
        wallCheckEnabled = Value
    end,
})

local FOVSlider = RageTab:CreateSlider({
    Name = "FOV Aim",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 100,
    Flag = "FOVSlider",
    Callback = function(Value)
        fov = Value
    end,
})

local FOVCircleToggle = RageTab:CreateButton({
    Name = "Toggle FOV Circle",
    Callback = function()
        showFOV = not showFOV
        fovCircle.Visible = showFOV
        Rayfield:Notify({
            Title = "FOV Circle",
            Content = showFOV and "Enabled" or "Disabled",
            Duration = 1,
            Image = 4483362458,
        })
    end,
})

local FOVColorPicker = RageTab:CreateColorPicker({
    Name = "FOV Circle Color",
    Color = Color3.new(1,1,1),
    Flag = "FOVColor",
    Callback = function(Value)
        fovColor = Value
        fovCircle.Color = Value
    end
})

local FriendListLabel = RageTab:CreateLabel("Friend List: " .. table.concat(FriendList, ", "))

local AddFriendInput = RageTab:CreateInput({
    Name = "Add Friend",
    PlaceholderText = "Enter username",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text ~= "" then
            table.insert(FriendList, Text)
            FriendListLabel:Set("Friend List: " .. table.concat(FriendList, ", "))
        end
    end,
})

local ClearFriendsButton = RageTab:CreateButton({
    Name = "Clear Friend List",
    Callback = function()
        FriendList = {}
        FriendListLabel:Set("Friend List: (empty)")
        Rayfield:Notify({
            Title = "Friend List",
            Content = "Friend list cleared",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

--==================== Weapon Prediction ====================
local weaponBulletSpeeds = {
    ["Beretta"] = 1624,
    ["G-17"] = 1850,
    ["UZI"] = 2250,
    ["Mare"] = 2000,
    ["Deagle"] = 2200,
    ["SKS"] = 3750,
    ["M1911"] = 2230,
    ["AKS-74U"] = 3000,
    ["FNP-45"] = 1500,
    ["TEC-9"] = 2100,
}

local function getCurrentWeaponSpeed()
    local char = localPlayer.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return weaponBulletSpeeds[tool.Name] or 1624 end
    end
    return 1624
end

local function isFriend(plr)
    for _, name in pairs(FriendList) do
        if plr.Name == name then return true end
    end
    return false
end

--==================== Downed Check ====================
local function isTargetDowned(targetCharacter)
    local targetName = targetCharacter.Name
    local charStat = CharStats:FindFirstChild(targetName)
    if not charStat then return false end
    local downedValue = charStat:FindFirstChild("Downed")
    if downedValue and downedValue:IsA("BoolValue") then
        return downedValue.Value
    end
    return false
end

--==================== Visibility & Prediction ====================
local function hasSpawnShield(plr)
    return plr.Character and plr.Character:FindFirstChildOfClass("ForceField") ~= nil
end

-- Функция проверки находится ли цель в FOV (без raycast)
local function isTargetInFOV(targetHead)
    if not targetHead then return false end
    
    local mousePos = UIS:GetMouseLocation()
    local pos, onscreen = Camera:WorldToScreenPoint(targetHead.Position)
    
    if not onscreen then return false end
    
    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
    return dist <= fov
end

-- Оптимизированная функция предсказания
local function getPredictedPosition(target)
    local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then return target.Position end
    
    local dir = hrp.Position - Camera.CFrame.Position
    local dist = dir.Magnitude
    local t = dist / getCurrentWeaponSpeed()
    
    return target.Position + hrp.Velocity * t
end

-- ПРОВЕРКА ВИДИМОСТИ ТОЛЬКО КОГДА ЦЕЛЬ В FOV
local function isTargetVisible(targetHead, localChar)
    if not wallCheckEnabled then return true end
    if not targetHead or not localChar then return false end
    
    -- Сначала проверяем FOV (без raycast)
    if not isTargetInFOV(targetHead) then return false end
    
    -- ТОЛЬКО если в FOV - делаем raycast
    local rayOrigin = Camera.CFrame.Position
    local rayDir = targetHead.Position - rayOrigin
    local rayDistance = rayDir.Magnitude
    rayDir = rayDir.Unit
    
    rayParams.FilterDescendantsInstances = {localChar, targetHead.Parent}
    
    local result = workspace:Raycast(rayOrigin, rayDir * rayDistance, rayParams)
    
    if not result then
        return true
    else
        local hit = result.Instance
        
        -- Если попали в цель - видимо
        if hit == targetHead or hit:IsDescendantOf(targetHead) then
            return true
        end
        
        -- Если попали в DFrame - проверяем, что за ним
        if hit.Name == "DFrame" then
            -- Делаем второй raycast от точки после DFrame
            local newOrigin = result.Position + rayDir * 0.1  -- Немного отходим от DFrame
            local remainingDistance = rayDistance - (newOrigin - rayOrigin).Magnitude
            
            if remainingDistance > 0 then
                -- Добавляем DFrame в игнор для второго raycast
                local newBlacklist = {localChar, targetHead.Parent, hit}
                rayParams.FilterDescendantsInstances = newBlacklist
                
                local secondResult = workspace:Raycast(newOrigin, rayDir * remainingDistance, rayParams)
                
                if not secondResult then
                    return true  -- Ничего не задели после DFrame
                else
                    local secondHit = secondResult.Instance
                    -- Проверяем, попали ли в цель после DFrame
                    return secondHit == targetHead or secondHit:IsDescendantOf(targetHead)
                end
            else
                return true  -- DFrame очень близко к цели
            end
        end
        
        -- Все остальное - невидимо
        return false
    end
end

-- Проверка валидности цели (без raycast)
local function isValidTarget(plr, targetHead)
    if not plr or not plr.Character then return false end
    if isFriend(plr) then return false end
    if not targetHead then return false end
    
    local char = plr.Character
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if hasSpawnShield(plr) then return false end
    if isTargetDowned(char) then return false end
    
    return true
end

-- Получение ближайшей цели к курсору (СНАЧАЛА FOV, ПОТОМ ВСЕ ОСТАЛЬНОЕ)
local function getNearestToCursor()
    local nearest = nil
    local minDist = fov
    local mousePos = UIS:GetMouseLocation()
    local localChar = localPlayer.Character
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    -- 1. Сначала позиция на экране
                    local pos, onscreen = Camera:WorldToScreenPoint(head.Position)
                    if onscreen then
                        -- 2. Проверка FOV (самое дешевое)
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist < minDist then
                            -- 3. Только если в FOV - проверяем валидность цели
                            if isValidTarget(plr, head) then
                                -- 4. Только если валидна - проверяем видимость (RAYCAST ТОЛЬКО ЗДЕСЬ)
                                if isTargetVisible(head, localChar) then
                                    minDist = dist
                                    nearest = head
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nearest
end

-- Функция для получения/обновления цели
local function getTarget()
    -- Если у нас уже есть цель и она все еще валидна
    if currentTarget and targetLocked then
        local plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
        
        -- Быстрая проверка: если игрока нет - сброс
        if not plr then
            currentTarget = nil
            targetLocked = false
            return nil
        end
        
        -- 1. Сначала проверка FOV (без валидации и raycast)
        if isTargetInFOV(currentTarget) then
            -- 2. Только если в FOV - проверяем валидность
            if isValidTarget(plr, currentTarget) then
                -- 3. Только если валидна - проверяем видимость (RAYCAST ТОЛЬКО ЗДЕСЬ)
                if isTargetVisible(currentTarget, localPlayer.Character) then
                    return currentTarget
                end
            end
        end
        
        -- Цель вышла из FOV или стала невалидной, сбрасываем
        currentTarget = nil
        targetLocked = false
        return nil
    end
    
    -- Если нет текущей цели, ищем новую
    if not currentTarget then
        local newTarget = getNearestToCursor()
        if newTarget then
            currentTarget = newTarget
            targetLocked = true
        end
    end
    
    return currentTarget
end

--==================== Input ====================
UIS.InputBegan:Connect(function(input, gameProcessed)
    -- 🔥 ЕСЛИ мы записываем бинд — НЕ ВЫХОДИМ
    if isRecordingKeybind then
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        isRecordingKeybind = false

        aimlockKey = input.KeyCode
        aimlockKeyName = input.KeyCode.Name

        -- 🔥 ТЕПЕРЬ label точно существует
        AimlockKeybindLabel:Set("Aimlock Key: " .. aimlockKeyName)

        Rayfield:Notify({
            Title = "Keybind Set",
            Content = "Aimlock key set to: " .. aimlockKeyName,
            Duration = 2,
            Image = 4483362458,
        })
        
        -- Сохраняем в конфиг
        if Window.ConfigurationSaving.Enabled then
            local config = Window:GetConfiguration()
            config.AimlockKey = aimlockKeyName
            Window:SetConfiguration(config)
        end
        
        return
    end

    -- ⛔ обычные инпуты — фильтруем
    if gameProcessed then return end

    -- Aimlock key (РАБОТАЕТ ТОЛЬКО ЕСЛИ БИНД УСТАНОВЛЕН)
    if aimlockKey and input.KeyCode == aimlockKey then
        keyHeld = true
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    -- Проверка бинда aimlock (РАБОТАЕТ ТОЛЬКО ЕСЛИ БИНД УСТАНОВЛЕН)
    if aimlockKey and input.KeyCode == aimlockKey then
        keyHeld = false
        -- При отпускании клавиши сбрасываем цель
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
        end
    end
end)

--==================== ESP System ====================
local Box_ESP_Enabled = false
local ESP_HPEnabled = false
local ESP_NameEnabled = false
local ESP_HPDynamicEnabled = false
local ESP_WeaponEnabled = false
local ESP_MaxDistance = 1500
local Settings = {ESP_Color=Color3.fromRGB(255,0,0), Friend_Color=Color3.fromRGB(0,255,0)}

-- Таблицы для хранения ESP объектов
local ESP_HPText = {}
local ESP_NameText = {}
local ESP_WeaponText = {}
local ESP_Boxes = {}
local partCache = {}
local characterCache = {} -- Кеш для персонажей игроков
local viewportCache = {} -- Кеш для WorldToViewportPoint

-- Кеш для игроков в зоне видимости (чтобы не проверять всех каждый кадр)
local playersInRange = {}
local lastDistanceCheck = 0
local DISTANCE_CHECK_INTERVAL = 0.2 -- Проверяем дистанцию раз в 0.2 секунды

-- Функция для полной очистки ESP игрока
local function cleanupPlayerESP(plr)
    if ESP_HPText[plr] then
        if ESP_HPText[plr] then
            ESP_HPText[plr].Visible = false
            ESP_HPText[plr]:Remove()
        end
        ESP_HPText[plr] = nil
    end
    
    if ESP_NameText[plr] then
        if ESP_NameText[plr] then
            ESP_NameText[plr].Visible = false
            ESP_NameText[plr]:Remove()
        end
        ESP_NameText[plr] = nil
    end
    
    if ESP_WeaponText[plr] then
        if ESP_WeaponText[plr] then
            ESP_WeaponText[plr].Visible = false
            ESP_WeaponText[plr]:Remove()
        end
        ESP_WeaponText[plr] = nil
    end
    
    if ESP_Boxes[plr] then
        if ESP_Boxes[plr].box then
            ESP_Boxes[plr].box.Visible = false
            ESP_Boxes[plr].box:Remove()
        end
        if ESP_Boxes[plr].boxoutline then
            ESP_Boxes[plr].boxoutline.Visible = false
            ESP_Boxes[plr].boxoutline:Remove()
        end
        ESP_Boxes[plr] = nil
    end
    
    -- Очищаем кеши
    partCache[plr] = nil
    characterCache[plr] = nil
    viewportCache[plr] = nil
    playersInRange[plr] = nil
end

-- Функция для скрытия ESP игрока (без удаления)
local function hidePlayerESP(plr)
    if ESP_HPText[plr] then
        ESP_HPText[plr].Visible = false
    end
    if ESP_NameText[plr] then
        ESP_NameText[plr].Visible = false
    end
    if ESP_WeaponText[plr] then
        ESP_WeaponText[plr].Visible = false
    end
    if ESP_Boxes[plr] then
        ESP_Boxes[plr].box.Visible = false
        ESP_Boxes[plr].boxoutline.Visible = false
    end
end

-- Функция для создания ESP объектов
local function createESPObjects(plr)
    -- Сначала очищаем старые объекты, если они есть
    cleanupPlayerESP(plr)
    
    -- Текст для HP
    local hpText = Drawing.new("Text")
    hpText.Visible = false
    hpText.Color = Settings.ESP_Color
    hpText.Size = 14
    hpText.Center = true
    hpText.Outline = true
    ESP_HPText[plr] = hpText
    
    -- Текст для имени
    local nameText = Drawing.new("Text")
    nameText.Visible = false
    nameText.Color = Settings.ESP_Color
    nameText.Size = 9
    nameText.Center = true
    nameText.Outline = true
    ESP_NameText[plr] = nameText
    
    -- Текст для оружия
    local weaponText = Drawing.new("Text")
    weaponText.Visible = false
    weaponText.Color = Settings.ESP_Color
    weaponText.Size = 12
    weaponText.Center = true
    weaponText.Outline = true
    ESP_WeaponText[plr] = weaponText
    
    -- Box для Box ESP
    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1
    box.Color = Settings.ESP_Color
    
    local boxoutline = Drawing.new("Square")
    boxoutline.Visible = false
    boxoutline.Thickness = 1
    boxoutline.Color = Settings.ESP_Color
    
    ESP_Boxes[plr] = {box = box, boxoutline = boxoutline}
    
    -- Инициализируем кеш частей
    partCache[plr] = {}
    characterCache[plr] = plr.Character
    
    -- Кешируем части персонажа
    if plr.Character then
        for _, part in ipairs(plr.Character:GetChildren()) do
            if part:IsA("BasePart") then
                partCache[plr][part] = true
            end
        end
    end
end

-- Проверка дистанции с кешированием
local function updatePlayersInRangeCache()
    local currentTime = tick()
    
    -- Проверяем дистанцию только если прошло достаточно времени
    if currentTime - lastDistanceCheck < DISTANCE_CHECK_INTERVAL then
        return
    end
    
    lastDistanceCheck = currentTime
    
    local cameraPos = Camera.CFrame.Position
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChild("Humanoid")
            
            if hrp and humanoid and humanoid.Health > 0 then
                local dist = (cameraPos - hrp.Position).Magnitude
                local isInRange = dist <= ESP_MaxDistance
                
                -- Обновляем кеш
                playersInRange[plr] = isInRange
                
                -- Если игрок вышел из дистанции - скрываем ESP
                if not isInRange and ESP_HPText[plr] then
                    hidePlayerESP(plr)
                end
            else
                playersInRange[plr] = false
            end
        else
            playersInRange[plr] = false
        end
    end
end

-- Функция для получения углов 3D бокса (оптимизированная версия)
local function get3DBoxCorners(hrp)
    local cf = hrp.CFrame
    local size = Vector3.new(4, 6, 1.5)

    return {
        cf * Vector3.new(-size.X/2, size.Y/2, 0),
        cf * Vector3.new( size.X/2, size.Y/2, 0),
        cf * Vector3.new(-size.X/2,-size.Y/2, 0),
        cf * Vector3.new( size.X/2,-size.Y/2, 0),
    }
end

-- Кеширование WorldToViewportPoint точек (только для видимых игроков)
local function cacheViewportPoints()
    -- Очищаем кеш предыдущего кадра
    viewportCache = {}
    
    -- Кешируем точки только для живых игроков в пределах дистанции
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer and playersInRange[plr] then
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                
                if hrp and humanoid and humanoid.Health > 0 then
                    -- Создаем или обновляем кеш
                    viewportCache[plr] = {
                        head = nil,
                        boxCorners = {},
                        anyVisible = false
                    }
                    
                    local data = viewportCache[plr]
                    
                    -- Кешируем позицию головы
                    local head = char:FindFirstChild("Head")
                    if head then
                        local headPos, headVisible = Camera:WorldToViewportPoint(head.Position)
                        data.head = {pos = Vector2.new(headPos.X, headPos.Y), visible = headVisible, z = headPos.Z}
                        if headVisible then data.anyVisible = true end
                    end
                    
                    -- Кешируем углы для Box ESP (только если включен Box ESP)
                    if Box_ESP_Enabled then
                        local corners = get3DBoxCorners(hrp)
                        
                        for i, corner in ipairs(corners) do
                            local pos, visible = Camera:WorldToViewportPoint(corner)
                            data.boxCorners[i] = {pos = Vector2.new(pos.X, pos.Y), visible = visible, z = pos.Z}
                            if visible then data.anyVisible = true end
                        end
                    end
                end
            end
        end
    end
end

-- Оптимизированная функция обновления ESP для одного игрока
local function updatePlayerESP(plr)
    -- Проверяем, включен ли вообще какой-либо ESP
    if not ESP_HPEnabled and not ESP_NameEnabled and not ESP_WeaponEnabled and not Box_ESP_Enabled then
        if ESP_HPText[plr] or ESP_NameText[plr] or ESP_WeaponText[plr] or ESP_Boxes[plr] then
            hidePlayerESP(plr)
        end
        return
    end
    
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or char.Humanoid.Health <= 0 then
        -- Игрок мертв или нет персонажа - удаляем ESP
        if ESP_HPText[plr] then
            cleanupPlayerESP(plr)
        end
        return
    end
    
    -- Если игрок В зоне видимости, но ESP объектов нет - создаем их
    if not ESP_HPText[plr] then
        createESPObjects(plr)
    end
    
    -- Проверяем, не изменился ли персонаж
    if characterCache[plr] ~= char then
        characterCache[plr] = char
        partCache[plr] = {}
        
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                partCache[plr][part] = true
            end
        end
    end
    
    -- Используем кешированные точки
    local data = viewportCache[plr]
    if not data or not data.anyVisible then
        hidePlayerESP(plr)
        return
    end
    
    local color = isFriend(plr) and Settings.Friend_Color or Settings.ESP_Color
    local hpText = ESP_HPText[plr]
    local nameText = ESP_NameText[plr]
    local weaponText = ESP_WeaponText[plr]
    local boxes = ESP_Boxes[plr]
    
    -- Обновляем текстовые ESP (используя кешированные точки головы)
    if data.head and data.head.visible then
        local headPos = data.head.pos
        
        -- HP Text
        if ESP_HPEnabled and hpText then
            local hp = math.clamp(char.Humanoid.Health, 0, char.Humanoid.MaxHealth)
            local hpColor = ESP_HPDynamicEnabled and Color3.fromHSV((hp/char.Humanoid.MaxHealth)/3,1,1) or color
            hpText.Position = Vector2.new(headPos.X + 20, headPos.Y)
            hpText.Text = math.floor(hp) .. " HP"
            hpText.Color = hpColor
            hpText.Visible = true
        elseif hpText then
            hpText.Visible = false
        end
        
        -- Name Text
        if ESP_NameEnabled and nameText then
            nameText.Position = Vector2.new(headPos.X, headPos.Y - 15)
            nameText.Text = plr.Name
            nameText.Color = color
            nameText.Visible = true
        elseif nameText then
            nameText.Visible = false
        end
        
        -- Weapon Text
        if ESP_WeaponEnabled and weaponText then
            local tool = char:FindFirstChildOfClass("Tool")
            weaponText.Position = Vector2.new(headPos.X, headPos.Y + 15)
            weaponText.Text = tool and tool.Name or "None"
            weaponText.Color = color
            weaponText.Visible = true
        elseif weaponText then
            weaponText.Visible = false
        end
    else
        if hpText then hpText.Visible = false end
        if nameText then nameText.Visible = false end
        if weaponText then weaponText.Visible = false end
    end

    -- Box ESP
    if Box_ESP_Enabled and boxes then
        local boxCorners = data.boxCorners
        
        if boxCorners and #boxCorners > 0 then
            local minX, minY, maxX, maxY = 9e9, 9e9, -9e9, -9e9
            local anyVisible = false
            
            for _, corner in ipairs(boxCorners) do
                if corner.visible and corner.z > 0 then
                    anyVisible = true
                    minX = math.min(minX, corner.pos.X)
                    minY = math.min(minY, corner.pos.Y)
                    maxX = math.max(maxX, corner.pos.X)
                    maxY = math.max(maxY, corner.pos.Y)
                end
            end
            
            if anyVisible then
                local w, h = maxX - minX, maxY - minY
                local pos = Vector2.new(minX, minY)
                
                boxes.box.Position = pos
                boxes.box.Size = Vector2.new(w, h)
                boxes.box.Color = color
                boxes.box.Visible = true
                
                boxes.boxoutline.Position = Vector2.new(pos.X - 1, pos.Y - 1)
                boxes.boxoutline.Size = Vector2.new(w + 2, h + 2)
                boxes.boxoutline.Color = color
                boxes.boxoutline.Visible = true
            else
                boxes.box.Visible = false
                boxes.boxoutline.Visible = false
            end
        else
            boxes.box.Visible = false
            boxes.boxoutline.Visible = false
        end
    elseif boxes then
        boxes.box.Visible = false
        boxes.boxoutline.Visible = false
    end
end

-- Инициализация игроков
local function initPlayer(plr)
    if plr == localPlayer then return end
    
    -- Подключаем обработчик смерти/возрождения
    plr.CharacterAdded:Connect(function(char)
        -- Удаляем старые ESP объекты при смене персонажа
        cleanupPlayerESP(plr)
    end)
end

-- Инициализируем существующих игроков
for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= localPlayer then
        initPlayer(plr)
    end
end

-- Обработчики добавления/удаления игроков
Players.PlayerAdded:Connect(function(plr)
    if plr ~= localPlayer then
        initPlayer(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    cleanupPlayerESP(plr)
end)

-- ESP Tab
local HPToggle = ESPTab:CreateToggle({
    Name = "Health ESP",
    CurrentValue = false,
    Flag = "HPToggle",
    Callback = function(Value)
        ESP_HPEnabled = Value
    end,
})

local HPDynamicToggle = ESPTab:CreateToggle({
    Name = "Dynamic Health Color",
    CurrentValue = false,
    Flag = "HPDynamicToggle",
    Callback = function(Value)
        ESP_HPDynamicEnabled = Value
    end,
})

local BoxToggle = ESPTab:CreateToggle({
    Name = "Box ESP",
    CurrentValue = false,
    Flag = "BoxToggle",
    Callback = function(Value)
        Box_ESP_Enabled = Value
    end,
})

local NameToggle = ESPTab:CreateToggle({
    Name = "Name ESP",
    CurrentValue = false,
    Flag = "NameToggle",
    Callback = function(Value)
        ESP_NameEnabled = Value
    end,
})

local WeaponToggle = ESPTab:CreateToggle({
    Name = "Weapon ESP",
    CurrentValue = false,
    Flag = "WeaponToggle",
    Callback = function(Value)
        ESP_WeaponEnabled = Value
    end,
})

local ESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Settings.ESP_Color,
    Flag = "ESPColor",
    Callback = function(Value)
        Settings.ESP_Color = Value
    end
})

local ESPDistanceSlider = ESPTab:CreateSlider({
    Name = "Max ESP Distance",
    Range = {1, 1500},
    Increment = 50,
    Suffix = "studs",
    CurrentValue = 1500,
    Flag = "ESPDistance",
    Callback = function(Value)
        ESP_MaxDistance = Value
    end,
})

-- Misc Tab
local DestroyUIButton = MiscTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        -- Очищаем все ESP объекты перед уничтожением
        for plr, _ in pairs(ESP_HPText) do
            cleanupPlayerESP(plr)
        end
        fovCircle:Remove()
        Rayfield:Destroy()
    end,
})

--==================== Render Loop ====================
local currentTool

RunService.RenderStepped:Connect(function()
    -- FOV Circle оптимизация
    if not aimbotEnabled or not showFOV then
        fovCircle.Visible = false
    else
        local mousePos = UIS:GetMouseLocation()
        if mousePos ~= lastMousePos or fov ~= lastFOV then
            fovCircle.Position = mousePos
            fovCircle.Radius = fov
            fovCircle.Visible = true
            lastMousePos = mousePos
            lastFOV = fov
        end
    end

    -- Aimlock и Autofire (работает ТОЛЬКО если бинд установлен и зажат)
    if aimbotEnabled and aimlockKey and keyHeld then
        local targetHead = getTarget()
        
        if targetHead then
            local plr = Players:GetPlayerFromCharacter(targetHead.Parent)
            local validTarget = plr and isValidTarget(plr, targetHead)
            
            if validTarget then
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, getPredictedPosition(targetHead))
                
                if autofireEnabled then
                    currentTool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
                    if currentTool then 
                        currentTool:Activate() 
                    end
                end
            else
                currentTarget = nil
                targetLocked = false
                if currentTool then 
                    currentTool:Deactivate() 
                    currentTool = nil 
                end
            end
        else
            if currentTool then 
                currentTool:Deactivate() 
                currentTool = nil 
            end
        end
    else
        if currentTool then 
            currentTool:Deactivate() 
            currentTool = nil 
        end
    end

    -- ESP Update (оптимизированный)
    -- 1. Обновляем кеш дистанции
    updatePlayersInRangeCache()
    
    -- 2. Кешируем все точки для текущего кадра
    cacheViewportPoints()
    
    -- 3. Обновляем ESP только для игроков в дистанции
    for plr, isInRange in pairs(playersInRange) do
        if isInRange then
            updatePlayerESP(plr)
        elseif ESP_HPText[plr] then
            -- Если игрок вне дистанции, скрываем ESP
            hidePlayerESP(plr)
        end
    end
end)

-- Функция для загрузки сохраненного бинда
local function loadSavedKeybind()
    if Window.ConfigurationSaving.Enabled then
        local config = Window:GetConfiguration()
        if config and config.AimlockKey then
            local keyString = config.AimlockKey
            if keyString and keyString ~= "" and keyString ~= "Not Set" then
                local success, keyCode = pcall(function()
                    return Enum.KeyCode[keyString]
                end)
                
                if success and keyCode then
                    aimlockKey = keyCode
                    aimlockKeyName = keyString
                    AimlockKeybindLabel:Set("Aimlock Key: " .. aimlockKeyName)
                end
            end
        end
    end
end

-- Загружаем сохраненный бинд при запуске
loadSavedKeybind()

-- Инициализация UI
Rayfield:LoadConfiguration()
