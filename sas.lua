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

-- Локальные ссылки для оптимизации
local table_insert = table.insert
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local Vector2_new = Vector2.new

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
    KeySystem = false
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
local currentTarget = nil
local targetLocked = false

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = fovColor
fovCircle.Thickness = 1
fovCircle.NumSides = 32

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

local function isTargetDowned(targetCharacter)
    if not targetCharacter then return false end
    local targetName = targetCharacter.Name
    local charStat = CharStats:FindFirstChild(targetName)
    if not charStat then return false end
    local downedValue = charStat:FindFirstChild("Downed")
    return downedValue and downedValue:IsA("BoolValue") and downedValue.Value
end

local function hasSpawnShield(plr)
    return plr.Character and plr.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function isTargetInFOV(targetPos)
    if not targetPos then return false end
    local mousePos = UIS:GetMouseLocation()
    local dist = (targetPos - mousePos).Magnitude
    return dist <= fov
end

local function getPredictedPosition(target)
    local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then return target.Position end
    local dir = hrp.Position - Camera.CFrame.Position
    local dist = dir.Magnitude
    local t = dist / getCurrentWeaponSpeed()
    return target.Position + hrp.Velocity * t
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = true

local function isTargetVisible(targetHead, localChar)
    if not wallCheckEnabled then return true end
    if not targetHead or not localChar then return false end
    
    local rayOrigin = Camera.CFrame.Position
    local rayDir = targetHead.Position - rayOrigin
    local rayDistance = rayDir.Magnitude
    rayDir = rayDir.Unit
    
    rayParams.FilterDescendantsInstances = {localChar, targetHead.Parent}
    local result = workspace:Raycast(rayOrigin, rayDir * rayDistance, rayParams)
    
    if not result then return true end
    
    local hit = result.Instance
    if hit == targetHead or hit:IsDescendantOf(targetHead) then return true end
    
    if hit.Name == "DFrame" then
        local newOrigin = result.Position + rayDir * 0.1
        local remainingDistance = rayDistance - (newOrigin - rayOrigin).Magnitude
        
        if remainingDistance > 0 then
            local newBlacklist = {localChar, targetHead.Parent, hit}
            rayParams.FilterDescendantsInstances = newBlacklist
            local secondResult = workspace:Raycast(newOrigin, rayDir * remainingDistance, rayParams)
            
            return not secondResult or (secondResult.Instance == targetHead or secondResult.Instance:IsDescendantOf(targetHead))
        end
        return true
    end
    
    return false
end

local function isValidTarget(plr, targetHead)
    if not plr or not plr.Character or isFriend(plr) or not targetHead then return false end
    local char = plr.Character
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 or hasSpawnShield(plr) then return false end
    return not isTargetDowned(char)
end

