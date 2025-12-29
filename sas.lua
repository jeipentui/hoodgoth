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

-- Silent Aim Module
local Aiming = nil
local silentAimHook = nil
local isSilentAimEnabled = false

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
local smoothness = 1.0
local hitChance = 100
local triggerbotDelay = 0.1
local bodyParts = {"Head", "HumanoidRootPart", "Torso"}
local selectedBodyPart = "Head"
local FriendList = {}

-- Настройки биндов
local aimlockKey = nil
local aimlockKeyName = "Not Set"
local isRecordingKeybind = false

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

--==================== NoFall Variables ====================
local isNoFallEnabled = false
local noFallConnection = nil

--==================== Функции для Silent Aim ====================
local function setupSilentAim()
    local success, err = pcall(function()
        Aiming = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/ROBLOX/master/Universal/Aiming/Module.lua"))()
        Aiming.TeamCheck(false)
        
        -- Настройки Silent Aim
        Aiming.Settings.SilentAim = true
        Aiming.Settings.VisibleCheck = wallCheckEnabled
        Aiming.Settings.FOV = fov
        Aiming.Settings.HitChance = hitChance
        Aiming.Settings.TargetPart = selectedBodyPart
        
        print("[Silent Aim] Модуль загружен успешно")
        return true
    end)
    
    if not success then
        print("[Silent Aim] Ошибка загрузки:", err)
        Rayfield:Notify({
            Title = "Silent Aim Error",
            Content = "Не удалось загрузить модуль Silent Aim",
            Duration = 3,
            Image = 4483362458,
        })
        return false
    end
    return success
end

local function enableSilentAim()
    if not Aiming and not setupSilentAim() then
        return false
    end
    
    if silentAimHook then
        return true -- Уже включен
    end
    
    local __index
    __index = hookmetamethod(game, "__index", function(t, k)
        -- Проверяем, обращаются ли к позиции мыши
        if isSilentAimEnabled and t:IsA("Mouse") and (k == "X" or k == "Y") then
            local callingScript = getcallingscript()
            
            -- Пропускаем скрипты мыши (чтобы не сломать UI)
            if callingScript and tostring(callingScript) == "MouseScript" then
                return __index(t, k)
            end
            
            -- Проверяем, можем ли использовать Silent Aim
            if Aiming and Aiming.Check() then
                local targetPart = Aiming.SelectedPart
                if targetPart then
                    local vector, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
                    
                    if onScreen then
                        -- Возвращаем подмененные координаты
                        return (k == "X" and vector.X or vector.Y)
                    end
                end
            end
        end
        
        -- Возвращаем оригинальное значение
        return __index(t, k)
    end)
    
    silentAimHook = __index
    isSilentAimEnabled = true
    print("[Silent Aim] Активирован через хук")
    return true
end

local function disableSilentAim()
    isSilentAimEnabled = false
    
    if silentAimHook then
        -- Восстанавливаем оригинальный метаметод
        hookmetamethod(game, "__index", silentAimHook)
        silentAimHook = nil
        print("[Silent Aim] Деактивирован")
    end
    
    if Aiming then
        Aiming.Settings.SilentAim = false
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

-- Silent Aim Toggle
local SilentAimToggle = RageTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Flag = "SilentAimToggle",
    Callback = function(Value)
        if Value then
            if enableSilentAim() then
                Rayfield:Notify({
                    Title = "Silent Aim",
                    Content = "Silent Aim активирован",
                    Duration = 2,
                    Image = 4483362458,
                })
            else
                SilentAimToggle:Set(false)
            end
        else
            disableSilentAim()
            Rayfield:Notify({
                Title = "Silent Aim",
                Content = "Silent Aim деактивирован",
                Duration = 2,
                Image = 4483362458,
            })
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
        
        Rayfield:Notify({
            Title = "Recording Keybind",
            Content = "Press any keyboard key to set as aimlock key",
            Duration = 3,
            Image = 4483362458,
        })
        
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
        if Aiming then
            Aiming.Settings.VisibleCheck = Value
        end
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
        if Aiming then
            Aiming.Settings.FOV = Value
        end
    end,
})

local SmoothnessSlider = RageTab:CreateSlider({
    Name = "Smoothness",
    Range = {0.1, 10.0},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1.0,
    Flag = "SmoothnessSlider",
    Callback = function(Value)
        smoothness = Value
    end,
})

