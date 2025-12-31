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
        SaveKey = false,
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

-- НАСТРОЙКИ NO VISUAL RECOIL (ПЕРЕХВАТ КАМЕРЫ)
local noVisualRecoilEnabled = false
local cameraHookEnabled = false
local originalCameraCFrame = nil
local cameraHookConnection = nil

-- Настройки биндов (НЕ СОХРАНЯЕТСЯ В КОНФИГЕ)
local aimlockKey = nil
local aimlockKeyName = "Not Set"
local isRecordingKeybind = false

-- Добавляем переменные для стабильного aimlock
local currentTarget = nil -- Текущая цель
local targetLocked = false -- Флаг блокировки цели

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 100
local lastMousePos = Vector2.new()
local lastFOV = fov

--==================== НОВЫЙ NO VISUAL RECOIL (ПЕРЕХВАТ КАМЕРЫ) ====================

-- Функция для перехвата и нейтрализации отдачи камеры
local function setupCameraRecoilHook()
    if not noVisualRecoilEnabled or cameraHookEnabled then
        return
    end
    
    print("[NoRecoil] Setting up camera recoil hook...")
    
    -- Сохраняем оригинальный CFrame камеры
    originalCameraCFrame = Camera.CFrame
    
    -- Метод 1: Перехват обновлений камеры через RenderStepped
    cameraHookConnection = RunService.RenderStepped:Connect(function()
        if not noVisualRecoilEnabled then
            return
        end
        
        -- Фиксируем камеру на её оригинальной позиции (без отдачи)
        if originalCameraCFrame then
            -- Сохраняем текущее направление взгляда
            local lookVector = Camera.CFrame.LookVector
            
            -- Устанавливаем камеру с фиксированной позицией, но сохраняем направление
            Camera.CFrame = CFrame.new(originalCameraCFrame.Position) * CFrame.lookAt(
                originalCameraCFrame.Position,
                originalCameraCFrame.Position + lookVector
            )
        end
    end)
    
    cameraHookEnabled = true
    print("[NoRecoil] Camera hook activated")
end

-- Метод 2: Перехват конкретных событий отдачи
local function interceptRecoilEvents()
    if not noVisualRecoilEnabled then
        return
    end
    
    -- Поиск и нейтрализация событий отдачи
    local function neutralizeRecoilEvent(eventName)
        -- Проверяем ReplicatedStorage на события отдачи
        local remoteEvent = ReplicatedStorage:FindFirstChild(eventName)
        if remoteEvent and remoteEvent:IsA("RemoteEvent") then
            local originalFireServer = remoteEvent.FireServer
            remoteEvent.FireServer = function(self, ...)
                -- Сервер получает оригинальные параметры
                return originalFireServer(self, ...)
            end
        end
    end
    
    -- Список возможных событий отдачи
    local recoilEvents = {
        "RecoilEvent",
        "ApplyRecoil",
        "CameraShake",
        "FireWeapon",
        "Shoot",
        "WeaponFired"
    }
    
    for _, eventName in pairs(recoilEvents) do
        pcall(neutralizeRecoilEvent, eventName)
    end
end

-- Метод 3: Перехват анимаций отдачи
local function interceptRecoilAnimations()
    if not noVisualRecoilEnabled then
        return
    end
    
    local char = localPlayer.Character
    if not char then return end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Останавливаем все анимации отдачи
    for _, animTrack in pairs(humanoid:GetPlayingAnimationTracks()) do
        local animName = animTrack.Name:lower()
        if animName:find("recoil") or animName:find("fire") or animName:find("shoot") then
            animTrack:Stop()
        end
    end
end

