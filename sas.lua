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
local math_clamp = math.clamp
local math_floor = math.floor
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

-- Оптимизация: Используем хэш-таблицу для быстрого поиска друзей
local FriendSet = {}

-- Добавляем переменные для стабильного aimlock
local currentTarget = nil -- Текущая цель
local targetLocked = false -- Флаг блокировки цели

-- Глобальный RaycastParams для оптимизации
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = true

-- Кеш для Raycast (оптимизация №6)
local frameRayCache = {}
local cacheCleanupTime = 0

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 32 -- Уменьшено для оптимизации
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
    return FriendSet[plr.Name] == true
end

--==================== Downed Check ====================
local downedCache = {}
local downedCacheTime = 0

local function isTargetDowned(targetCharacter)
    local now = tick()
    local cacheKey = targetCharacter and targetCharacter.Name
    
    -- Очистка кеша каждые 0.5 секунды
    if now - downedCacheTime > 0.5 then
        downedCache = {}
        downedCacheTime = now
    end
    
    if cacheKey and downedCache[cacheKey] ~= nil then
        return downedCache[cacheKey]
    end
    
    if not targetCharacter then 
        if cacheKey then downedCache[cacheKey] = false end
        return false 
    end
    
    local targetName = targetCharacter.Name
    local charStat = CharStats:FindFirstChild(targetName)
    if not charStat then 
        if cacheKey then downedCache[cacheKey] = false end
        return false 
    end
    
    local downedValue = charStat:FindFirstChild("Downed")
    local result = downedValue and downedValue:IsA("BoolValue") and downedValue.Value or false
    
    if cacheKey then downedCache[cacheKey] = result end
    return result
end

--==================== Visibility & Prediction ====================
local spawnShieldCache = {}
local spawnShieldTime = 0

local function hasSpawnShield(plr)
    local now = tick()
    local cacheKey = plr and tostring(plr)
    
    -- Очистка кеша каждые 0.5 секунды
    if now - spawnShieldTime > 0.5 then
        spawnShieldCache = {}
        spawnShieldTime = now
    end
    
    if cacheKey and spawnShieldCache[cacheKey] ~= nil then
        return spawnShieldCache[cacheKey]
    end
    
    local char = plr.Character
    local result = char and char:FindFirstChildOfClass("ForceField") ~= nil or false
    
    if cacheKey then spawnShieldCache[cacheKey] = result end
    return result
end

-- Функция проверки находится ли цель в FOV
local function isTargetInFOV(targetHead)
    if not targetHead then return false end
    
    local mousePos = UIS:GetMouseLocation()
    local pos, onscreen = Camera:WorldToScreenPoint(targetHead.Position)
    
    if not onscreen then return false end
    
    local dist = (Vector2_new(pos.X, pos.Y) - mousePos).Magnitude
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

-- Кешированный Raycast (оптимизация №6)
local function cachedRaycast(origin, direction, distance)
    local key = tostring(origin) .. tostring(direction)
    if frameRayCache[key] then return frameRayCache[key] end

    local result = workspace:Raycast(origin, direction * distance, rayParams)
    frameRayCache[key] = result
    return result
end

-- Проверка видимости цели с кешированием Raycast
local visibilityCache = {}
local visibilityCacheTime = 0

