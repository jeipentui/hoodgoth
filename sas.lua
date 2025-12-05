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

-- Улучшенная проверка видимости цели (wallcheck) - НЕ целимся через стены
local function IsVisible(targetPart)
    if not targetPart then return false end
    if not wallCheckEnabled then return true end

    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local distance = direction.Magnitude
    direction = direction.Unit

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    
    -- Создаем черный список
    local blacklist = {}
    
    -- Добавляем нашего персонажа
    if localPlayer.Character then
        table.insert(blacklist, localPlayer.Character)
    end
    
    -- НЕ добавляем персонажа цели - хотим проверить, есть ли препятствия
    -- Если добавить цель в черный список, луч пройдет через нее и мы не узнаем о препятствиях
    
    params.FilterDescendantsInstances = blacklist
    params.IgnoreWater = true

    -- Делаем raycast
    local ray = workspace:Raycast(origin, direction * distance, params)

    -- Если ничего не попалось - цель видима
    if not ray then
        return true
    end

    local hit = ray.Instance
    
    -- Если луч попал прямо в цель или ее часть - цель видима
    if hit == targetPart or hit:IsDescendantOf(targetPart.Parent) then
        return true
    end
    
    -- Если попали во что-то другое - цель НЕ видима
    -- НЕ делаем исключений для прозрачных объектов и тонких частей
    return false
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

-- Получение ближайшей цели к курсору (обновленная с новой функцией видимости)
local function getNearestToCursor()
    local nearest = nil
    local minDist = fov
    local mousePos = UIS:GetMouseLocation()
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head and isValidTarget(plr, head) then
                    local pos, onscreen = Camera:WorldToScreenPoint(head.Position)
                    if onscreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist < minDist and IsVisible(head) then
                            minDist = dist
                            nearest = head
                        end
                    end
                end
            end
        end
    end

    return nearest
end

-- Функция для получения/обновления цели (обновленная с новой функцией видимости)
local function getTarget()
    -- Если у нас уже есть цель и она все еще валидна
    if currentTarget and targetLocked then
        local plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
        if plr and isValidTarget(plr, currentTarget) then
            -- Проверяем, находится ли цель все еще в FOV и видима
            if isTargetInFOV(currentTarget) and IsVisible(currentTarget) then
                return currentTarget
            else
                -- Цель вышла из FOV или стала невидимой, сбрасываем
                currentTarget = nil
                targetLocked = false
                return nil
            end
        else
            -- Цель стала невалидной
            currentTarget = nil
            targetLocked = false
            return nil
        end
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

--==================== ESP System ====================
local ESP_CornerboxEnabled = false
local ESP_HPEnabled = false
local Box_ESP_Enabled = false
local ESP_NameEnabled = false
local ESP_HPDynamicEnabled = false
local ESP_WeaponEnabled = false
local ESP_MaxDistance = 1500
local Settings = {ESP_Color=Color3.fromRGB(255,0,0), Friend_Color=Color3.fromRGB(0,255,0)}

-- Таблицы для хранения ESP объектов
local ESP_Lines = {}
local ESP_HPText = {}
local ESP_NameText = {}
local ESP_WeaponText = {}
local ESP_Boxes = {}
local partCache = {}
local characterCache = {} -- Кеш для персонажей игроков

-- Функция для полной очистки ESP игрока
local function cleanupPlayerESP(plr)
    if ESP_Lines[plr] then
        for _, line in pairs(ESP_Lines[plr]) do
            if line then
                line.Visible = false
                line:Remove()
            end
        end
        ESP_Lines[plr] = nil
    end
    
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
    
    -- Очищаем кеш частей
    partCache[plr] = nil
    characterCache[plr] = nil
end

-- Функция для создания ESP объектов
local function createESPObjects(plr)
    -- Сначала очищаем старые объекты, если они есть
    cleanupPlayerESP(plr)
    
    -- Создаем новые объекты
    local lines = {}
    local lineNames = {"TL1", "TL2", "TR1", "TR2", "BL1", "BL2", "BR1", "BR2"}
    
    for _, name in ipairs(lineNames) do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Settings.ESP_Color
        line.Thickness = 2
        lines[name] = line
    end
    
    ESP_Lines[plr] = lines
    
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
        
        -- Подключаем обработчик изменения персонажа
        plr.CharacterAdded:Connect(function(char)
            characterCache[plr] = char
            partCache[plr] = {}
            
            task.wait(0.1) -- Даем время на загрузку
            
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    partCache[plr][part] = true
                end
            end
        end)
    end