-- Оптимизированная функция получения ближайшей цели
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
                    local pos, onscreen = Camera:WorldToScreenPoint(head.Position)
                    if onscreen then
                        local dist = (Vector2_new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist < minDist and dist <= fov then
                            if isValidTarget(plr, head) then
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

local function getTarget()
    if currentTarget and targetLocked then
        local plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
        
        if not plr then
            currentTarget = nil
            targetLocked = false
            return nil
        end
        
        if isTargetInFOV(currentTarget) then
            if isValidTarget(plr, currentTarget) then
                if isTargetVisible(currentTarget, localPlayer.Character) then
                    return currentTarget
                end
            end
        end
        
        currentTarget = nil
        targetLocked = false
        return nil
    end
    
    if not currentTarget then
        local newTarget = getNearestToCursor()
        if newTarget then
            currentTarget = newTarget
            targetLocked = true
        end
    end
    
    return currentTarget
end

UIS.InputBegan:Connect(function(i,g)
    if not g and i.KeyCode == Enum.KeyCode.X then 
        keyHeld = true 
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
        end
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.X then 
        keyHeld = false 
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
        end
    end
end)

--==================== ESP System (ОПТИМИЗИРОВАННЫЙ) ====================
local ESP_HPEnabled = false
local Box_ESP_Enabled = false
local ESP_NameEnabled = false
local ESP_HPDynamicEnabled = false
local ESP_WeaponEnabled = false
local ESP_MaxDistance = 1500
local Settings = {ESP_Color=Color3.fromRGB(255,0,0), Friend_Color=Color3.fromRGB(0,255,0)}

local ESP_HPText = {}
local ESP_NameText = {}
local ESP_WeaponText = {}
local ESP_Boxes = {}
local partCache = {}
local characterCache = {}
local PlayerList = {} -- Массив для быстрого доступа

-- Оптимизация №2: Создание ESP объектов один раз, без удаления
local function createESPObjects(plr)
    if ESP_HPText[plr] then return end -- Уже создано
    
    local hpText = Drawing.new("Text")
    hpText.Visible = false
    hpText.Color = Settings.ESP_Color
    hpText.Size = 14
    hpText.Center = true
    hpText.Outline = true
    ESP_HPText[plr] = hpText
    
    local nameText = Drawing.new("Text")
    nameText.Visible = false
    nameText.Color = Settings.ESP_Color
    nameText.Size = 9
    nameText.Center = true
    nameText.Outline = true
    ESP_NameText[plr] = nameText
    
    local weaponText = Drawing.new("Text")
    weaponText.Visible = false
    weaponText.Color = Settings.ESP_Color
    weaponText.Size = 12
    weaponText.Center = true
    weaponText.Outline = true
    ESP_WeaponText[plr] = weaponText
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1
    box.Color = Settings.ESP_Color
    
    local boxoutline = Drawing.new("Square")
    boxoutline.Visible = false
    boxoutline.Thickness = 1
    boxoutline.Color = Settings.ESP_Color
    
    ESP_Boxes[plr] = {box = box, boxoutline = boxoutline}
    
    -- Оптимизация №4: Кеширование частей персонажа
    local function cacheParts(char)
        partCache[plr] = {}
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    table_insert(partCache[plr], part)
                end
            end
        end
    end
    
    characterCache[plr] = plr.Character
    if plr.Character then
        cacheParts(plr.Character)
    end
end

-- Оптимизация №2: Только скрываем, не удаляем
local function hidePlayerESP(plr)
    if ESP_HPText[plr] then ESP_HPText[plr].Visible = false end
    if ESP_NameText[plr] then ESP_NameText[plr].Visible = false end
    if ESP_WeaponText[plr] then ESP_WeaponText[plr].Visible = false end
    if ESP_Boxes[plr] then
        ESP_Boxes[plr].box.Visible = false
        ESP_Boxes[plr].boxoutline.Visible = false
    end
end

-- Оптимизация №9: Перехват добавления/удаления игроков
local function initPlayer(plr)
    if plr == localPlayer then return end
    
    table_insert(PlayerList, plr)
    createESPObjects(plr)
    
    -- Оптимизация №4: Обработчик изменения персонажа
    plr.CharacterAdded:Connect(function(char)
        characterCache[plr] = char
        partCache[plr] = {}
        
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    table_insert(partCache[plr], part)
                end
            end
        end
    end)
end

-- Инициализируем существующих игроков
for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= localPlayer then
        initPlayer(plr)
    end
end

-- Оптимизация №9: Обработчики добавления/удаления игроков
Players.PlayerAdded:Connect(function(plr)
    if plr ~= localPlayer then
        initPlayer(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    -- Удаляем из массива
    for i = #PlayerList, 1, -1 do
        if PlayerList[i] == plr then
            table.remove(PlayerList, i)
            break
        end
    end
    
    -- Скрываем ESP
    hidePlayerESP(plr)
    
    -- Очищаем кеш
    ESP_HPText[plr] = nil
    ESP_NameText[plr] = nil
    ESP_WeaponText[plr] = nil
    ESP_Boxes[plr] = nil
    partCache[plr] = nil
    characterCache[plr] = nil
end)

local function shouldCreateESP(plr)
    local char = plr.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    return dist <= ESP_MaxDistance
end

local function UpdateESP(plr)
    -- Проверяем, включен ли вообще какой-либо ESP
    if not ESP_HPEnabled and not ESP_NameEnabled and not ESP_WeaponEnabled and not Box_ESP_Enabled then
        hidePlayerESP(plr)
        return
    end
    
    local char = characterCache[plr]
    if not char then
        hidePlayerESP(plr)
        return
    end
    
    local humanoid = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp or humanoid.Health <= 0 then
        hidePlayerESP(plr)
        return
    end
    
    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
    if dist > ESP_MaxDistance then
        hidePlayerESP(plr)
        return
    end
    
    local head = char:FindFirstChild("Head")
    if not head then
        hidePlayerESP(plr)
        return
    end
    
    -- Оптимизация №3: Один вызов WorldToViewportPoint
    local headPos, onscreen = Camera:WorldToViewportPoint(head.Position)
    if not onscreen then
        hidePlayerESP(plr)
        return
    end
    
    local color = isFriend(plr) and Settings.Friend_Color or Settings.ESP_Color
    local screenPos = Vector2_new(headPos.X, headPos.Y)
    
    -- HP Text
    if ESP_HPEnabled and ESP_HPText[plr] then
        local hp = math_clamp(humanoid.Health, 0, humanoid.MaxHealth)
        local hpColor = ESP_HPDynamicEnabled and Color3.fromHSV((hp/humanoid.MaxHealth)/3,1,1) or color
        ESP_HPText[plr].Position = Vector2_new(screenPos.X + 20, screenPos.Y)
        ESP_HPText[plr].Text = math_floor(hp) .. " HP"
        ESP_HPText[plr].Color = hpColor
        ESP_HPText[plr].Visible = true
    elseif ESP_HPText[plr] then
        ESP_HPText[plr].Visible = false
    end
    
    -- Name Text
    if ESP_NameEnabled and ESP_NameText[plr] then
        ESP_NameText[plr].Position = Vector2_new(screenPos.X, screenPos.Y - 15)
        ESP_NameText[plr].Text = plr.Name
        ESP_NameText[plr].Color = color
        ESP_NameText[plr].Visible = true
    elseif ESP_NameText[plr] then
        ESP_NameText[plr].Visible = false
    end
    
    -- Weapon Text
    if ESP_WeaponEnabled and ESP_WeaponText[plr] then
        local tool = char:FindFirstChildOfClass("Tool")
        ESP_WeaponText[plr].Position = Vector2_new(screenPos.X, screenPos.Y + 15)
        ESP_WeaponText[plr].Text = tool and tool.Name or "None"
        ESP_WeaponText[plr].Color = color
        ESP_WeaponText[plr].Visible = true
    elseif ESP_WeaponText[plr] then
        ESP_WeaponText[plr].Visible = false
    end

    -- Box ESP
    if Box_ESP_Enabled and ESP_Boxes[plr] then
        local cf = hrp.CFrame
        local size = Vector3.new(4, 6, 1.5)
        local corners = {
            cf * Vector3.new(-size.X/2, size.Y/2, 0),
            cf * Vector3.new(size.X/2, size.Y/2, 0),
            cf * Vector3.new(-size.X/2,-size.Y/2, 0),
            cf * Vector3.new(size.X/2,-size.Y/2, 0)
        }
        
        local minX, minY, maxX, maxY = 9e9, 9e9, -9e9, -9e9
        local anyVisible = false
        
        for i = 1, 4 do
            local pos, visible = Camera:WorldToViewportPoint(corners[i])
            if visible and pos.Z > 0 then
                anyVisible = true
                minX = math_min(minX, pos.X)
                minY = math_min(minY, pos.Y)
                maxX = math_max(maxX, pos.X)
                maxY = math_max(maxY, pos.Y)
            end
        end
        
        if anyVisible then
            local w, h = maxX - minX, maxY - minY
            local pos = Vector2_new(minX, minY)
            
            ESP_Boxes[plr].box.Position = pos
            ESP_Boxes[plr].box.Size = Vector2_new(w, h)
            ESP_Boxes[plr].box.Color = color
            ESP_Boxes[plr].box.Visible = true
            
            ESP_Boxes[plr].boxoutline.Position = Vector2_new(pos.X - 1, pos.Y - 1)
            ESP_Boxes[plr].boxoutline.Size = Vector2_new(w + 2, h + 2)
            ESP_Boxes[plr].boxoutline.Color = color
            ESP_Boxes[plr].boxoutline.Visible = true
        else
            ESP_Boxes[plr].box.Visible = false
            ESP_Boxes[plr].boxoutline.Visible = false
        end
    elseif ESP_Boxes[plr] then
        ESP_Boxes[plr].box.Visible = false
        ESP_Boxes[plr].boxoutline.Visible = false
    end
end

--==================== UI Elements ====================
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
    Callback = function(Value) autofireEnabled = Value end,
})

