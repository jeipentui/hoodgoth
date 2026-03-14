-- Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharStats = ReplicatedStorage:FindFirstChild("CharStats")
local localPlayer = Players.LocalPlayer

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "thw club",
    LoadingTitle = "Loading Interface...",
    LoadingSubtitle = "by thw",
    Theme = "Bloom",
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
local AntiAimTab = Window:CreateTab("Anti-Aim")
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

-- NO VISUAL RECOIL
local NoVisualRecoilEnabled = false
local lastShotTime = 0
local RECOIL_TAIL = 0.3
local targetCFrame = Camera.CFrame

-- SILENT AIM (FLASH AIM) VARIABLES
local silentAimEnabled = false
local silentAimFOV = 100
local silentAimShowFOV = false
local silentAimWallCheck = true
local silentAimTarget = nil
local lastSilentAimUpdate = 0
local SILENT_AIM_UPDATE_INTERVAL = 0.05
local silentAimKey = nil
local silentAimKeyName = "Not Set"
local silentAimKeyHeld = false
local isRecordingSilentKeybind = false

local silentFovCircle = Drawing.new("Circle")
silentFovCircle.Visible = false
silentFovCircle.Color = Color3.new(1, 0, 0)
silentFovCircle.Thickness = 2
silentFovCircle.NumSides = 100

local function monitorTool(tool)
    if not tool then return end
    tool.Activated:Connect(function()
        lastShotTime = tick()
        targetCFrame = Camera.CFrame
    end)
end

local function setupCharacter(char)
    local humanoid = char:WaitForChild("Humanoid")
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        monitorTool(tool)
    end

    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            monitorTool(child)
        end
    end)

    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            lastShotTime = 0
        end
    end)
end

localPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    setupCharacter(char)
end)

if localPlayer.Character then
    setupCharacter(localPlayer.Character)
end

local recoilHook = RunService.RenderStepped:Connect(function()
    if NoVisualRecoilEnabled then
        if (tick() - lastShotTime <= RECOIL_TAIL) then
            Camera.CFrame = targetCFrame
        else
            local char = localPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                targetCFrame = CFrame.new(Camera.CFrame.Position) * (targetCFrame - targetCFrame.Position)
            end
        end
    end
end)

local function activateNoVisualRecoil()
    NoVisualRecoilEnabled = true
    lastShotTime = 0
    targetCFrame = Camera.CFrame
end

local function deactivateNoVisualRecoil()
    NoVisualRecoilEnabled = false
    lastShotTime = 0
end

local aimlockKey = nil
local aimlockKeyName = "Not Set"
local isRecordingKeybind = false

local currentTarget = nil
local targetLocked = false

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 100
local lastMousePos = Vector2.new()
local lastFOV = fov

--==================== FRAME CACHE ====================
local frameCache = {
    mousePos = Vector2.new(),
    cameraPos = Vector3.new(),
    cameraCFrame = CFrame.new(),
    time = 0,
}

local function updateFrameCache()
    frameCache.mousePos = UIS:GetMouseLocation()
    frameCache.cameraCFrame = Camera.CFrame
    frameCache.cameraPos = Camera.CFrame.Position
    frameCache.time = tick()
end

--==================== WALLCHECK CACHE ====================
local wallCheckCache = {}
local WALLCHECK_CACHE_TIME = 0.08

local function clearWallCheckCache(plr)
    wallCheckCache[plr] = nil
end

--==================== FOV CHECK ====================
local FOV_RADIUS = 100