end

-- Функция для проверки, нужно ли создать ESP
local function shouldCreateESP(plr)
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or char.Humanoid.Health <= 0 then
        return false
    end
    
    local hrp = char.HumanoidRootPart
    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    
    return dist <= ESP_MaxDistance
end

--==================== Update ESP ====================
local function UpdateESP(plr)
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or char.Humanoid.Health <= 0 then
        -- Игрок мертв или нет персонажа - удаляем ESP
        if ESP_Lines[plr] then
            cleanupPlayerESP(plr)
        end
        return
    end
    
    local hrp = char.HumanoidRootPart
    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    
    -- Если игрок ВНЕ зоны видимости
    if dist > ESP_MaxDistance then
        -- Если у него есть ESP объекты - удаляем их
        if ESP_Lines[plr] then
            cleanupPlayerESP(plr)
        end
        return
    end
    
    -- Если игрок В зоне видимости, но ESP объектов нет - создаем их
    if not ESP_Lines[plr] then
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
    
    local color = isFriend(plr) and Settings.Friend_Color or Settings.ESP_Color
    local lines = ESP_Lines[plr]
    local hpText = ESP_HPText[plr]
    local nameText = ESP_NameText[plr]
    local weaponText = ESP_WeaponText[plr]
    local boxes = ESP_Boxes[plr]
    
    -- Cornerbox
    if ESP_CornerboxEnabled and lines then
        local sizeX, sizeY = 1.5, 3
        local TL3D = hrp.Position + Vector3.new(-sizeX/2, sizeY/2, 0)
        local TR3D = hrp.Position + Vector3.new(sizeX/2, sizeY/2, 0)
        local BL3D = hrp.Position + Vector3.new(-sizeX/2, -sizeY/2, 0)
        local BR3D = hrp.Position + Vector3.new(sizeX/2, -sizeY/2, 0)
        local TL, onTL = Camera:WorldToViewportPoint(TL3D)
        local TR, onTR = Camera:WorldToViewportPoint(TR3D)
        local BL, onBL = Camera:WorldToViewportPoint(BL3D)
        local BR, onBR = Camera:WorldToViewportPoint(BR3D)
        
        if onTL and onTR and onBL and onBR then
            local offset = math.clamp(1/dist*1000,5,20)
            
            lines.TL1.From, lines.TL1.To = Vector2.new(TL.X,TL.Y), Vector2.new(TL.X+offset,TL.Y)
            lines.TL2.From, lines.TL2.To = Vector2.new(TL.X,TL.Y), Vector2.new(TL.X,TL.Y-offset)
            lines.TR1.From, lines.TR1.To = Vector2.new(TR.X,TR.Y), Vector2.new(TR.X-offset,TR.Y)
            lines.TR2.From, lines.TR2.To = Vector2.new(TR.X,TR.Y), Vector2.new(TR.X,TR.Y-offset)
            lines.BL1.From, lines.BL1.To = Vector2.new(BL.X,BL.Y), Vector2.new(BL.X+offset,BL.Y)
            lines.BL2.From, lines.BL2.To = Vector2.new(BL.X,BL.Y), Vector2.new(BL.X,BL.Y+offset)
            lines.BR1.From, lines.BR1.To = Vector2.new(BR.X,BR.Y), Vector2.new(BR.X-offset,BR.Y)
            lines.BR2.From, lines.BR2.To = Vector2.new(BR.X,BR.Y), Vector2.new(BR.X,BR.Y+offset)
            
            for _, line in pairs(lines) do
                line.Visible = true
                line.Color = color
            end
        else
            for _, line in pairs(lines) do
                line.Visible = false
            end
        end
    elseif lines then
        for _, line in pairs(lines) do
            line.Visible = false
        end
    end

    -- Head Texts
    local head = char:FindFirstChild("Head")
    if head then
        local pos, onScr = Camera:WorldToViewportPoint(head.Position)
        
        -- HP Text
        if ESP_HPEnabled and hpText then
            if onScr then
                local hp = math.clamp(char.Humanoid.Health, 0, char.Humanoid.MaxHealth)
                local hpColor = ESP_HPDynamicEnabled and Color3.fromHSV((hp/char.Humanoid.MaxHealth)/3,1,1) or color
                hpText.Position = Vector2.new(pos.X + 20, pos.Y)
                hpText.Text = math.floor(hp) .. " HP"
                hpText.Color = hpColor
                hpText.Visible = true
            else
                hpText.Visible = false
            end
        elseif hpText then
            hpText.Visible = false
        end
        
        -- Name Text
        if ESP_NameEnabled and nameText then
            if onScr then
                nameText.Position = Vector2.new(pos.X, pos.Y - 15)
                nameText.Text = plr.Name
                nameText.Color = color
                nameText.Visible = true
            else
                nameText.Visible = false
            end
        elseif nameText then
            nameText.Visible = false
        end
        
        -- Weapon Text
        if ESP_WeaponEnabled and weaponText then
            if onScr then
                local tool = char:FindFirstChildOfClass("Tool")
                weaponText.Position = Vector2.new(pos.X, pos.Y + 15)
                weaponText.Text = tool and tool.Name or "None"
                weaponText.Color = color
                weaponText.Visible = true
            else
                weaponText.Visible = false
            end
        elseif weaponText then
            weaponText.Visible = false
        end
    else
        if hpText then hpText.Visible = false end
        if nameText then nameText.Visible = false end
        if weaponText then weaponText.Visible = false end
    end

    -- Box ESP
    if Box_ESP_Enabled and boxes and partCache[plr] then
        local minX, minY, maxX, maxY = 9e9, 9e9, -9e9, -9e9
        local anyVisible = false
        
        -- Обновляем позиции только кешированных частей
        for part in pairs(partCache[plr]) do
            if part.Parent == char then
                local pos = Camera:WorldToViewportPoint(part.Position)
                if pos.Z > 0 then
                    anyVisible = true
                    minX = math.min(minX, pos.X)
                    minY = math.min(minY, pos.Y)
                    maxX = math.max(maxX, pos.X)
                    maxY = math.max(maxY, pos.Y)
                end
            else
                -- Часть удалена, убираем из кеша
                partCache[plr][part] = nil
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
    
    -- Создаем ESP объекты только если игрок в зоне видимости
    if shouldCreateESP(plr) then
        createESPObjects(plr)
    end
    
    -- Подключаем обработчик смерти/возрождения
    plr.CharacterAdded:Connect(function(char)
        if shouldCreateESP(plr) then
            createESPObjects(plr)
        end
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
local CornerboxToggle = ESPTab:CreateToggle({
    Name = "Cornerbox ESP",
    CurrentValue = false,
    Flag = "CornerboxToggle",
    Callback = function(Value)
        ESP_CornerboxEnabled = Value
    end,
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
        for plr, _ in pairs(ESP_Lines) do
            cleanupPlayerESP(plr)
        end
        fovCircle:Remove()
        Rayfield:Destroy()
    end,
})

--==================== Render Loop ====================
local currentTool

RunService.RenderStepped:Connect(function()
    -- FOV Circle
    local mousePos = UIS:GetMouseLocation()
    if showFOV and (mousePos ~= lastMousePos or fov ~= lastFOV) then
        fovCircle.Position = mousePos
        fovCircle.Radius = fov
        fovCircle.Visible = true
        lastMousePos = mousePos
        lastFOV = fov
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

    -- ESP Update для всех игроков
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer and plr.Parent then
            UpdateESP(plr)
        end
    end
end)

-- Initialize UI
Rayfield:LoadConfiguration()
Rayfield:Notify({
    Title = "thw club",
    Content = "Script loaded successfully!\nСтрогий WallCheck активирован - теперь НЕ целимся через стены\nСтабильный aimlock активирован - цель будет удерживаться до выхода из FOV\nESP оптимизирован - автоматически удаляется при выходе из зоны видимости",
    Duration = 5,
    Image = 4483362458,
})
