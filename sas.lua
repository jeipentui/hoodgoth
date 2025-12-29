-- Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")
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
UIS.InputBegan:Connect(function(i,g)
    if not g and i.KeyCode == Enum.KeyCode.X then 
        keyHeld = true 
        -- При нажатии на клавишу ищем новую цель
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
        end
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.X then 
        keyHeld = false 
        -- При отпускании клавиши сбрасываем цель
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
        end
    end
end)

--==================== Optimized 3D Box ESP System ====================
local Box3D_Enabled = false
local ESP_MaxDistance = 1500
local ESP_HPEnabled = false
local ESP_NameEnabled = false
local ESP_HPDynamicEnabled = false
local ESP_WeaponEnabled = false
local Settings = {
    ESP_Color = Color3.fromRGB(255,0,0), 
    Friend_Color = Color3.fromRGB(0,255,0),
    Box3D_Color = Color3.fromRGB(255,0,0),
    Box3D_Friend_Color = Color3.fromRGB(0,255,0)
}

-- Кеш для 3D боксов
local Box3D_Cache = {}
local ESP_HPText = {}
local ESP_NameText = {}
local ESP_WeaponText = {}
local characterCache = {}
local viewportCache = {}
local playersInRange = {}
local lastDistanceCheck = 0
local DISTANCE_CHECK_INTERVAL = 0.2

-- Размеры персонажа (оптимизированные константы)
local HUMAN_SIZE = Vector3.new(4, 6, 1.5)

-- Углы 3D бокса в локальном пространстве (вычисляем один раз при загрузке)
local LOCAL_CORNERS = {
    Vector3.new(-HUMAN_SIZE.X/2,  HUMAN_SIZE.Y/2,  0),           -- 1 Верхний левый передний
    Vector3.new( HUMAN_SIZE.X/2,  HUMAN_SIZE.Y/2,  0),           -- 2 Верхний правый передний
    Vector3.new(-HUMAN_SIZE.X/2, -HUMAN_SIZE.Y/2,  0),           -- 3 Нижний левый передний
    Vector3.new( HUMAN_SIZE.X/2, -HUMAN_SIZE.Y/2,  0),           -- 4 Нижний правый передний
    Vector3.new(-HUMAN_SIZE.X/2,  HUMAN_SIZE.Y/2,  HUMAN_SIZE.Z), -- 5 Верхний левый задний
    Vector3.new( HUMAN_SIZE.X/2,  HUMAN_SIZE.Y/2,  HUMAN_SIZE.Z), -- 6 Верхний правый задний
    Vector3.new(-HUMAN_SIZE.X/2, -HUMAN_SIZE.Y/2,  HUMAN_SIZE.Z), -- 7 Нижний левый задний
    Vector3.new( HUMAN_SIZE.X/2, -HUMAN_SIZE.Y/2,  HUMAN_SIZE.Z), -- 8 Нижний правый задний
}

-- Соединения между точками для рисования линий
local BOX_CONNECTIONS = {
    {1, 2}, {2, 4}, {4, 3}, {3, 1}, -- Передняя грань
    {5, 6}, {6, 8}, {8, 7}, {7, 5}, -- Задняя грань
    {1, 5}, {2, 6}, {3, 7}, {4, 8}  -- Соединительные линии
}

-- Функция для создания 3D Box объектов для игрока
local function createBox3DForPlayer(plr)
    if Box3D_Cache[plr] then return Box3D_Cache[plr] end
    
    Box3D_Cache[plr] = {
        lines = {},
        visible = false,
        color = Settings.Box3D_Color
    }
    
    -- Создаем 12 линий для 3D бокса
    for i = 1, 12 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Thickness = 1
        line.Color = Settings.Box3D_Color
        table.insert(Box3D_Cache[plr].lines, line)
    end
    
    return Box3D_Cache[plr]
end

-- Функция для скрытия 3D бокса
local function hideBox3D(plr)
    local boxData = Box3D_Cache[plr]
    if not boxData then return end
    
    boxData.visible = false
    for _, line in ipairs(boxData.lines) do
        line.Visible = false
    end