local function InFOV(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    if not onScreen then return false end

    local dist = (Vector2.new(screenPos.X, screenPos.Y) - frameCache.mousePos).Magnitude
    return dist <= FOV_RADIUS
end

--==================== WALLCHECK (RAW) ====================
local function WallCheckRaw(targetHead, localChar)
    if not wallCheckEnabled then return true end
    if not targetHead or not localChar then return false end

    if not InFOV(targetHead.Position) then
        return false
    end

    local origin = frameCache.cameraPos
    local direction = (targetHead.Position - origin).Unit
    local distanceToTarget = (targetHead.Position - origin).Magnitude

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {localChar, targetHead.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true

    local result1 = workspace:Raycast(origin, direction * distanceToTarget, rayParams)

    if not result1 then
        return true
    end

    local hit1 = result1.Instance

    if hit1:IsDescendantOf(targetHead.Parent) then
        return true
    end

    if hit1.Name == "DFrame" or hit1.ClassName == "DFrame" then
        local newOrigin = result1.Position + (direction * 0.5)
        local remainingDistance = distanceToTarget - (newOrigin - origin).Magnitude

        if remainingDistance > 0 then
            local result2 = workspace:Raycast(newOrigin, direction * remainingDistance, rayParams)

            if not result2 then
                return true
            end

            if result2.Instance:IsDescendantOf(targetHead.Parent) then
                return true
            end

            return false
        end
    end

    return false
end

--==================== WALLCHECK С КЭШЕМ ====================
local function WallCheck(targetHead, localChar, plr)
    if not wallCheckEnabled then return true end

    if plr then
        local cached = wallCheckCache[plr]
        if cached and (frameCache.time - cached.time) < WALLCHECK_CACHE_TIME then
            return cached.result
        end
    end

    local result = WallCheckRaw(targetHead, localChar)

    if plr then
        wallCheckCache[plr] = {result = result, time = frameCache.time}
    end

    return result
end

--==================== WALLCHECK ДЛЯ SILENT AIM ====================
local function WallCheckSilentRaw(targetHead, localChar)
    if not targetHead or not localChar then return false end

    local origin = frameCache.cameraPos
    local direction = (targetHead.Position - origin).Unit
    local distanceToTarget = (targetHead.Position - origin).Magnitude

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {localChar, targetHead.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true

    local result1 = workspace:Raycast(origin, direction * distanceToTarget, rayParams)

    if not result1 then
        return true
    end

    local hit1 = result1.Instance

    if hit1:IsDescendantOf(targetHead.Parent) then
        return true
    end

    if hit1.Name == "DFrame" or hit1.ClassName == "DFrame" then
        local newOrigin = result1.Position + (direction * 0.5)
        local remainingDistance = distanceToTarget - (newOrigin - origin).Magnitude

        if remainingDistance > 0 then
            local result2 = workspace:Raycast(newOrigin, direction * remainingDistance, rayParams)

            if not result2 then
                return true
            end

            if result2.Instance:IsDescendantOf(targetHead.Parent) then
                return true
            end

            return false
        end
    end

    return false
end

--==================== Weapon Prediction ====================
local weaponBulletSpeeds = {
    ["Beretta"] = 1624,
    ["Magnum"] = 2550,
    ["G-17"] = 1850,
    ["UZI"] = 2250,
    ["UZI+"] = 2250,
    ["Mare"] = 2000,
    ["Deagle"] = 2200,
    ["SKS"] = 3750,
    ["M1911"] = 2230,
    ["AKS-74U"] = 3000,
    ["FNP-45"] = 1500,
    ["TEC-9"] = 2100,
    ["MAC-10+"] = 2250,
    ["MAC-10"] = 2250,
    ["MP7"] = 2600,
    ["Tommy+"] = 2225,
    ["Tommy"] = 2225,
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
    if not CharStats then return false end
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

local function getPredictedPosition(target)
    local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then return target.Position end

    local dist = (hrp.Position - frameCache.cameraPos).Magnitude
    local t = dist / getCurrentWeaponSpeed()

    return target.Position + hrp.Velocity * t
end

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

--==================== ПОИСК ЦЕЛИ ====================
local function getNearestToCursor()
    local localChar = localPlayer.Character
    if not localChar then return nil end

    local mousePos = frameCache.mousePos
    local candidates = {}

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist <= FOV_RADIUS then
                            if isValidTarget(plr, head) then
                                candidates[#candidates + 1] = {plr = plr, head = head, dist = dist}
                            end
                        end
                    end
                end
            end
        end
    end

    if #candidates == 0 then return nil end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    for _, c in ipairs(candidates) do
        if WallCheck(c.head, localChar, c.plr) then
            return c.head
        end
    end

    return nil
end

local function getTarget()
    if currentTarget and targetLocked then
        local plr = Players:GetPlayerFromCharacter(currentTarget.Parent)

        if not plr then
            currentTarget = nil
            targetLocked = false
            return nil
        end

        if isValidTarget(plr, currentTarget) then
            if WallCheck(currentTarget, localPlayer.Character, plr) then
                return currentTarget
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

--==================== SILENT AIM TARGET ====================
local function updateSilentAimTarget()
    if not silentAimEnabled or not silentAimKeyHeld then
        silentAimTarget = nil
        return
    end

    local now = frameCache.time
    if now - lastSilentAimUpdate < SILENT_AIM_UPDATE_INTERVAL then
        if silentAimTarget then
            local plr = Players:GetPlayerFromCharacter(silentAimTarget.Parent)
            if not plr or not isValidTarget(plr, silentAimTarget) then
                silentAimTarget = nil
            end
        end
        return
    end
    lastSilentAimUpdate = now

    local localChar = localPlayer.Character
    if not localChar then
        silentAimTarget = nil
        return
    end

    local mousePos = frameCache.mousePos
    local candidates = {}

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist <= silentAimFOV then
                            if isValidTarget(plr, head) then
                                candidates[#candidates + 1] = {plr = plr, head = head, dist = dist}
                            end
                        end
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        silentAimTarget = nil
        return
    end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    for _, c in ipairs(candidates) do
        if silentAimWallCheck then
            if WallCheckSilentRaw(c.head, localChar) then
                silentAimTarget = c.head
                return
            end
        else
            silentAimTarget = c.head
            return
        end
    end
    silentAimTarget = nil
end

--==================== ANTI-AIM С DESYNC ====================
local AntiAimEnabled = false
local AntiAimMode = "Spin"
local AntiAimSpeed = 20
local AntiAimConnection = nil
local DesyncEnabled = true

local function setAutoRotate(value)
    local char = localPlayer.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.AutoRotate = value
        end
    end
end

local function startAntiAim()
    if AntiAimConnection then AntiAimConnection:Disconnect() end

    local spinAngle = 0
    local jitterFlip = false

    setAutoRotate(false)

    AntiAimConnection = RunService.RenderStepped:Connect(function(dt)
        if not AntiAimEnabled then return end

        local char = localPlayer.Character
        if not char then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then return end
        if humanoid.Health <= 0 then return end
        if humanoid.SeatPart then return end

        humanoid.AutoRotate = false

        local savedCamCFrame = Camera.CFrame

        local lookDir = savedCamCFrame.LookVector
        local realAngle = math.atan2(-lookDir.X, -lookDir.Z)

        if AntiAimMode == "Spin" then
            spinAngle = spinAngle + (AntiAimSpeed * dt * 60)
            if spinAngle >= 360 then spinAngle = spinAngle - 360 end

            hrp.CFrame = CFrame.new(hrp.Position)
                * CFrame.Angles(0, math.rad(spinAngle), 0)

        elseif AntiAimMode == "Jitter" then
            jitterFlip = not jitterFlip
            local offset = jitterFlip and 180 or -180

            hrp.CFrame = CFrame.new(hrp.Position)
                * CFrame.Angles(0, realAngle + math.rad(offset), 0)

        elseif AntiAimMode == "Random" then
            local randomAngle = math.random(0, 360)

            hrp.CFrame = CFrame.new(hrp.Position)
                * CFrame.Angles(0, math.rad(randomAngle), 0)

        elseif AntiAimMode == "Backward" then
            hrp.CFrame = CFrame.new(hrp.Position)
                * CFrame.Angles(0, realAngle + math.rad(180), 0)

        elseif AntiAimMode == "Sideways" then
            jitterFlip = not jitterFlip
            local sideAngle = jitterFlip and 90 or -90

            hrp.CFrame = CFrame.new(hrp.Position)
                * CFrame.Angles(0, realAngle + math.rad(sideAngle), 0)

        elseif AntiAimMode == "Fake Down" then
            spinAngle = spinAngle + (AntiAimSpeed * dt * 60)
            if spinAngle >= 360 then spinAngle = spinAngle - 360 end

            hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, -0.5, 0))
                * CFrame.Angles(math.rad(15), math.rad(spinAngle), 0)

        elseif AntiAimMode == "Crazy" then
            spinAngle = spinAngle + (AntiAimSpeed * dt * 60)
            if spinAngle >= 360 then spinAngle = spinAngle - 360 end

            local randomTilt = math.random(-25, 25)

            hrp.CFrame = CFrame.new(hrp.Position)
                * CFrame.Angles(math.rad(randomTilt), math.rad(spinAngle), math.rad(randomTilt))
        end

        if DesyncEnabled then
            Camera.CFrame = savedCamCFrame
        end
    end)
end

local function stopAntiAim()
    AntiAimEnabled = false
    if AntiAimConnection then
        AntiAimConnection:Disconnect()
        AntiAimConnection = nil
    end
    setAutoRotate(true)
end

-- Респавн фикс для AntiAim
localPlayer.CharacterAdded:Connect(function(char)
    if AntiAimEnabled then
        task.wait(0.5)
        local humanoid = char:WaitForChild("Humanoid")
        if humanoid then
            humanoid.AutoRotate = false
        end
    end
end)

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

        if humanoid.SeatPart or humanoid:GetState() == Enum.HumanoidStateType.Climbing then
            return
        end

        local velY = hrp.Velocity.Y

        if velY < FALL_SPEED_THRESHOLD then
            hrp.Velocity = Vector3.new(
                hrp.Velocity.X,
                SAFE_FALL_SPEED,
                hrp.Velocity.Z
            )
        end
    end)
end

local function stopNoFall()
    NoFallEnabled = false
    if NoFallConnection then
        NoFallConnection:Disconnect()
        NoFallConnection = nil
    end
end

--==================== UI: RAGEBOT TAB ====================

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

local SilentAimToggle = RageTab:CreateToggle({
    Name = "Silent Aim (Flash)",
    CurrentValue = false,
    Flag = "SilentAimToggle",
    Callback = function(Value)
        silentAimEnabled = Value
        if not Value then silentAimTarget = nil end
    end,
})

local SilentAimWallcheckToggle = RageTab:CreateToggle({
    Name = "Silent Aim Wallcheck",
    CurrentValue = true,
    Flag = "SilentAimWallcheck",
    Callback = function(Value)
        silentAimWallCheck = Value
    end,
})

local SilentAimFOVSlider = RageTab:CreateSlider({
    Name = "Silent Aim FOV",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 100,
    Flag = "SilentAimFOV",
    Callback = function(Value)
        silentAimFOV = Value
    end,
})

local SilentAimKeybindLabel = RageTab:CreateLabel("Silent Aim Key: Not Set")

local SetSilentAimKeyButton = RageTab:CreateButton({
    Name = "Set Silent Aim Key",
    Callback = function()
        isRecordingSilentKeybind = true
        SilentAimKeybindLabel:Set("Press any keyboard key...")

        local connection
        connection = UIS.InputBegan:Connect(function(input, gameProcessed)
            if isRecordingSilentKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
                isRecordingSilentKeybind = false
                connection:Disconnect()

                silentAimKey = input.KeyCode
                silentAimKeyName = input.KeyCode.Name
                SilentAimKeybindLabel:Set("Silent Aim Key: " .. silentAimKeyName)

                Rayfield:Notify({
                    Title = "Keybind Set",
                    Content = "Silent Aim key set to: " .. silentAimKeyName,
                    Duration = 2,
                    Image = 4483362458,
                })
            end
        end)

        task.delay(5, function()
            if isRecordingSilentKeybind then
                isRecordingSilentKeybind = false
                if connection then connection:Disconnect() end
                SilentAimKeybindLabel:Set("Silent Aim Key: " .. silentAimKeyName)
            end
        end)
    end,
})

local SilentFOVCircleToggle = RageTab:CreateButton({
    Name = "Toggle Silent FOV Circle",
    Callback = function()
        silentAimShowFOV = not silentAimShowFOV
        silentFovCircle.Visible = silentAimShowFOV
        Rayfield:Notify({
            Title = "Silent FOV Circle",
            Content = silentAimShowFOV and "Enabled" or "Disabled",
            Duration = 1,
            Image = 4483362458,
        })
    end,
})

local SilentFOVColorPicker = RageTab:CreateColorPicker({
    Name = "Silent FOV Color",
    Color = Color3.new(1, 0, 0),
    Flag = "SilentFOVColor",
    Callback = function(Value)
        silentFovCircle.Color = Value
    end
})

local NoVisualRecoilToggle = RageTab:CreateToggle({
    Name = "No Visual Recoil",
    CurrentValue = false,
    Flag = "NoVisualRecoilToggle",
    Callback = function(Value)
        if Value then
            activateNoVisualRecoil()
        else
            deactivateNoVisualRecoil()
        end
    end,
})

local AimlockKeybindLabel = RageTab:CreateLabel("Aimlock Key: Not Set")

local SetAimlockKeyButton = RageTab:CreateButton({
    Name = "Set Aimlock Key",
    Callback = function()
        isRecordingKeybind = true
        AimlockKeybindLabel:Set("Press any keyboard key...")

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

        task.delay(5, function()
            if isRecordingKeybind then
                isRecordingKeybind = false
                if connection then connection:Disconnect() end
                AimlockKeybindLabel:Set("Aimlock Key: " .. aimlockKeyName)
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

--==================== UI: ANTI-AIM TAB ====================

local AntiAimToggle = AntiAimTab:CreateToggle({
    Name = "Anti-Aim",
    CurrentValue = false,
    Flag = "AntiAimToggle",
    Callback = function(Value)
        AntiAimEnabled = Value
        if Value then
            startAntiAim()
            Rayfield:Notify({
                Title = "Anti-Aim",
                Content = "Anti-Aim enabled: " .. AntiAimMode,
                Duration = 2,
                Image = 4483362458,
            })
        else
            stopAntiAim()
            Rayfield:Notify({
                Title = "Anti-Aim",
                Content = "Anti-Aim disabled",
                Duration = 2,
                Image = 4483362458,
            })
        end
    end,
})

local DesyncToggle = AntiAimTab:CreateToggle({
    Name = "Desync (Anim Fix)",
    CurrentValue = true,
    Flag = "DesyncToggle",
    Callback = function(Value)
        DesyncEnabled = Value
        Rayfield:Notify({
            Title = "Desync",
            Content = Value and "Camera independent from model" or "Camera follows model",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

local AntiAimModeDropdown = AntiAimTab:CreateDropdown({
    Name = "Anti-Aim Mode",
    Options = {"Spin", "Jitter", "Random", "Backward", "Sideways", "Fake Down", "Crazy"},
    CurrentOption = {"Spin"},
    MultipleOptions = false,
    Flag = "AntiAimMode",
    Callback = function(Value)
        AntiAimMode = Value[1] or Value
        if AntiAimEnabled then
            Rayfield:Notify({
                Title = "Anti-Aim Mode",
                Content = "Mode: " .. AntiAimMode,
                Duration = 1,
                Image = 4483362458,
            })
        end
    end,
})

local AntiAimSpeedSlider = AntiAimTab:CreateSlider({
    Name = "Anti-Aim Speed",
    Range = {5, 50},
    Increment = 1,
    Suffix = "speed",
    CurrentValue = 20,
    Flag = "AntiAimSpeed",
    Callback = function(Value)
        AntiAimSpeed = Value
    end,
})

AntiAimTab:CreateLabel("━━━━━━ Info ━━━━━━")
AntiAimTab:CreateLabel("Spin - fast rotation")
AntiAimTab:CreateLabel("Jitter - snap 180° left/right")
AntiAimTab:CreateLabel("Random - random angle each tick")
AntiAimTab:CreateLabel("Backward - always face away")
AntiAimTab:CreateLabel("Sideways - thin hitbox")
AntiAimTab:CreateLabel("Fake Down - spin + head tilt")
AntiAimTab:CreateLabel("Crazy - spin + random tilt")
AntiAimTab:CreateLabel("━━━━━━━━━━━━━━━━━")
AntiAimTab:CreateLabel("Desync ON = you aim freely")
AntiAimTab:CreateLabel("Enemies see spinning model")

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

        return
    end

    if isRecordingSilentKeybind then
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        isRecordingSilentKeybind = false
        silentAimKey = input.KeyCode
        silentAimKeyName = input.KeyCode.Name
        SilentAimKeybindLabel:Set("Silent Aim Key: " .. silentAimKeyName)

        Rayfield:Notify({
            Title = "Keybind Set",
            Content = "Silent Aim key set to: " .. silentAimKeyName,
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

    if silentAimKey and input.KeyCode == silentAimKey then
        silentAimKeyHeld = true
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

    if silentAimKey and input.KeyCode == silentAimKey then
        silentAimKeyHeld = false
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

local ESP_HPText = {}
local ESP_NameText = {}
local ESP_WeaponText = {}
local ESP_Boxes = {}
local characterCache = {}
local viewportCache = {}

local playersInRange = {}
local lastDistanceCheck = 0
local DISTANCE_CHECK_INTERVAL = 0.25

local function cleanupPlayerESP(plr)
    if ESP_HPText[plr] then
        ESP_HPText[plr].Visible = false
        ESP_HPText[plr]:Remove()
        ESP_HPText[plr] = nil
    end

    if ESP_NameText[plr] then
        ESP_NameText[plr].Visible = false
        ESP_NameText[plr]:Remove()
        ESP_NameText[plr] = nil
    end

    if ESP_WeaponText[plr] then
        ESP_WeaponText[plr].Visible = false
        ESP_WeaponText[plr]:Remove()
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

    characterCache[plr] = nil
    viewportCache[plr] = nil
    playersInRange[plr] = nil
    wallCheckCache[plr] = nil
end

local function hidePlayerESP(plr)
    if ESP_HPText[plr] then ESP_HPText[plr].Visible = false end
    if ESP_NameText[plr] then ESP_NameText[plr].Visible = false end
    if ESP_WeaponText[plr] then ESP_WeaponText[plr].Visible = false end
    if ESP_Boxes[plr] then
        ESP_Boxes[plr].box.Visible = false
        ESP_Boxes[plr].boxoutline.Visible = false
    end
end

local function createESPObjects(plr)
    cleanupPlayerESP(plr)

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
    characterCache[plr] = plr.Character
end

local function updatePlayersInRangeCache()
    local currentTime = frameCache.time

    if currentTime - lastDistanceCheck < DISTANCE_CHECK_INTERVAL then
        return
    end

    lastDistanceCheck = currentTime

    local cameraPos = frameCache.cameraPos

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChild("Humanoid")

            if hrp and humanoid and humanoid.Health > 0 then
                local dist = (cameraPos - hrp.Position).Magnitude
                local isInRange = dist <= ESP_MaxDistance

                playersInRange[plr] = isInRange

                if not isInRange then
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

local function get3DBoxCorners(hrp)
    local cf = hrp.CFrame
    return {
        cf * Vector3.new(-2, 3, 0),
        cf * Vector3.new(2, 3, 0),
        cf * Vector3.new(-2, -3, 0),
        cf * Vector3.new(2, -3, 0),
    }
end

local function cacheViewportPoints()
    viewportCache = {}

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= localPlayer and playersInRange[plr] then
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")

                if hrp and humanoid and humanoid.Health > 0 then
                    local data = {
                        head = nil,
                        boxCorners = {},
                        anyVisible = false
                    }

                    local head = char:FindFirstChild("Head")
                    if head then
                        local headPos, headVisible = Camera:WorldToViewportPoint(head.Position)
                        data.head = {pos = Vector2.new(headPos.X, headPos.Y), visible = headVisible, z = headPos.Z}
                        if headVisible then data.anyVisible = true end
                    end

                    if Box_ESP_Enabled and data.anyVisible then
                        local corners = get3DBoxCorners(hrp)
                        for i, corner in ipairs(corners) do
                            local pos, visible = Camera:WorldToViewportPoint(corner)
                            data.boxCorners[i] = {pos = Vector2.new(pos.X, pos.Y), visible = visible, z = pos.Z}
                        end
                    end

                    viewportCache[plr] = data
                end
            end
        end
    end
end

local function updatePlayerESP(plr)
    if not ESP_HPEnabled and not ESP_NameEnabled and not ESP_WeaponEnabled and not Box_ESP_Enabled then
        hidePlayerESP(plr)
        return
    end

    local char = plr.Character
    if not char then
        cleanupPlayerESP(plr)
        return
    end

    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        cleanupPlayerESP(plr)
        return
    end

    if not ESP_HPText[plr] then
        createESPObjects(plr)
    end

    if characterCache[plr] ~= char then
        characterCache[plr] = char
    end

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

    if data.head and data.head.visible then
        local headPos = data.head.pos

        if ESP_HPEnabled and hpText then
            local hp = math.clamp(humanoid.Health, 0, humanoid.MaxHealth)
            local hpColor = ESP_HPDynamicEnabled and Color3.fromHSV((hp / humanoid.MaxHealth) / 3, 1, 1) or color
            hpText.Position = Vector2.new(headPos.X + 20, headPos.Y)
            hpText.Text = math.floor(hp) .. " HP"
            hpText.Color = hpColor
            hpText.Visible = true
        elseif hpText then
            hpText.Visible = false
        end

        if ESP_NameEnabled and nameText then
            nameText.Position = Vector2.new(headPos.X, headPos.Y - 15)
            nameText.Text = plr.Name
            nameText.Color = color
            nameText.Visible = true
        elseif nameText then
            nameText.Visible = false
        end

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

    if Box_ESP_Enabled and boxes then
        local boxCorners = data.boxCorners

        if boxCorners and #boxCorners > 0 then
            local minX, minY, maxX, maxY = 9e9, 9e9, -9e9, -9e9
            local anyVisible = false

            for _, corner in ipairs(boxCorners) do
                if corner.visible and corner.z > 0 then
                    anyVisible = true
                    if corner.pos.X < minX then minX = corner.pos.X end
                    if corner.pos.Y < minY then minY = corner.pos.Y end
                    if corner.pos.X > maxX then maxX = corner.pos.X end
                    if corner.pos.Y > maxY then maxY = corner.pos.Y end
                end
            end

            if anyVisible then
                local w, h = maxX - minX, maxY - minY

                boxes.box.Position = Vector2.new(minX, minY)
                boxes.box.Size = Vector2.new(w, h)
                boxes.box.Color = color
                boxes.box.Visible = true

                boxes.boxoutline.Position = Vector2.new(minX - 1, minY - 1)
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

--==================== UI: ESP TAB ====================

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

--==================== UI: MISC TAB ====================

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
        stopAntiAim()
        silentAimEnabled = false
        if recoilHook then recoilHook:Disconnect() end

        for plr, _ in pairs(ESP_HPText) do
            cleanupPlayerESP(plr)
        end
        fovCircle:Remove()
        silentFovCircle:Remove()

        Rayfield:Destroy()
    end,
})

--==================== ГЛАВНЫЙ RENDER LOOP ====================
local currentTool

RunService.RenderStepped:Connect(function()
    updateFrameCache()

    updateSilentAimTarget()

    if silentAimEnabled and silentAimKeyHeld and silentAimTarget then
        local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            local savedCFrame = Camera.CFrame
            local predictedPos = getPredictedPosition(silentAimTarget)
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
            tool:Activate()
            Camera.CFrame = savedCFrame
        end
    end

    if silentAimEnabled and silentAimShowFOV then
        silentFovCircle.Position = frameCache.mousePos
        silentFovCircle.Radius = silentAimFOV
        silentFovCircle.Visible = true
    else
        silentFovCircle.Visible = false
    end

    if not aimbotEnabled or not showFOV then
        fovCircle.Visible = false
    else
        local mousePos = frameCache.mousePos
        if mousePos ~= lastMousePos or fov ~= lastFOV then
            fovCircle.Position = mousePos
            fovCircle.Radius = fov
            fovCircle.Visible = true
            lastMousePos = mousePos
            lastFOV = fov
        end
    end

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

    updatePlayersInRangeCache()
    cacheViewportPoints()

    for plr, isInRange in pairs(playersInRange) do
        if isInRange then
            updatePlayerESP(plr)
        else
            hidePlayerESP(plr)
        end
    end
end)

Rayfield:LoadConfiguration()
