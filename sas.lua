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
local currentTarget = nil
local lastTargetTime = 0
local targetLockDelay = 0.05 -- 50ms задержка для стабильности

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

-- Функция проверки находится ли цель в FOV
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

-- Проверка видимости цели (wallcheck)
local function isTargetVisible(targetHead, localChar)
    if not wallCheckEnabled then return true end
    
    if not targetHead or not localChar then return false end
    
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
            local newOrigin = result.Position + rayDir * 0.1
            local remainingDistance = rayDistance - (newOrigin - rayOrigin).Magnitude
            
            if remainingDistance > 0 then
                -- Добавляем DFrame в игнор для второго raycast
                local newBlacklist = {localChar, targetHead.Parent, hit}
                rayParams.FilterDescendantsInstances = newBlacklist
                
                local secondResult = workspace:Raycast(newOrigin, rayDir * remainingDistance, rayParams)
                
                if not secondResult then
                    return true
                else
                    local secondHit = secondResult.Instance
                    return secondHit == targetHead or secondHit:IsDescendantOf(targetHead)
                end
            else
                return true
            end
        end
        
        return false
    end
end

-- Проверка валидности цели
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

-- Получение ближайшей цели к курсору (БЫСТРОЕ)
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
                    -- 1. Быстрая проверка позиции на экране
                    local pos, onscreen = Camera:WorldToScreenPoint(head.Position)
                    if onscreen then
                        -- 2. Проверка FOV
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist < minDist then
                            -- 3. Проверяем валидность цели
                            if isValidTarget(plr, head) then
                                -- 4. Проверяем видимость
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

-- Функция для получения цели (БЫСТРАЯ)
local function getTarget()
    -- Если у нас уже есть цель и она все еще валидна
    if currentTarget and tick() - lastTargetTime < targetLockDelay then
        local plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
        
        if not plr then
            currentTarget = nil
            return nil
        end
        
        -- Быстрая проверка FOV
        if isTargetInFOV(currentTarget) then
            if isValidTarget(plr, currentTarget) then
                if isTargetVisible(currentTarget, localPlayer.Character) then
                    return currentTarget
                end
            end
        end
        
        currentTarget = nil
        return nil
    end
    
    -- Ищем новую цель
    local newTarget = getNearestToCursor()
    if newTarget then
        currentTarget = newTarget
        lastTargetTime = tick()
    end
    
    return currentTarget
end

--==================== Input ====================
UIS.InputBegan:Connect(function(i,g)
    if not g and i.KeyCode == Enum.KeyCode.X then 
        keyHeld = true 
        -- При нажатии на клавишу сразу ищем новую цель
        if aimbotEnabled then
            currentTarget = nil
            lastTargetTime = 0
        end
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.X then 
        keyHeld = false 
        -- При отпускании клавиши сбрасываем цель
        currentTarget = nil
    end
end)

--==================== ESP System ====================
local ESP_HPEnabled = false
local Box_ESP_Enabled = false
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
end

-- Функция для проверки, нужно ли создать ESP
local function shouldCreateESP(plr)
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    
    local hrp = char.HumanoidRootPart
    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    
    return dist <= ESP_MaxDistance
end

-- Функция для получения углов 3D бокса
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