local function isTargetVisible(targetHead, localChar)
    if not wallCheckEnabled then return true end
    
    local now = tick()
    local cacheKey = targetHead and localChar and (tostring(targetHead) .. "_" .. tostring(localChar))
    
    -- Очистка кеша каждые 0.3 секунды
    if now - visibilityCacheTime > 0.3 then
        visibilityCache = {}
        visibilityCacheTime = now
    end
    
    if cacheKey and visibilityCache[cacheKey] ~= nil then
        return visibilityCache[cacheKey]
    end
    
    local rayOrigin = Camera.CFrame.Position
    local rayDir = targetHead.Position - rayOrigin
    local rayDistance = rayDir.Magnitude
    rayDir = rayDir.Unit
    
    -- Оптимизация: используем кешированный blacklist
    local targetChar = targetHead.Parent
    local blacklistKey = localChar and targetChar and (tostring(localChar) .. "_" .. tostring(targetChar))
    
    if not frameRayCache[blacklistKey] then
        rayParams.FilterDescendantsInstances = {localChar, targetChar}
    end
    
    local result = cachedRaycast(rayOrigin, rayDir, rayDistance)
    
    if not result then
        if cacheKey then visibilityCache[cacheKey] = true end
        return true
    else
        local hit = result.Instance
        
        -- Если попали в цель - видимо
        if hit == targetHead or hit:IsDescendantOf(targetHead) then
            if cacheKey then visibilityCache[cacheKey] = true end
            return true
        end
        
        -- Если попали в DFrame - проверяем, что за ним
        if hit.Name == "DFrame" then
            -- Делаем второй raycast от точки после DFrame
            local newOrigin = result.Position + rayDir * 0.1
            local remainingDistance = rayDistance - (newOrigin - rayOrigin).Magnitude
            
            if remainingDistance > 0 then
                -- Добавляем DFrame в игнор для второго raycast
                local newBlacklist = {localChar, targetChar, hit}
                rayParams.FilterDescendantsInstances = newBlacklist
                
                local secondResult = cachedRaycast(newOrigin, rayDir, remainingDistance)
                
                local finalResult = not secondResult or (secondResult.Instance == targetHead or secondResult.Instance:IsDescendantOf(targetHead))
                if cacheKey then visibilityCache[cacheKey] = finalResult end
                return finalResult
            else
                if cacheKey then visibilityCache[cacheKey] = true end
                return true
            end
        end
        
        -- Все остальное - невидимо
        if cacheKey then visibilityCache[cacheKey] = false end
        return false
    end
end

-- Кеш для проверки валидности цели (оптимизация №3)
local characterCache = {}
local validityCache = {}
local validityCacheTime = 0

-- Функция для получения кешированного персонажа (оптимизация №3)
local function getCharacter(plr)
    if not plr then return nil end
    
    if not characterCache[plr] or characterCache[plr].timestamp < tick() - 0.5 then
        local char = plr.Character
        if char then
            local head = char:FindFirstChild("Head")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChild("Humanoid")
            local tool = char:FindFirstChildOfClass("Tool")
            
            characterCache[plr] = {
                char = char,
                head = head,
                hrp = hrp,
                humanoid = humanoid,
                tool = tool,
                timestamp = tick()
            }
        else
            characterCache[plr] = nil
        end
    end
    
    return characterCache[plr]
end

-- Проверка валидности цели с кешированием
local function isValidTarget(plr, targetHead)
    local now = tick()
    local cacheKey = plr and tostring(plr)
    
    -- Очистка кеша каждые 0.3 секунды
    if now - validityCacheTime > 0.3 then
        validityCache = {}
        validityCacheTime = now
    end
    
    -- Проверка кеша
    if cacheKey and validityCache[cacheKey] ~= nil then
        return validityCache[cacheKey]
    end
    
    local charData = getCharacter(plr)
    if not charData or not charData.char then 
        if cacheKey then validityCache[cacheKey] = false end
        return false 
    end
    
    if isFriend(plr) then 
        if cacheKey then validityCache[cacheKey] = false end
        return false 
    end
    
    if not targetHead then 
        if cacheKey then validityCache[cacheKey] = false end
        return false 
    end
    
    if not charData.humanoid or charData.humanoid.Health <= 0 then 
        if cacheKey then validityCache[cacheKey] = false end
        return false 
    end
    
    if hasSpawnShield(plr) then 
        if cacheKey then validityCache[cacheKey] = false end
        return false 
    end
    
    if isTargetDowned(charData.char) then 
        if cacheKey then validityCache[cacheKey] = false end
        return false 
    end
    
    if cacheKey then validityCache[cacheKey] = true end
    return true
end

-- Получение ближайшей цели к курсору с оптимизацией
local nearestCache = nil
local nearestCacheTime = 0
local playersArray = {} -- Массив игроков для быстрого обхода

local function updatePlayersArray()
    playersArray = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            table_insert(playersArray, plr)
        end
    end
end

-- Инициализация массива игроков
updatePlayersArray()
Players.PlayerAdded:Connect(updatePlayersArray)
Players.PlayerRemoving:Connect(updatePlayersArray)