local WallcheckToggle = RageTab:CreateToggle({
    Name = "Wallcheck",
    CurrentValue = true,
    Flag = "WallcheckToggle",
    Callback = function(Value) wallCheckEnabled = Value end,
})

local FOVSlider = RageTab:CreateSlider({
    Name = "FOV Aim",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 100,
    Flag = "FOVSlider",
    Callback = function(Value) fov = Value end,
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
    Callback = function(Value) fovColor = Value fovCircle.Color = Value end
})

local FriendListLabel = RageTab:CreateLabel("Friend List: " .. table.concat(FriendList, ", "))

local AddFriendInput = RageTab:CreateInput({
    Name = "Add Friend",
    PlaceholderText = "Enter username",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text ~= "" then
            table_insert(FriendList, Text)
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

local HPToggle = ESPTab:CreateToggle({
    Name = "Health ESP",
    CurrentValue = false,
    Flag = "HPToggle",
    Callback = function(Value) ESP_HPEnabled = Value end,
})

local HPDynamicToggle = ESPTab:CreateToggle({
    Name = "Dynamic Health Color",
    CurrentValue = false,
    Flag = "HPDynamicToggle",
    Callback = function(Value) ESP_HPDynamicEnabled = Value end,
})

local BoxToggle = ESPTab:CreateToggle({
    Name = "Box ESP",
    CurrentValue = false,
    Flag = "BoxToggle",
    Callback = function(Value) Box_ESP_Enabled = Value end,
})

local NameToggle = ESPTab:CreateToggle({
    Name = "Name ESP",
    CurrentValue = false,
    Flag = "NameToggle",
    Callback = function(Value) ESP_NameEnabled = Value end,
})

local WeaponToggle = ESPTab:CreateToggle({
    Name = "Weapon ESP",
    CurrentValue = false,
    Flag = "WeaponToggle",
    Callback = function(Value) ESP_WeaponEnabled = Value end,
})

local ESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.fromRGB(255,0,0),
    Flag = "ESPColor",
    Callback = function(Value) Settings.ESP_Color = Value end
})