-- Метод 4: Нейтрализация визуальных эффектов отдачи
local function neutralizeVisualEffects()
    if not noVisualRecoilEnabled then
        return
    end
    
    -- Удаление эффектов тряски
    local cameraShaker = Camera:FindFirstChild("CameraShaker")
    if cameraShaker then
        cameraShaker:Destroy()
    end
    
    -- Удаление эффектов блума/размытия
    for _, effect in pairs(Camera:GetChildren()) do
        if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
            if effect.Name:find("Recoil") or effect.Name:find("Fire") then
                effect.Enabled = false
            end
        end
    end
    
    -- Фиксация оружия во вьюмоделе
    local viewmodels = workspace:FindFirstChild("Viewmodels") or workspace:FindFirstChild("Viewmodel")
    if viewmodels then
        for _, weapon in pairs(viewmodels:GetDescendants()) do
            if weapon:IsA("BasePart") then
                -- Отключаем физику и фиксируем позицию
                if weapon:FindFirstChild("BodyPosition") then
                    weapon.BodyPosition:Destroy()
                end
                if weapon:FindFirstChild("BodyGyro") then
                    weapon.BodyGyro:Destroy()
                end
            end
        end
    end
end

-- Основная функция активации no visual recoil
local function activateNoVisualRecoil()
    if cameraHookEnabled then
        return
    end
    
    print("[NoRecoil] Activating no visual recoil...")
    
    -- Запускаем все методы
    setupCameraRecoilHook()
    
    -- Периодические проверки и нейтрализации
    local periodicCheck = RunService.Heartbeat:Connect(function()
        if not noVisualRecoilEnabled then
            periodicCheck:Disconnect()
            return
        end
        
        interceptRecoilAnimations()
        neutralizeVisualEffects()
        
        -- Обновляем оригинальную позицию камеры если игрок движется
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = localPlayer.Character.HumanoidRootPart
            if hrp and (not originalCameraCFrame or (hrp.Position - originalCameraCFrame.Position).Magnitude > 5) then
                originalCameraCFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0))
            end
        end
    end)
    
    -- Одноразовый перехват событий
    interceptRecoilEvents()
    
    Rayfield:Notify({
        Title = "No Visual Recoil",
        Content = "Visual recoil removed. Server sees real recoil values.",
        Duration = 3,
        Image = 4483362458,
    })
end

-- Функция деактивации
local function deactivateNoVisualRecoil()
    if cameraHookConnection then
        cameraHookConnection:Disconnect()
        cameraHookConnection = nil
    end
    
    cameraHookEnabled = false
    originalCameraCFrame = nil
    
    print("[NoRecoil] Camera hook deactivated")
    
    Rayfield:Notify({
        Title = "No Visual Recoil",
        Content = "Visual recoil restored to normal",
        Duration = 2,
        Image = 4483362458,
    })
end

--==================== НОВЫЙ WALLCHECK ====================

-- ✅ FOV CHECK (БЫСТРЫЙ, БЕЗ МУСОРА)
local FOV_RADIUS = 100