end

-- Функция для удаления 3D бокса
local function cleanupBox3D(plr)
    local boxData = Box3D_Cache[plr]
    if not boxData then return end
    
    for _, line in ipairs(boxData.lines) do
        if line then
            line.Visible = false
            line:Remove()
        end
    end
    
    Box3D_Cache[plr] = nil
end

-- Функция для очистки ESP игрока
local function cleanupPlayerESP(plr)
    -- Очищаем 3D Box
    cleanupBox3D(plr)
    
    -- Очищаем текстовые ESP
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
    
    -- Очищаем кеши
    characterCache[plr] = nil
    viewportCache[plr] = nil
    playersInRange[plr] = nil
end

-- Функция для скрытия ESP игрока (без удаления)
local function hidePlayerESP(plr)
    -- Скрываем 3D Box
    hideBox3D(plr)
    
    -- Скрываем текстовые ESP
    if ESP_HPText[plr] then
        ESP_HPText[plr].Visible = false
    end
    if ESP_NameText[plr] then
        ESP_NameText[plr].Visible = false
    end
    if ESP_WeaponText[plr] then
        ESP_WeaponText[plr].Visible = false
    end
end

-- Функция для создания текстовых ESP объектов
local function createESPObjects(plr)
    -- Очищаем старые объекты
    cleanupPlayerESP(plr)
    
    -- Создаем 3D Box если нужно
    if Box3D_Enabled then
        createBox3DForPlayer(plr)
    end
    
    -- Создаем текстовые ESP
    if ESP_HPEnabled then
        local hpText = Drawing.new("Text")
        hpText.Visible = false
        hpText.Color = Settings.ESP_Color
        hpText.Size = 14
        hpText.Center = true
        hpText.Outline = true
        ESP_HPText[plr] = hpText
    end
    
    if ESP_NameEnabled then
        local nameText = Drawing.new("Text")
        nameText.Visible = false
        nameText.Color = Settings.ESP_Color
        nameText.Size = 9
        nameText.Center = true
        nameText.Outline = true
        ESP_NameText[plr] = nameText
    end
    
    if ESP_WeaponEnabled then
        local weaponText = Drawing.new("Text")
        weaponText.Visible = false
        weaponText.Color = Settings.ESP_Color
        weaponText.Size = 12
        weaponText.Center = true
        weaponText.Outline = true
        ESP_WeaponText[plr] = weaponText
    end
    
    -- Инициализируем кеш
    characterCache[plr] = plr.Character
end

-- Проверка дистанции с кешированием
local function updatePlayersInRangeCache()
    local currentTime = tick()
    
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
                playersInRange[plr] = dist <= ESP_MaxDistance
            else
                playersInRange[plr] = false
            end
        else
            playersInRange[plr] = false
        end
    end
end

-- Кешируем WorldToViewportPoint результаты для текущего кадра
local viewportPointsCache = {}
local function cacheViewportPointsForFrame()
    viewportPointsCache = {}
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer and (playersInRange[plr] or Box3D_Enabled) then
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                
                if hrp and humanoid and humanoid.Health > 0 then
                    -- Получаем CFrame персонажа
                    local cf = hrp.CFrame
                    
                    -- Кешируем мировые координаты углов для 3D Box
                    local corners3D = {}
                    for i, corner in ipairs(LOCAL_CORNERS) do
                        corners3D[i] = cf:PointToWorldSpace(corner)
                    end
                    
                    -- Кешируем точки на экране
                    viewportPointsCache[plr] = {
                        head = nil,
                        boxCorners = {},
                        cf = cf,
                        hrpPos = hrp.Position
                    }
                    
                    local data = viewportPointsCache[plr]
                    
                    -- Кешируем голову для текстовых ESP
                    local head = char:FindFirstChild("Head")
                    if head then
                        local headPos = Camera:WorldToViewportPoint(head.Position)
                        data.head = {
                            pos = Vector2.new(headPos.X, headPos.Y),
                            visible = headPos.Z > 0,
                            z = headPos.Z
                        }
                    end
                    
                    -- Кешируем углы для 3D Box ESP
                    if Box3D_Enabled then
                        data.boxCorners = {}
                        local anyVisible = false
                        
                        for i = 1, 8 do
                            local screenPoint = Camera:WorldToViewportPoint(corners3D[i])
                            data.boxCorners[i] = {
                                pos = Vector2.new(screenPoint.X, screenPoint.Y),
                                visible = screenPoint.Z > 0,
                                z = screenPoint.Z
                            }
                            
                            if screenPoint.Z > 0 then
                                anyVisible = true
                            end
                        end
                        
                        data.anyVisible = anyVisible
                    end
                end
            end
        end
    end