local function getNearestToCursor()
    local now = tick()
    
    -- Кешируем результат на 0.1 секунды
    if nearestCache and now - nearestCacheTime < 0.1 then
        return nearestCache
    end
    
    local nearest = nil
    local minDist = fov
    local mousePos = UIS:GetMouseLocation()
    local localChar = localPlayer.Character
    
    -- Используем локальные переменные для оптимизации
    local players = playersArray
    local playerCount = #players
    
    for i = 1, playerCount do
        local plr = players[i]
        local charData = getCharacter(plr)
        
        if charData and charData.head then
            local head = charData.head
            
            -- 1. Сначала позиция на экране (оптимизация №1)
            local pos, onscreen = Camera:WorldToScreenPoint(head.Position)
            if onscreen then
                -- 2. Проверка FOV (самое дешевое) - оптимизация №7
                local dist = (Vector2_new(pos.X, pos.Y) - mousePos).Magnitude
                if dist < minDist then
                    -- 3. Только если в FOV - проверяем валидность цели
                    if isValidTarget(plr, head) then
                        -- 4. Только если валидна - проверяем видимость
                        if isTargetVisible(head, localChar) then
                            minDist = dist
                            nearest = head
                        end
                    end
                end
            end
        end
    end

    nearestCache = nearest
    nearestCacheTime = now
    return nearest
end

-- Функция для получения/обновления цели (оптимизированная) - оптимизация №10
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
        
        -- 1. Сначала проверка FOV (без валидации)
        if isTargetInFOV(currentTarget) then
            -- 2. Только если в FOV - проверяем валидность
            if isValidTarget(plr, currentTarget) then
                -- 3. Только если валидна - проверяем видимость
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
    
    return nil -- Не ищем новую цель здесь, это делается в главном цикле
end