--==================== Update ESP ====================
local function UpdateESP(plr)
    -- Проверяем, включен ли вообще какой-либо ESP
    local hasAnyESP = ESP_HPEnabled or ESP_NameEnabled or ESP_WeaponEnabled or Box_ESP_Enabled
    
    if not hasAnyESP then
        if ESP_HPText[plr] then
            hidePlayerESP(plr)
        end
        return
    end
    
    local char = plr.Character
    if not char then
        -- Удаляем ESP если нет персонажа
        if ESP_HPText[plr] then
            cleanupPlayerESP(plr)
        end
        return
    end
    
    local humanoid = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not hrp or humanoid.Health <= 0 then
        -- Удаляем ESP если игрок мертв
        if ESP_HPText[plr] then
            cleanupPlayerESP(plr)
        end
        return
    end
    
    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    
    -- Если игрок ВНЕ зоны видимости
    if dist > ESP_MaxDistance then
        -- Если у него есть ESP объекты - скрываем их
        if ESP_HPText[plr] then
            hidePlayerESP(plr)
        end
        return
    end
    
    -- Если игрок В зоне видимости, но ESP объектов нет - создаем их
    if not ESP_HPText[plr] then
        createESPObjects(plr)
    end
    
    -- Получаем позицию головы на экране
    local head = char:FindFirstChild("Head")
    if not head then
        hidePlayerESP(plr)
        return
    end
    
    local headPos, onscreen = Camera:WorldToViewportPoint(head.Position)
    if not onscreen then
        hidePlayerESP(plr)
        return
    end
    
    local color = isFriend(plr) and Settings.Friend_Color or Settings.ESP_Color
    local hpText = ESP_HPText[plr]
    local nameText = ESP_NameText[plr]
    local weaponText = ESP_WeaponText[plr]
    local boxes = ESP_Boxes[plr]
    
    local screenPos = Vector2.new(headPos.X, headPos.Y)
    
    -- HP Text
    if ESP_HPEnabled and hpText then
        local hp = math.clamp(humanoid.Health, 0, humanoid.MaxHealth)
        local hpColor = ESP_HPDynamicEnabled and Color3.fromHSV((hp/humanoid.MaxHealth)/3,1,1) or color
        hpText.Position = Vector2.new(screenPos.X + 20, screenPos.Y)
        hpText.Text = math.floor(hp) .. " HP"
        hpText.Color = hpColor
        hpText.Visible = true
    elseif hpText then
        hpText.Visible = false
    end
    
    -- Name Text
    if ESP_NameEnabled and nameText then
        nameText.Position = Vector2.new(screenPos.X, screenPos.Y - 15)
        nameText.Text = plr.Name
        nameText.Color = color
        nameText.Visible = true
    elseif nameText then
        nameText.Visible = false
    end
    
    -- Weapon Text
    if ESP_WeaponEnabled and weaponText then
        local tool = char:FindFirstChildOfClass("Tool")
        weaponText.Position = Vector2.new(screenPos.X, screenPos.Y + 15)
        weaponText.Text = tool and tool.Name or "None"
        weaponText.Color = color
        weaponText.Visible = true
    elseif weaponText then
        weaponText.Visible = false
    end

    -- Box ESP
    if Box_ESP_Enabled and boxes then
        local corners = get3DBoxCorners(hrp)
        local minX, minY, maxX, maxY = 9e9, 9e9, -9e9, -9e9
        local anyVisible = false
        
        for i = 1, 4 do
            local cornerPos, cornerVisible = Camera:WorldToViewportPoint(corners[i])
            if cornerVisible and cornerPos.Z > 0 then
                anyVisible = true
                local x, y = cornerPos.X, cornerPos.Y
                minX = math.min(minX, x)
                minY = math.min(minY, y)
                maxX = math.max(maxX, x)
                maxY = math.max(maxY, y)
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
    elseif boxes then
        boxes.box.Visible = false
        boxes.boxoutline.Visible = false
    end
end

--==================== Инициализация игроков ====================
local function initPlayer(plr)
    if plr == localPlayer then return end
    
    -- Подключаем обработчик изменения персонажа
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5) -- Даем время на загрузку
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
    Color = Color3.fromRGB(255,0,0),
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
local espUpdateTime = 0
local espUpdateInterval = 0.033 -- ~30 FPS для ESP

RunService.RenderStepped:Connect(function()
    -- FOV Circle
    if showFOV then
        local mousePos = UIS:GetMouseLocation()
        if mousePos ~= lastMousePos or fov ~= lastFOV then
            fovCircle.Position = mousePos
            fovCircle.Radius = fov
            fovCircle.Visible = true
            lastMousePos = mousePos
            lastFOV = fov
        end
    else
        fovCircle.Visible = false
    end

    -- Aimlock и Autofire - МГНОВЕННЫЙ ОТКЛИК
    if aimbotEnabled and keyHeld then
        local targetHead = getTarget()
        
        if targetHead then
            local plr = Players:GetPlayerFromCharacter(targetHead.Parent)
            local validTarget = plr and isValidTarget(plr, targetHead)
            
            if validTarget then
                -- Немедленно целимся
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, getPredictedPosition(targetHead))
                
                if autofireEnabled then
                    currentTool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
                    if currentTool then 
                        currentTool:Activate() 
                    end
                end
            else
                currentTarget = nil
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
        currentTarget = nil
        if currentTool then 
            currentTool:Deactivate() 
            currentTool = nil 
        end
    end

    -- ESP Update с интервалом для производительности
    local now = tick()
    if now - espUpdateTime >= espUpdateInterval then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= localPlayer and plr.Parent then
                UpdateESP(plr)
            end
        end
        espUpdateTime = now
    end
end)

-- Initialize UI
Rayfield:LoadConfiguration()