end

-- Обновление 3D Box ESP
local function updateBox3D()
    if not Box3D_Enabled then
        for plr in pairs(Box3D_Cache) do
            hideBox3D(plr)
        end
        return
    end
    
    for plr, data in pairs(viewportPointsCache) do
        if data.anyVisible and data.boxCorners then
            -- Проверяем, есть ли бокс в кеше, если нет - создаем
            if not Box3D_Cache[plr] then
                createBox3DForPlayer(plr)
            end
            
            local boxData = Box3D_Cache[plr]
            local color = isFriend(plr) and Settings.Box3D_Friend_Color or Settings.Box3D_Color
            
            -- Рисуем все 12 линий
            for lineIdx, connection in ipairs(BOX_CONNECTIONS) do
                local point1 = data.boxCorners[connection[1]]
                local point2 = data.boxCorners[connection[2]]
                local line = boxData.lines[lineIdx]
                
                if point1 and point2 and point1.visible and point2.visible then
                    line.From = point1.pos
                    line.To = point2.pos
                    line.Color = color
                    line.Visible = true
                else
                    line.Visible = false
                end
            end
            
            boxData.visible = true
            boxData.color = color
        elseif Box3D_Cache[plr] then
            hideBox3D(plr)
        end
    end
end

-- Обновление текстовых ESP
local function updateTextESP(plr)
    if not playersInRange[plr] then
        hidePlayerESP(plr)
        return
    end
    
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or char.Humanoid.Health <= 0 then
        cleanupPlayerESP(plr)
        return
    end
    
    -- Если ESP объектов нет - создаем их
    if not ESP_HPText[plr] and not ESP_NameText[plr] and not ESP_WeaponText[plr] then
        createESPObjects(plr)
    end
    
    local data = viewportPointsCache[plr]
    if not data or not data.head or not data.head.visible then
        hidePlayerESP(plr)
        return
    end
    
    local color = isFriend(plr) and Settings.ESP_Color or Settings.ESP_Color
    local headPos = data.head.pos
    
    -- Обновляем текстовые ESP
    if ESP_HPEnabled and ESP_HPText[plr] then
        local hp = math.clamp(char.Humanoid.Health, 0, char.Humanoid.MaxHealth)
        local hpColor = ESP_HPDynamicEnabled and Color3.fromHSV((hp/char.Humanoid.MaxHealth)/3,1,1) or color
        ESP_HPText[plr].Position = Vector2.new(headPos.X + 20, headPos.Y)
        ESP_HPText[plr].Text = math.floor(hp) .. " HP"
        ESP_HPText[plr].Color = hpColor
        ESP_HPText[plr].Visible = true
    elseif ESP_HPText[plr] then
        ESP_HPText[plr].Visible = false
    end
    
    if ESP_NameEnabled and ESP_NameText[plr] then
        ESP_NameText[plr].Position = Vector2.new(headPos.X, headPos.Y - 15)
        ESP_NameText[plr].Text = plr.Name
        ESP_NameText[plr].Color = color
        ESP_NameText[plr].Visible = true
    elseif ESP_NameText[plr] then
        ESP_NameText[plr].Visible = false
    end
    
    if ESP_WeaponEnabled and ESP_WeaponText[plr] then
        local tool = char:FindFirstChildOfClass("Tool")
        ESP_WeaponText[plr].Position = Vector2.new(headPos.X, headPos.Y + 15)
        ESP_WeaponText[plr].Text = tool and tool.Name or "None"
        ESP_WeaponText[plr].Color = color
        ESP_WeaponText[plr].Visible = true
    elseif ESP_WeaponText[plr] then
        ESP_WeaponText[plr].Visible = false
    end