local HitChanceSlider = RageTab:CreateSlider({
    Name = "Hit Chance",
    Range = {0, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 100,
    Flag = "HitChanceSlider",
    Callback = function(Value)
        hitChance = Value
        if Aiming then
            Aiming.Settings.HitChance = Value
        end
    end,
})

-- Выбор части тела
local BodyPartDropdown = RageTab:CreateDropdown({
    Name = "Aimbot Body Part",
    Options = {"Head", "HumanoidRootPart", "Torso"},
    CurrentOption = "Head",
    Flag = "BodyPartDropdown",
    Callback = function(Option)
        selectedBodyPart = Option
        if Aiming then
            Aiming.Settings.TargetPart = Option
        end
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
            local newOrigin = result.Position + rayDir * 0.1
            local remainingDistance = rayDistance - (newOrigin - rayOrigin).Magnitude
            
            if remainingDistance > 0 then
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

-- Получение ближайшей цели к курсору
local function getNearestToCursor()
    local nearest = nil
    local minDist = fov
    local mousePos = UIS:GetMouseLocation()
    local localChar = localPlayer.Character
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild(selectedBodyPart) or char:FindFirstChild("Head")
                if head then
                    local pos, onscreen = Camera:WorldToScreenPoint(head.Position)
                    if onscreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist < minDist then
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

-- Функция для получения/обновления цели
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

--==================== NoFall Function ====================
local function startNoFall()
    if isNoFallEnabled then return end
    isNoFallEnabled = true
    
    print("[NoFall] Активирован")
    
    if noFallConnection then
        noFallConnection:Disconnect()
        noFallConnection = nil
    end
    
    noFallConnection = RunService.Heartbeat:Connect(function()
        if not isNoFallEnabled then return end
        
        local player = game.Players.LocalPlayer
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not hrp then return end
        
        if humanoid.SeatPart then
            pcall(function() humanoid.PlatformStand = false end)
            return
        end
        
        local verticalVelocity = hrp.Velocity.Y
        
        if verticalVelocity < -50 then
            pcall(function() humanoid.PlatformStand = true end)
            
            local position = hrp.Position
            hrp.CFrame = CFrame.new(position.X, position.Y, position.Z)
            hrp.Velocity = Vector3.new(0, verticalVelocity, 0)
        else
            pcall(function() humanoid.PlatformStand = false end)
        end
        
        if humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
    end)
end

local function stopNoFall()
    isNoFallEnabled = false
    
    local player = game.Players.LocalPlayer
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            pcall(function() humanoid.PlatformStand = false end)
        end
    end
    
    if noFallConnection then
        noFallConnection:Disconnect()
        noFallConnection = nil
    end
    
    print("[NoFall] Деактивирован")
end

--==================== Input ====================
UIS.InputBegan:Connect(function(input, gameProcessed)
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
        
        if Window.ConfigurationSaving.Enabled then
            local config = Window:GetConfiguration()
            config.AimlockKey = aimlockKeyName
            Window:SetConfiguration(config)
        end
        
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
local characterCache = {}
local viewportCache = {}

local playersInRange = {}
local lastDistanceCheck = 0
local DISTANCE_CHECK_INTERVAL = 0.2

-- Функция для полной очистки ESP игрока
local function cleanupPlayerESP(plr)
    if ESP_HPText[plr] then
        ESP_HPText[plr]:Remove()
        ESP_HPText[plr] = nil
    end
    
    if ESP_NameText[plr] then
        ESP_NameText[plr]:Remove()
        ESP_NameText[plr] = nil
    end
    
    if ESP_WeaponText[plr] then
        ESP_WeaponText[plr]:Remove()
        ESP_WeaponText[plr] = nil
    end
    
    if ESP_Boxes[plr] then
        if ESP_Boxes[plr].box then
            ESP_Boxes[plr].box:Remove()
        end
        if ESP_Boxes[plr].boxoutline then
            ESP_Boxes[plr].boxoutline:Remove()
        end
        ESP_Boxes[plr] = nil
    end
    
    partCache[plr] = nil
    characterCache[plr] = nil
    viewportCache[plr] = nil
    playersInRange[plr] = nil
end

-- Остальные функции ESP остаются такими же...

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
        stopNoFall()
        disableSilentAim()
        
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
    -- FOV Circle
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