local function InFOV(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    if not onScreen then return false end

    local mousePos = UIS:GetMouseLocation()
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

    return dist <= FOV_RADIUS
end

-- Функция проверки видимости цели (с wallcheck)
local function WallCheck(targetHead, localChar)
    if not wallCheckEnabled then return true end
    if not targetHead or not localChar then return false end
    
    -- СНАЧАЛА проверяем, что цель в FOV
    if not InFOV(targetHead.Position) then
        return false -- цель вне FOV, wallcheck не нужен
    end

    local origin = Camera.CFrame.Position
    local direction = (targetHead.Position - origin).Unit
    local distanceToTarget = (targetHead.Position - origin).Magnitude
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {localChar, targetHead.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true

    -- Первый raycast от камеры до цели
    local result1 = workspace:Raycast(origin, direction * distanceToTarget, rayParams)
    
    if not result1 then
        return true -- ничего не попали, цель видна
    end
    
    local hit1 = result1.Instance
    
    -- Попали в саму цель
    if hit1:IsDescendantOf(targetHead.Parent) then
        return true
    end
    
    -- ✅ Если попали в DFrame, проверяем что ЗА ним
    if hit1.Name == "DFrame" or hit1.ClassName == "DFrame" then
        -- Делаем второй raycast от точки ЗА DFrame до цели
        local newOrigin = result1.Position + (direction * 0.5)
        local remainingDistance = distanceToTarget - (newOrigin - origin).Magnitude
        
        if remainingDistance > 0 then
            local result2 = workspace:Raycast(newOrigin, direction * remainingDistance, rayParams)
            
            if not result2 then
                return true -- за DFrame ничего нет, цель видна
            end
            
            local hit2 = result2.Instance
            
            -- Проверяем, попали ли в цель ЗА DFrame
            if hit2:IsDescendantOf(targetHead.Parent) then
                return true -- за DFrame сразу цель
            end
            
            -- За DFrame есть ДРУГАЯ стена → не видно
            return false
        end
    end
    
    -- Попали в не-DFrame объект → стена
    return false
end

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

-- НОВЫЙ УЛУЧШЕННЫЙ ТОГГЛ: No Visual Recoil (перехват камеры)
local NoVisualRecoilToggle = RageTab:CreateToggle({
    Name = "🟢 No Visual Recoil",
    CurrentValue = false,
    Flag = "NoVisualRecoilToggle",
    Callback = function(Value)
        noVisualRecoilEnabled = Value
        
        if Value then
            -- Активируем no visual recoil
            activateNoVisualRecoil()
        else
            -- Деактивируем no visual recoil
            deactivateNoVisualRecoil()
        end
    end,
})

local NoVisualRecoilDescription = RageTab:CreateLabel("Перехватывает отдачу ДО применения к камере")
local NoVisualRecoilDescription2 = RageTab:CreateLabel("Сервер видит реальные значения, клиент - нет")

-- Лейбл для бинда (НЕ СОХРАНЯЕТСЯ В КОНФИГЕ)
local AimlockKeybindLabel = RageTab:CreateLabel("Aimlock Key: Not Set")

-- Кнопка для установки бинда (БИНД НЕ СОХРАНЯЕТСЯ)
local SetAimlockKeyButton = RageTab:CreateButton({
    Name = "Set Aimlock Key",
    Callback = function()
        isRecordingKeybind = true
        AimlockKeybindLabel:Set("Press any keyboard key...")
        
        -- Ожидаем нажатия клавиши
        local connection
        connection = UIS.InputBegan:Connect(function(input, gameProcessed)
            if isRecordingKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
                isRecordingKeybind = false
                connection:Disconnect()
                
                aimlockKey = input.KeyCode
                aimlockKeyName = input.KeyCode.Name
                AimlockKeybindLabel:Set("Aimlock Key: " .. aimlockKeyName)
                
                Rayfield:Notify({
                    Title = "Keybind Set",
                    Content = "Aimlock key set to: " .. aimlockKeyName,
                    Duration = 2,
                    Image = 4483362458,
                })
            end
        end)
        
        -- Таймаут через 5 секунд
        task.delay(5, function()
            if isRecordingKeybind then
                isRecordingKeybind = false
                if connection then
                    connection:Disconnect()
                end
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
        FOV_RADIUS = Value
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

-- Оптимизированная функция предсказания
local function getPredictedPosition(target)
    local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then return target.Position end
    
    local dir = hrp.Position - Camera.CFrame.Position
    local dist = dir.Magnitude
    local t = dist / getCurrentWeaponSpeed()
    
    return target.Position + hrp.Velocity * t
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

-- Получение ближайшей цели к курсору (СНАЧАЛА FOV, ПОТОМ WALLCHECK)
local function getNearestToCursor()
    local nearest = nil
    local minDist = FOV_RADIUS
    local localChar = localPlayer.Character
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    -- 1. Сначала FOV check (самое дешевое)
                    if InFOV(head.Position) then
                        -- 2. Проверяем валидность цели
                        if isValidTarget(plr, head) then
                            -- 3. Только если валидна - проверяем видимость через WallCheck
                            if WallCheck(head, localChar) then
                                -- Находим ближайшую к курсору
                                local mousePos = UIS:GetMouseLocation()
                                local pos, _ = Camera:WorldToScreenPoint(head.Position)
                                local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                                
                                if dist < minDist then
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
        
        -- 1. Сначала проверка FOV
        if InFOV(currentTarget.Position) then
            -- 2. Только если в FOV - проверяем валидность
            if isValidTarget(plr, currentTarget) then
                -- 3. Только если валидна - проверяем видимость через WallCheck
                if WallCheck(currentTarget, localPlayer.Character) then
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

--==================== LEGIT NO FALL ====================

local NoFallEnabled = false
local NoFallConnection

local FALL_SPEED_THRESHOLD = -55
local SAFE_FALL_SPEED = -15

local function startNoFall()
    if NoFallEnabled then return end
    NoFallEnabled = true

    NoFallConnection = RunService.Heartbeat:Connect(function()
        if not NoFallEnabled then return end

        local char = localPlayer.Character
        if not char then return end

        local humanoid = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not hrp then return end

        -- если сидим / карабкаемся — не лезем
        if humanoid.SeatPart or humanoid:GetState() == Enum.HumanoidStateType.Climbing then
            return
        end

        local velY = hrp.Velocity.Y

        -- только при РЕАЛЬНОМ падении
        if velY < FALL_SPEED_THRESHOLD then
            hrp.Velocity = Vector3.new(
                hrp.Velocity.X,
                SAFE_FALL_SPEED,
                hrp.Velocity.Z
            )
        end
    end)

    print("[NoFall] Legit NoFall enabled")
end

local function stopNoFall()
    NoFallEnabled = false

    if NoFallConnection then
        NoFallConnection:Disconnect()
        NoFallConnection = nil
    end

    print("[NoFall] Legit NoFall disabled")
end

--==================== Input ====================
UIS.InputBegan:Connect(function(input, gameProcessed)
    -- ЕСЛИ мы записываем бинд
    if isRecordingKeybind then
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        isRecordingKeybind = false

        aimlockKey = input.KeyCode
        aimlockKeyName = input.KeyCode.Name

        AimlockKeybindLabel:Set("Aimlock Key: " .. aimlockKeyName)

        Rayfield:Notify({
            Title = "Keybind Set",
            Content = "Aimlock key set to: " .. aimlockKeyName,
            Duration = 2,
            Image = 4483362458,
        })
        
        return
    end

    if gameProcessed then return end

    if aimlockKey and input.KeyCode == aimlockKey then
        keyHeld = true
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if aimlockKey and input.KeyCode == aimlockKey then
        keyHeld = false
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
local NoFallToggle = MiscTab:CreateToggle({
    Name = "NoFall Protection",
    CurrentValue = false,
    Flag = "NoFallToggle",
    Callback = function(Value)
        if Value then
            task.spawn(function()
                startNoFall()
                Rayfield:Notify({
                    Title = "NoFall Activated",
                    Content = "Fall damage protection enabled",
                    Duration = 2,
                    Image = 4483362458,
                })
            end)
        else
            task.spawn(function()
                stopNoFall()
                Rayfield:Notify({
                    Title = "NoFall Deactivated",
                    Content = "Fall damage protection disabled",
                    Duration = 2,
                    Image = 4483362458,
                })
            end)
        end
    end,
})

local DestroyUIButton = MiscTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        -- Останавливаем NoFall
        stopNoFall()
        
        -- Останавливаем no visual recoil
        deactivateNoVisualRecoil()
        
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

    -- No Visual Recoil активирован через перехват камеры
    -- (работает в background через cameraHookConnection)

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

-- Инициализация UI
Rayfield:LoadConfiguration()