--==================== Input ====================
UIS.InputBegan:Connect(function(i,g)
    if not g and i.KeyCode == Enum.KeyCode.X then 
        keyHeld = true 
        -- При нажатии на клавишу сбрасываем цель и кеш
        if aimbotEnabled then
            currentTarget = nil
            targetLocked = false
            nearestCache = nil
            nearestCacheTime = 0
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
local ESP_ViewportCache = {} -- Кеш для WorldToViewportPoint (оптимизация №5)

-- Функция для полной очистки ESP игрока (только при удалении игрока)
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
    ESP_ViewportCache[plr] = nil
    characterCache[plr] = nil
end

-- Функция для скрытия ESP игрока (без удаления) - оптимизация №2
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

-- Функция для создания ESP объектов (только один раз) - оптимизация №2
local function createESPObjects(plr)
    -- НЕ очищаем старые объекты, если они уже есть
    if ESP_HPText[plr] then return end
    
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
    local charData = getCharacter(plr)
    if not charData or not charData.hrp or not charData.humanoid or charData.humanoid.Health <= 0 then
        return false
    end
    
    local dist = (Camera.CFrame.Position - charData.hrp.Position).Magnitude
    return dist <= ESP_MaxDistance
end

-- Кеширование WorldToViewportPoint точек (оптимизация №5)
local viewportCacheTime = 0

local function cacheViewportPoints(plr)
    local now = tick()
    local charData = getCharacter(plr)
    
    if not charData or not charData.head or not charData.hrp then 
        ESP_ViewportCache[plr] = nil
        return 
    end
    
    -- Обновляем кеш каждые 0.1 секунды
    if ESP_ViewportCache[plr] and ESP_ViewportCache[plr].timestamp and now - ESP_ViewportCache[plr].timestamp < 0.1 then
        return
    end
    
    -- Создаем или обновляем кеш
    if not ESP_ViewportCache[plr] then
        ESP_ViewportCache[plr] = {}
    end
    
    -- Кешируем позицию головы
    local headPos, headVisible = Camera:WorldToViewportPoint(charData.head.Position)
    ESP_ViewportCache[plr].head = {
        pos = Vector2_new(headPos.X, headPos.Y), 
        visible = headVisible, 
        z = headPos.Z,
        timestamp = now
    }
    
    -- Кешируем углы для Box ESP (только если включен Box ESP)
    if Box_ESP_Enabled and charData.hrp then
        local cf = charData.hrp.CFrame
        local size = Vector3.new(4, 6, 1.5)
        
        local corners = {
            cf * Vector3.new(-size.X/2, size.Y/2, 0),
            cf * Vector3.new( size.X/2, size.Y/2, 0),
            cf * Vector3.new(-size.X/2,-size.Y/2, 0),
            cf * Vector3.new( size.X/2,-size.Y/2, 0),
        }
        
        ESP_ViewportCache[plr].boxCorners = {}
        
        for i = 1, 4 do
            local pos, visible = Camera:WorldToViewportPoint(corners[i])
            ESP_ViewportCache[plr].boxCorners[i] = {
                pos = Vector2_new(pos.X, pos.Y), 
                visible = visible, 
                z = pos.Z
            }
        end
    else
        ESP_ViewportCache[plr].boxCorners = nil
    end
    
    ESP_ViewportCache[plr].timestamp = now
end

--==================== Update ESP с оптимизацией ====================
local espUpdateIndex = 1 -- Для циклического обновления
local espUpdateBatch = 3 -- Обновляем по 3 игрока за кадр

local function UpdateESP(plr)
    -- Проверяем, включен ли вообще какой-либо ESP
    if not ESP_HPEnabled and not ESP_NameEnabled and not ESP_WeaponEnabled and not Box_ESP_Enabled then
        if ESP_HPText[plr] then
            hidePlayerESP(plr)
        end
        return
    end
    
    local charData = getCharacter(plr)
    if not charData or not charData.hrp or not charData.humanoid or charData.humanoid.Health <= 0 then
        -- Игрок мертв или нет персонажа - скрываем ESP, но НЕ удаляем
        if ESP_HPText[plr] then
            hidePlayerESP(plr)
        end
        return
    end
    
    local dist = (Camera.CFrame.Position - charData.hrp.Position).Magnitude
    
    -- Если игрок ВНЕ зоны видимости
    if dist > ESP_MaxDistance then
        -- Если у него есть ESP объекты - скрываем их
        if ESP_HPText[plr] then
            hidePlayerESP(plr)
        end
        return
    end
    
    -- Если игрок В зоне видимости, но ESP объектов нет - создаем их ОДИН РАЗ
    if not ESP_HPText[plr] then
        createESPObjects(plr)
    end
    
    -- Кешируем точки обзора
    cacheViewportPoints(plr)
    
    -- Если игрока нет на экране - скрываем ESP
    if not ESP_ViewportCache[plr] or not ESP_ViewportCache[plr].head or not ESP_ViewportCache[plr].head.visible then
        hidePlayerESP(plr)
        return
    end
    
    local color = isFriend(plr) and Settings.Friend_Color or Settings.ESP_Color
    local hpText = ESP_HPText[plr]
    local nameText = ESP_NameText[plr]
    local weaponText = ESP_WeaponText[plr]
    local boxes = ESP_Boxes[plr]
    
    -- Используем кешированные точки
    local headCache = ESP_ViewportCache[plr].head
    if headCache then
        local headPos = headCache.pos
        
        -- HP Text
        if ESP_HPEnabled and hpText then
            local hp = math_clamp(charData.humanoid.Health, 0, charData.humanoid.MaxHealth)
            local hpColor = ESP_HPDynamicEnabled and Color3.fromHSV((hp/charData.humanoid.MaxHealth)/3,1,1) or color
            hpText.Position = Vector2_new(headPos.X + 20, headPos.Y)
            hpText.Text = math_floor(hp) .. " HP"
            hpText.Color = hpColor
            hpText.Visible = true
        elseif hpText then
            hpText.Visible = false
        end
        
        -- Name Text
        if ESP_NameEnabled and nameText then
            nameText.Position = Vector2_new(headPos.X, headPos.Y - 15)
            nameText.Text = plr.Name
            nameText.Color = color
            nameText.Visible = true
        elseif nameText then
            nameText.Visible = false
        end
        
        -- Weapon Text
        if ESP_WeaponEnabled and weaponText then
            weaponText.Position = Vector2_new(headPos.X, headPos.Y + 15)
            weaponText.Text = charData.tool and charData.tool.Name or "None"
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
        local boxCorners = ESP_ViewportCache[plr] and ESP_ViewportCache[plr].boxCorners
        
        if boxCorners then
            local minX, minY, maxX, maxY = 9e9, 9e9, -9e9, -9e9
            local anyVisible = false
            
            for i = 1, 4 do
                local corner = boxCorners[i]
                if corner.visible and corner.z > 0 then
                    anyVisible = true
                    local x, y = corner.pos.X, corner.pos.Y
                    if x < minX then minX = x end
                    if y < minY then minY = y end
                    if x > maxX then maxX = x end
                    if y > maxY then maxY = y end
                end
            end
            
            if anyVisible then
                local w, h = maxX - minX, maxY - minY
                local pos = Vector2_new(minX, minY)
                
                boxes.box.Position = pos
                boxes.box.Size = Vector2_new(w, h)
                boxes.box.Color = color
                boxes.box.Visible = true
                
                boxes.boxoutline.Position = Vector2_new(pos.X - 1, pos.Y - 1)
                boxes.boxoutline.Size = Vector2_new(w + 2, h + 2)
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

--==================== Инициализация игроков ====================
local function initPlayer(plr)
    if plr == localPlayer then return end
    
    -- Создаем ESP объекты только если игрок в зоне видимости
    if shouldCreateESP(plr) then
        createESPObjects(plr)
    end
    
    -- Подключаем обработчик изменения персонажа
    plr.CharacterAdded:Connect(function(char)
        characterCache[plr] = nil -- Сбрасываем кеш
        task.wait(0.5) -- Даем время на загрузку
        
        if shouldCreateESP(plr) then
            createESPObjects(plr)
        end
    end)
end

-- Инициализируем существующих игроков
for _, plr in pairs(playersArray) do
    initPlayer(plr)
end

-- Обработчики добавления/удаления игроков
Players.PlayerAdded:Connect(function(plr)
    if plr ~= localPlayer then
        updatePlayersArray()
        initPlayer(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    cleanupPlayerESP(plr)
    updatePlayersArray()
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
            table_insert(FriendList, Text)
            FriendSet[Text] = true
            FriendListLabel:Set("Friend List: " .. table.concat(FriendList, ", "))
        end
    end,
})

local ClearFriendsButton = RageTab:CreateButton({
    Name = "Clear Friend List",
    Callback = function()
        FriendList = {}
        FriendSet = {}
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
        -- При выключении скрываем все HP ESP
        if not Value then
            for _, plr in pairs(playersArray) do
                if ESP_HPText[plr] then
                    ESP_HPText[plr].Visible = false
                end
            end
        end
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
        -- При выключении скрываем все Box ESP
        if not Value then
            for _, plr in pairs(playersArray) do
                if ESP_Boxes[plr] then
                    ESP_Boxes[plr].box.Visible = false
                    ESP_Boxes[plr].boxoutline.Visible = false
                end
            end
        end
    end,
})

local NameToggle = ESPTab:CreateToggle({
    Name = "Name ESP",
    CurrentValue = false,
    Flag = "NameToggle",
    Callback = function(Value)
        ESP_NameEnabled = Value
        -- При выключении скрываем все Name ESP
        if not Value then
            for _, plr in pairs(playersArray) do
                if ESP_NameText[plr] then
                    ESP_NameText[plr].Visible = false
                end
            end
        end
    end,
})

local WeaponToggle = ESPTab:CreateToggle({
    Name = "Weapon ESP",
    CurrentValue = false,
    Flag = "WeaponToggle",
    Callback = function(Value)
        ESP_WeaponEnabled = Value
        -- При выключении скрываем все Weapon ESP
        if not Value then
            for _, plr in pairs(playersArray) do
                if ESP_WeaponText[plr] then
                    ESP_WeaponText[plr].Visible = false
                end
            end
        end
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
        for _, plr in pairs(playersArray) do
            cleanupPlayerESP(plr)
        end
        fovCircle:Remove()
        Rayfield:Destroy()
    end,
})

--==================== Главный Render Loop с оптимизациями ====================
local currentTool

RunService.RenderStepped:Connect(function()
    -- Очистка Raycast кеша каждый кадр (оптимизация №6)
    frameRayCache = {}
    
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

    -- Aimlock и Autofire (оптимизация №8 и №10)
    if aimbotEnabled and keyHeld then
        -- Получаем цель (если еще нет) - оптимизация №10
        if not currentTarget then
            currentTarget = getNearestToCursor()
            if currentTarget then
                targetLocked = true
            end
        end
        
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
        currentTarget = nil
        targetLocked = false
        if currentTool then 
            currentTool:Deactivate() 
            currentTool = nil 
        end
    end

    -- ESP Update с циклическим обновлением
    local playerCount = #playersArray
    if playerCount > 0 then
        -- Обновляем по espUpdateBatch игроков за кадр
        for i = 1, espUpdateBatch do
            local index = (espUpdateIndex + i - 2) % playerCount + 1
            local plr = playersArray[index]
            if plr and plr.Parent then
                UpdateESP(plr)
            end
        end
        
        espUpdateIndex = (espUpdateIndex + espUpdateBatch - 1) % playerCount + 1
    end
end)

-- Initialize UI
Rayfield:LoadConfiguration()