end

-- Инициализация игроков
local function initPlayer(plr)
    if plr == localPlayer then return end
    
    plr.CharacterAdded:Connect(function(char)
        cleanupPlayerESP(plr)
    end)
end

for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= localPlayer then
        initPlayer(plr)
    end
end

Players.PlayerAdded:Connect(function(plr)
    if plr ~= localPlayer then
        initPlayer(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    cleanupPlayerESP(plr)
end)

--==================== Fullbright ====================
local fullbrightEnabled = false
local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient
}

local targetLighting = {
    Brightness = 2,
    ClockTime = 14,
    FogEnd = 100000,
    GlobalShadows = false,
    Ambient = Color3.fromRGB(255,255,255)
}

local function enableFullbright()
    for k, v in pairs(targetLighting) do
        Lighting[k] = v
    end
end

local function disableFullbright()
    for k, v in pairs(originalLighting) do
        Lighting[k] = v
    end
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

-- ESP Tab
local Box3DToggle = ESPTab:CreateToggle({
    Name = "3D Box ESP",
    CurrentValue = false,
    Flag = "Box3DToggle",
    Callback = function(Value)
        Box3D_Enabled = Value
        
        -- Если выключаем - скрываем все боксы
        if not Value then
            for plr in pairs(Box3D_Cache) do
                hideBox3D(plr)
            end
        end
        
        Rayfield:Notify({
            Title = "3D Box ESP",
            Content = Value and "Enabled" or "Disabled",
            Duration = 1,
            Image = 4483362458,
        })
    end,
})

local Box3DColorPicker = ESPTab:CreateColorPicker({
    Name = "3D Box Color",
    Color = Settings.Box3D_Color,
    Flag = "Box3DColor",
    Callback = function(Value)
        Settings.Box3D_Color = Value
        
        -- Обновляем цвет всех существующих 3D боксов
        for plr, boxData in pairs(Box3D_Cache) do
            if boxData.visible then
                local color = isFriend(plr) and Settings.Box3D_Friend_Color or Settings.Box3D_Color
                for _, line in ipairs(boxData.lines) do
                    line.Color = color
                end
                boxData.color = color
            end
        end
    end
})

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
    Name = "Text ESP Color",
    Color = Settings.ESP_Color,
    Flag = "ESPColor",
    Callback = function(Value)
        Settings.ESP_Color = Value
        
        -- Обновляем цвет всех существующих текстовых ESP
        for plr in pairs(ESP_HPText) do
            if ESP_HPText[plr] and ESP_HPText[plr].Visible then
                ESP_HPText[plr].Color = Settings.ESP_Color
            end
        end
        
        for plr in pairs(ESP_NameText) do
            if ESP_NameText[plr] and ESP_NameText[plr].Visible then
                ESP_NameText[plr].Color = Settings.ESP_Color
            end
        end
        
        for plr in pairs(ESP_WeaponText) do
            if ESP_WeaponText[plr] and ESP_WeaponText[plr].Visible then
                ESP_WeaponText[plr].Color = Settings.ESP_Color
            end
        end
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
local FullbrightToggle = MiscTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "FullbrightToggle",
    Callback = function(Value)
        fullbrightEnabled = Value
        if Value then
            enableFullbright()
        else
            disableFullbright()
        end
    end,
})

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

    -- Aimlock и Autofire
    if aimbotEnabled and keyHeld then
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
    cacheViewportPointsForFrame()
    
    -- 3. Обновляем 3D Box ESP
    updateBox3D()
    
    -- 4. Обновляем текстовые ESP
    for plr in pairs(playersInRange) do
        if playersInRange[plr] then
            updateTextESP(plr)
        elseif ESP_HPText[plr] then
            hidePlayerESP(plr)
        end
    end
end)

-- Initialize UI
Rayfield:LoadConfiguration()