local ESPDistanceSlider = ESPTab:CreateSlider({
    Name = "Max ESP Distance",
    Range = {1, 1500},
    Increment = 50,
    Suffix = "studs",
    CurrentValue = 1500,
    Flag = "ESPDistance",
    Callback = function(Value) ESP_MaxDistance = Value end,
})

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
            if ESP_HPText[plr] then
                ESP_HPText[plr]:Remove()
            end
        end
        fovCircle:Remove()
        Rayfield:Destroy()
    end,
})

--==================== Render Loop ====================
local currentTool
local espUpdateIndex = 1
local espUpdateBatch = 2 -- 2 игрока за кадр для 60 FPS

RunService.RenderStepped:Connect(function()
    -- FOV Circle
    if showFOV then
        local mousePos = UIS:GetMouseLocation()
        fovCircle.Position = mousePos
        fovCircle.Radius = fov
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
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

    -- ESP Update для 2 игроков за кадр (60 FPS)
    local playerCount = #PlayerList
    if playerCount > 0 then
        local startIndex = espUpdateIndex
        local endIndex = math.min(startIndex + espUpdateBatch - 1, playerCount)
        
        for i = startIndex, endIndex do
            local plr = PlayerList[i]
            if plr and plr.Parent then
                UpdateESP(plr)
            end
        end
        
        espUpdateIndex = endIndex + 1
        if espUpdateIndex > playerCount then
            espUpdateIndex = 1
        end
    end
end)

-- Initialize UI
Rayfield:LoadConfiguration()
