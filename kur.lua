local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharStats = ReplicatedStorage:WaitForChild("CharStats")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("skeet_visual")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "skeet_visual"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local MENU_FONT = Enum.Font.SourceSansBold

local ICONS = {
	"rbxassetid://72199966651688",
	"rbxassetid://94319244918015",
	"rbxassetid://76135141713306",
	"rbxassetid://93250830821593",
	"rbxassetid://136073842129615",
	"rbxassetid://112066925986134",
	"rbxassetid://72577416815582",
	"rbxassetid://135727194981297"
}

local C = {
	outer       = Color3.fromRGB(3, 3, 3),
	inner       = Color3.fromRGB(47, 47, 47),
	bg0         = Color3.fromRGB(8, 8, 8),
	bg1         = Color3.fromRGB(12, 12, 12),
	bg2         = Color3.fromRGB(15, 15, 15),
	side        = Color3.fromRGB(12, 12, 12),
	divider     = Color3.fromRGB(34, 34, 34),
	text        = Color3.fromRGB(214, 214, 214),
	textDim     = Color3.fromRGB(120, 120, 120),
	iconOn      = Color3.fromRGB(255, 255, 255),
	groupBg     = Color3.fromRGB(23, 23, 23),
	dotA        = Color3.fromRGB(12, 12, 12),
	dotB        = Color3.fromRGB(20, 20, 20),
	topMini     = Color3.fromRGB(40, 40, 40),
	checkOn     = Color3.fromRGB(0, 200, 0),
	checkOff    = Color3.fromRGB(35, 35, 35),
	sliderBg    = Color3.fromRGB(8, 8, 8),
	sliderFill  = Color3.fromRGB(0, 200, 0),
	sliderFill2 = Color3.fromRGB(0, 255, 50),
	bindText    = Color3.fromRGB(180, 180, 180),
	bindRecording = Color3.fromRGB(255, 50, 50),
	contextBg   = Color3.fromRGB(20, 20, 20),
	contextBorder = Color3.fromRGB(50, 50, 50),
	contextHover = Color3.fromRGB(35, 35, 35),
	contextSelected = Color3.fromRGB(0, 200, 0),
	contextUnselected = Color3.fromRGB(120, 120, 120),
}

-- ==================== FUNCTIONAL VARIABLES ====================
local aimbotEnabled = false
local autofireEnabled = false
local keyHeld = false
local fov = 100
local showFOV = false
local wallCheckEnabled = true
local FriendList = {}
local NoVisualRecoilEnabled = false
local lastShotTime = 0
local RECOIL_TAIL = 0.3
local targetCFrame = Camera.CFrame
local silentAimEnabled = false
local silentAimTarget = nil
local lastSilentAimUpdate = 0
local SILENT_AIM_UPDATE_INTERVAL = 0.05
local aimlockKey = nil
local aimlockKeyName = "Not Set"
local aimlockKeyHeld = false
local aimlockMode = "On hotkey"
local isRecordingKeybind = false
local currentTarget = nil
local targetLocked = false
local NoFallEnabled = false
local NoFallConnection
local FALL_SPEED_THRESHOLD = -55
local SAFE_FALL_SPEED = -15

local Box_ESP_Enabled = false
local ESP_HPEnabled = false
local ESP_NameEnabled = false
local ESP_HPDynamicEnabled = false
local ESP_WeaponEnabled = false
local ESP_MaxDistance = 1500
local Settings = {ESP_Color = Color3.fromRGB(255, 0, 0), Friend_Color = Color3.fromRGB(0, 255, 0)}

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Thickness = 2
fovCircle.NumSides = 100

local ESP_HPText = {}
local ESP_NameText = {}
local ESP_WeaponText = {}
local ESP_Boxes = {}
local characterCache = {}
local viewportCache = {}
local playersInRange = {}
local lastDistanceCheck = 0
local DISTANCE_CHECK_INTERVAL = 0.25
local wallCheckCache = {}
local WALLCHECK_CACHE_TIME = 0.08

local frameCache = {
	mousePos = Vector2.new(),
	cameraPos = Vector3.new(),
	cameraCFrame = CFrame.new(),
	time = 0,
}

-- ==================== ALL LOGIC FUNCTIONS ====================
local function updateFrameCache()
	frameCache.mousePos = UIS:GetMouseLocation()
	frameCache.cameraCFrame = Camera.CFrame
	frameCache.cameraPos = Camera.CFrame.Position
	frameCache.time = tick()
end

local function monitorTool(tool)
	if not tool then return end
	tool.Activated:Connect(function()
		lastShotTime = tick()
		targetCFrame = Camera.CFrame
	end)
end

local function setupCharacter(char)
	char:WaitForChild("Humanoid")
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then monitorTool(tool) end
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then monitorTool(child) end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then lastShotTime = 0 end
	end)
end

lp.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	setupCharacter(char)
end)
if lp.Character then setupCharacter(lp.Character) end

local recoilHook = RunService.RenderStepped:Connect(function()
	if NoVisualRecoilEnabled then
		if (tick() - lastShotTime <= RECOIL_TAIL) then
			Camera.CFrame = targetCFrame
		else
			local char = lp.Character
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

local FOV_RADIUS = 100

local function InFOV(worldPos)
	local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
	if not onScreen then return false end
	local dist = (Vector2.new(screenPos.X, screenPos.Y) - frameCache.mousePos).Magnitude
	return dist <= FOV_RADIUS
end

local function WallCheckRaw(targetHead, localChar)
	if not wallCheckEnabled then return true end
	if not targetHead or not localChar then return false end
	if not InFOV(targetHead.Position) then return false end
	local origin = frameCache.cameraPos
	local direction = (targetHead.Position - origin).Unit
	local distanceToTarget = (targetHead.Position - origin).Magnitude
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {localChar, targetHead.Parent}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	local result1 = workspace:Raycast(origin, direction * distanceToTarget, rayParams)
	if not result1 then return true end
	local hit1 = result1.Instance
	if hit1:IsDescendantOf(targetHead.Parent) then return true end
	if hit1.Name == "DFrame" or hit1.ClassName == "DFrame" then
		local newOrigin = result1.Position + (direction * 0.5)
		local remainingDistance = distanceToTarget - (newOrigin - origin).Magnitude
		if remainingDistance > 0 then
			local result2 = workspace:Raycast(newOrigin, direction * remainingDistance, rayParams)
			if not result2 then return true end
			if result2.Instance:IsDescendantOf(targetHead.Parent) then return true end
			return false
		end
	end
	return false
end

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

local weaponBulletSpeeds = {
	["Beretta"] = 1624, ["Magnum"] = 2550, ["G-17"] = 1850,
	["UZI"] = 2250, ["UZI+"] = 2250, ["Mare"] = 2000,
	["Deagle"] = 2200, ["SKS"] = 3750, ["M1911"] = 2230,
	["AKS-74U"] = 3000, ["FNP-45"] = 1500, ["TEC-9"] = 2100,
	["MAC-10+"] = 2250, ["MAC-10"] = 2250, ["MP7"] = 2600,
	["Tommy+"] = 2225, ["Tommy"] = 2225,
}

local function getCurrentWeaponSpeed()
	local char = lp.Character
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
	local charStat = CharStats:FindFirstChild(targetCharacter.Name)
	if not charStat then return false end
	local downedValue = charStat:FindFirstChild("Downed")
	if downedValue and downedValue:IsA("BoolValue") then return downedValue.Value end
	return false
end

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

local function getNearestToCursor()
	local localChar = lp.Character
	if not localChar then return nil end
	local mousePos = frameCache.mousePos
	local candidates = {}
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= lp then
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
			if WallCheck(currentTarget, lp.Character, plr) then
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

local function updateSilentAimTarget()
	if not silentAimEnabled or not aimbotEnabled then
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
	local localChar = lp.Character
	if not localChar then silentAimTarget = nil return end
	local mousePos = frameCache.mousePos
	local candidates = {}
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= lp then
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
	if #candidates == 0 then silentAimTarget = nil return end
	table.sort(candidates, function(a, b) return a.dist < b.dist end)
	for _, c in ipairs(candidates) do
		if WallCheck(c.head, localChar, c.plr) then
			silentAimTarget = c.head
			return
		end
	end
	silentAimTarget = nil
end

local function startNoFall()
	if NoFallEnabled then return end
	NoFallEnabled = true
	NoFallConnection = RunService.Heartbeat:Connect(function()
		if not NoFallEnabled then return end
		local char = lp.Character
		if not char then return end
		local humanoid = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp then return end
		if humanoid.SeatPart or humanoid:GetState() == Enum.HumanoidStateType.Climbing then return end
		if hrp.Velocity.Y < FALL_SPEED_THRESHOLD then
			hrp.Velocity = Vector3.new(hrp.Velocity.X, SAFE_FALL_SPEED, hrp.Velocity.Z)
		end
	end)
end

local function stopNoFall()
	NoFallEnabled = false
	if NoFallConnection then NoFallConnection:Disconnect() NoFallConnection = nil end
end

local function isAimbotActive()
	if not aimbotEnabled then return false end
	if aimlockMode == "Always on" then return true
	elseif aimlockMode == "On hotkey" then return aimlockKeyHeld
	elseif aimlockMode == "Toggle" then return keyHeld
	elseif aimlockMode == "Off hotkey" then return not aimlockKeyHeld
	end
	return false
end

-- ==================== ESP FUNCTIONS ====================
local function cleanupPlayerESP(plr)
	if ESP_HPText[plr] then ESP_HPText[plr].Visible = false; ESP_HPText[plr]:Remove(); ESP_HPText[plr] = nil end
	if ESP_NameText[plr] then ESP_NameText[plr].Visible = false; ESP_NameText[plr]:Remove(); ESP_NameText[plr] = nil end
	if ESP_WeaponText[plr] then ESP_WeaponText[plr].Visible = false; ESP_WeaponText[plr]:Remove(); ESP_WeaponText[plr] = nil end
	if ESP_Boxes[plr] then
		if ESP_Boxes[plr].box then ESP_Boxes[plr].box.Visible = false; ESP_Boxes[plr].box:Remove() end
		if ESP_Boxes[plr].boxoutline then ESP_Boxes[plr].boxoutline.Visible = false; ESP_Boxes[plr].boxoutline:Remove() end
		ESP_Boxes[plr] = nil
	end
	characterCache[plr] = nil; viewportCache[plr] = nil; playersInRange[plr] = nil; wallCheckCache[plr] = nil
end

local function hidePlayerESP(plr)
	if ESP_HPText[plr] then ESP_HPText[plr].Visible = false end
	if ESP_NameText[plr] then ESP_NameText[plr].Visible = false end
	if ESP_WeaponText[plr] then ESP_WeaponText[plr].Visible = false end
	if ESP_Boxes[plr] then ESP_Boxes[plr].box.Visible = false; ESP_Boxes[plr].boxoutline.Visible = false end
end

local function createESPObjects(plr)
	cleanupPlayerESP(plr)
	local hpText = Drawing.new("Text"); hpText.Visible = false; hpText.Color = Settings.ESP_Color; hpText.Size = 14; hpText.Center = true; hpText.Outline = true; ESP_HPText[plr] = hpText
	local nameText = Drawing.new("Text"); nameText.Visible = false; nameText.Color = Settings.ESP_Color; nameText.Size = 9; nameText.Center = true; nameText.Outline = true; ESP_NameText[plr] = nameText
	local weaponText = Drawing.new("Text"); weaponText.Visible = false; weaponText.Color = Settings.ESP_Color; weaponText.Size = 12; weaponText.Center = true; weaponText.Outline = true; ESP_WeaponText[plr] = weaponText
	local box = Drawing.new("Square"); box.Visible = false; box.Thickness = 1; box.Color = Settings.ESP_Color
	local boxoutline = Drawing.new("Square"); boxoutline.Visible = false; boxoutline.Thickness = 1; boxoutline.Color = Color3.new(0, 0, 0)
	ESP_Boxes[plr] = {box = box, boxoutline = boxoutline}
	characterCache[plr] = plr.Character
end

local function updatePlayersInRangeCache()
	local currentTime = frameCache.time
	if currentTime - lastDistanceCheck < DISTANCE_CHECK_INTERVAL then return end
	lastDistanceCheck = currentTime
	local cameraPos = frameCache.cameraPos
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= lp and plr.Character then
			local char = plr.Character
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local humanoid = char:FindFirstChild("Humanoid")
			if hrp and humanoid and humanoid.Health > 0 then
				local dist = (cameraPos - hrp.Position).Magnitude
				playersInRange[plr] = dist <= ESP_MaxDistance
				if not playersInRange[plr] then hidePlayerESP(plr) end
			else playersInRange[plr] = false end
		else playersInRange[plr] = false end
	end
end

local function get3DBoxCorners(hrp)
	local cf = hrp.CFrame
	return {cf * Vector3.new(-2, 3, 0), cf * Vector3.new(2, 3, 0), cf * Vector3.new(-2, -3, 0), cf * Vector3.new(2, -3, 0)}
end

local function cacheViewportPoints()
	viewportCache = {}
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= lp and playersInRange[plr] then
			local char = plr.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local humanoid = char:FindFirstChild("Humanoid")
				if hrp and humanoid and humanoid.Health > 0 then
					local data = {head = nil, boxCorners = {}, anyVisible = false}
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
	if not ESP_HPEnabled and not ESP_NameEnabled and not ESP_WeaponEnabled and not Box_ESP_Enabled then hidePlayerESP(plr) return end
	local char = plr.Character
	if not char then cleanupPlayerESP(plr) return end
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then cleanupPlayerESP(plr) return end
	if not ESP_HPText[plr] then createESPObjects(plr) end
	if characterCache[plr] ~= char then characterCache[plr] = char end
	local data = viewportCache[plr]
	if not data or not data.anyVisible then hidePlayerESP(plr) return end
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
		elseif hpText then hpText.Visible = false end
		if ESP_NameEnabled and nameText then
			nameText.Position = Vector2.new(headPos.X, headPos.Y - 15)
			nameText.Text = plr.Name
			nameText.Color = color
			nameText.Visible = true
		elseif nameText then nameText.Visible = false end
		if ESP_WeaponEnabled and weaponText then
			local tool = char:FindFirstChildOfClass("Tool")
			weaponText.Position = Vector2.new(headPos.X, headPos.Y + 15)
			weaponText.Text = tool and tool.Name or "None"
			weaponText.Color = color
			weaponText.Visible = true
		elseif weaponText then weaponText.Visible = false end
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
				boxes.boxoutline.Color = Color3.new(0, 0, 0)
				boxes.boxoutline.Visible = true
			else boxes.box.Visible = false; boxes.boxoutline.Visible = false end
		else boxes.box.Visible = false; boxes.boxoutline.Visible = false end
	elseif boxes then boxes.box.Visible = false; boxes.boxoutline.Visible = false end
end

local function initPlayer(plr)
	if plr == lp then return end
	plr.CharacterAdded:Connect(function() cleanupPlayerESP(plr) end)
end
for _, plr in pairs(Players:GetPlayers()) do if plr ~= lp then initPlayer(plr) end end
Players.PlayerAdded:Connect(function(plr) if plr ~= lp then initPlayer(plr) end end)
Players.PlayerRemoving:Connect(function(plr) cleanupPlayerESP(plr) end)

-- ==================== UI BUILD ====================
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function gradient(parent, rotation, seq)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 0
	g.Color = seq
	g.Parent = parent
	return g
end

local function addDotPattern(parent, colorA, colorB, tile)
	local img = Instance.new("ImageLabel")
	img.Name = "DotPattern"
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Position = UDim2.fromOffset(0, 0)
	img.BorderSizePixel = 0
	img.ZIndex = parent.ZIndex
	img.Image = "rbxassetid://9968344105"
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(tile or 6, tile or 6)
	img.ImageColor3 = colorB or Color3.fromRGB(20, 20, 20)
	img.Parent = parent
	local base = Instance.new("Frame")
	base.Name = "DotBase"
	base.BackgroundColor3 = colorA or Color3.fromRGB(12, 12, 12)
	base.BorderSizePixel = 0
	base.Size = UDim2.new(1, 0, 1, 0)
	base.ZIndex = math.max((parent.ZIndex or 1) - 1, 0)
	base.Parent = parent
	return base, img
end

local sliderDragging = false

local main = mk("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(658, 558),
	Position = UDim2.new(0.5, -329, 0.5, -279),
	BackgroundColor3 = C.outer,
	BorderSizePixel = 0,
	ClipsDescendants = true
}, gui)

local border1 = mk("Frame", {
	Size = UDim2.new(1, -2, 1, -2),
	Position = UDim2.fromOffset(1, 1),
	BackgroundColor3 = C.inner,
	BorderSizePixel = 0
}, main)

local border2 = mk("Frame", {
	Size = UDim2.new(1, -2, 1, -2),
	Position = UDim2.fromOffset(1, 1),
	BackgroundColor3 = C.bg0,
	BorderSizePixel = 0
}, border1)

local body = mk("Frame", {
	Size = UDim2.new(1, -4, 1, -4),
	Position = UDim2.fromOffset(2, 2),
	BackgroundColor3 = C.dotA,
	BorderSizePixel = 0,
	ClipsDescendants = true
}, border2)

addDotPattern(body, C.dotA, C.dotB, 6)

mk("Frame", {
	Size = UDim2.new(1, 0, 0, 3),
	Position = UDim2.fromOffset(0, 0),
	BackgroundColor3 = C.topMini,
	BorderSizePixel = 0,
	ZIndex = 50
}, body)

local contentHeight = 530
local contentYStart = 20

local side = mk("Frame", {
	Size = UDim2.fromOffset(75, contentHeight),
	Position = UDim2.fromOffset(0, contentYStart),
	BackgroundColor3 = C.side,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 2
}, body)

mk("Frame", {
	Size = UDim2.new(0, 1, 1, 0),
	Position = UDim2.new(1, -1, 0, 0),
	BackgroundColor3 = C.divider,
	BorderSizePixel = 0,
	ZIndex = 3
}, side)

local content = mk("Frame", {
	Size = UDim2.fromOffset(570, contentHeight),
	Position = UDim2.fromOffset(82, contentYStart),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 2
}, body)

local pageHolder = mk("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 2
}, content)

local iconHolder = mk("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 20
}, side)

local dragZone = mk("Frame", {
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	ZIndex = 200
}, body)

local topPadding = 20
local bottomPadding = 30
local iconSize = 36
local buttonWidth = 50
local countIcons = #ICONS
local availableHeight = contentHeight - topPadding - bottomPadding - (countIcons * iconSize)
local gapIcons = math.max(availableHeight / (countIcons - 1), 2)

local tabButtons = {}
local pages = {}
local activeContextMenu = nil

local function closeActiveContext()
	if activeContextMenu then
		activeContextMenu:Destroy()
		activeContextMenu = nil
	end
end

-- ==================== UI COMPONENTS ====================
local TEXT_OFFSET = 22

local function createCheckboxWithBind(parent, yPos, labelText, defaultValue, bindText, onToggle, onBindClick, onContextSelect, getCurrentMode)
	local ROW_HEIGHT = 18
	local container = mk("Frame", {
		Size = UDim2.new(1, -16, 0, ROW_HEIGHT),
		Position = UDim2.fromOffset(8, yPos),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, parent)

	local checkBox = mk("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = defaultValue and C.checkOn or C.checkOff,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, container)

	mk("UIStroke", {
		Color = Color3.fromRGB(3, 3, 3),
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, checkBox)

	mk("TextLabel", {
		Size = UDim2.new(1, -55, 1, 0),
		Position = UDim2.fromOffset(TEXT_OFFSET, 0),
		BackgroundTransparency = 1,
		Text = labelText,
		Font = MENU_FONT,
		TextSize = 13,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = false,
		ZIndex = 6,
	}, container)

	-- Bind as plain text, no background box
	local bindLabel = mk("TextLabel", {
		Size = UDim2.fromOffset(40, 14),
		Position = UDim2.new(1, -40, 0, 2),
		BackgroundTransparency = 1,
		Text = bindText or "[-]",
		Font = MENU_FONT,
		TextSize = 11,
		TextColor3 = C.bindText,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
	}, container)

	-- Invisible button over bind text for clicks
	local bindClickArea = mk("TextButton", {
		Size = UDim2.fromOffset(40, 18),
		Position = UDim2.new(1, -40, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 9,
	}, container)

	local clickArea = mk("TextButton", {
		Size = UDim2.new(1, -45, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 8,
	}, container)

	local enabled = defaultValue

	clickArea.MouseButton1Click:Connect(function()
		enabled = not enabled
		checkBox.BackgroundColor3 = enabled and C.checkOn or C.checkOff
		if onToggle then onToggle(enabled) end
	end)

	bindClickArea.MouseButton1Click:Connect(function()
		if onBindClick then onBindClick(bindLabel) end
	end)

	bindClickArea.MouseButton2Click:Connect(function()
		closeActiveContext()

		local modes = {"Always on", "On hotkey", "Toggle", "Off hotkey"}
		local ctxHeight = #modes * 20 + 6
		local ctxWidth = 90

		local absPos = bindLabel.AbsolutePosition
		local ctx = mk("Frame", {
			Size = UDim2.fromOffset(ctxWidth, ctxHeight),
			Position = UDim2.fromOffset(absPos.X - ctxWidth - 5, absPos.Y),
			BackgroundColor3 = C.contextBg,
			BorderSizePixel = 0,
			ZIndex = 500,
		}, gui)

		mk("UIStroke", {
			Color = C.contextBorder,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, ctx)

		activeContextMenu = ctx

		for i, mode in ipairs(modes) do
			local currentMode = getCurrentMode and getCurrentMode() or "On hotkey"
			local isSelected = (mode == currentMode)

			local itemBtn = mk("TextButton", {
				Size = UDim2.new(1, -6, 0, 18),
				Position = UDim2.fromOffset(3, 3 + (i - 1) * 20),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 501,
			}, ctx)

			mk("TextLabel", {
				Size = UDim2.new(1, -4, 1, 0),
				Position = UDim2.fromOffset(4, 0),
				BackgroundTransparency = 1,
				Text = mode,
				Font = MENU_FONT,
				TextSize = 11,
				TextColor3 = isSelected and C.contextSelected or C.contextUnselected,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 502,
			}, itemBtn)

			itemBtn.MouseEnter:Connect(function()
				itemBtn.BackgroundTransparency = 0
				itemBtn.BackgroundColor3 = C.contextHover
			end)

			itemBtn.MouseLeave:Connect(function()
				itemBtn.BackgroundTransparency = 1
			end)

			itemBtn.MouseButton1Click:Connect(function()
				if onContextSelect then onContextSelect(mode) end
				closeActiveContext()
			end)
		end

		task.spawn(function()
			task.wait(0.1)
			local conn
			conn = UIS.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
					task.wait(0.05)
					if activeContextMenu == ctx then
						local mousePos = UIS:GetMouseLocation()
						local ctxPos = ctx.AbsolutePosition
						local ctxSize = ctx.AbsoluteSize
						if mousePos.X < ctxPos.X or mousePos.X > ctxPos.X + ctxSize.X or mousePos.Y < ctxPos.Y or mousePos.Y > ctxPos.Y + ctxSize.Y then
							closeActiveContext()
							conn:Disconnect()
						end
					else
						conn:Disconnect()
					end
				end
			end)
		end)
	end)

	return {
		container = container,
		checkBox = checkBox,
		bindLabel = bindLabel,
		setEnabled = function(val)
			enabled = val
			checkBox.BackgroundColor3 = enabled and C.checkOn or C.checkOff
		end,
		getEnabled = function() return enabled end,
		setBindText = function(txt) bindLabel.Text = txt end,
	}
end

local function createCheckbox(parent, yPos, labelText, defaultValue, onToggle)
	local ROW_HEIGHT = 18
	local container = mk("Frame", {
		Size = UDim2.new(1, -16, 0, ROW_HEIGHT),
		Position = UDim2.fromOffset(8, yPos),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, parent)

	local checkBox = mk("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = defaultValue and C.checkOn or C.checkOff,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, container)

	mk("UIStroke", {
		Color = Color3.fromRGB(3, 3, 3),
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, checkBox)

	mk("TextLabel", {
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(TEXT_OFFSET, 0),
		BackgroundTransparency = 1,
		Text = labelText,
		Font = MENU_FONT,
		TextSize = 13,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = false,
		ZIndex = 6,
	}, container)

	local clickArea = mk("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 8,
	}, container)

	local enabled = defaultValue

	clickArea.MouseButton1Click:Connect(function()
		enabled = not enabled
		checkBox.BackgroundColor3 = enabled and C.checkOn or C.checkOff
		if onToggle then onToggle(enabled) end
	end)

	return {
		container = container,
		checkBox = checkBox,
		setEnabled = function(val)
			enabled = val
			checkBox.BackgroundColor3 = enabled and C.checkOn or C.checkOff
		end,
		getEnabled = function() return enabled end,
	}
end

local function createSlider(parent, yPos, labelText, minVal, maxVal, defaultVal, suffix, onChanged)
	local ROW_HEIGHT = 32
	local container = mk("Frame", {
		Size = UDim2.new(1, -16, 0, ROW_HEIGHT),
		Position = UDim2.fromOffset(8, yPos),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, parent)

	mk("TextLabel", {
		Size = UDim2.new(0.6, 0, 0, 14),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = labelText,
		Font = MENU_FONT,
		TextSize = 13,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = false,
		ZIndex = 6,
	}, container)

	local valueLabel = mk("TextLabel", {
		Size = UDim2.new(0.4, 0, 0, 14),
		Position = UDim2.new(0.6, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(defaultVal) .. (suffix or ""),
		Font = MENU_FONT,
		TextSize = 13,
		TextColor3 = C.textDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 6,
	}, container)

	local sliderTrack = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.fromOffset(0, 18),
		BackgroundColor3 = C.sliderBg,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, container)

	mk("UIStroke", {
		Color = Color3.fromRGB(3, 3, 3),
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, sliderTrack)

	local fillPercent = (defaultVal - minVal) / (maxVal - minVal)
	local sliderFill = mk("Frame", {
		Size = UDim2.new(fillPercent, 0, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = C.sliderFill,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, sliderTrack)

	gradient(sliderFill, 0, ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.sliderFill),
		ColorSequenceKeypoint.new(1, C.sliderFill2),
	}))

	local currentValue = defaultVal
	local dragging = false

	local function updateSlider(inputX)
		local trackPos = sliderTrack.AbsolutePosition.X
		local trackSize = sliderTrack.AbsoluteSize.X
		if trackSize == 0 then return end
		local percent = math.clamp((inputX - trackPos) / trackSize, 0, 1)
		local value = math.floor(minVal + (maxVal - minVal) * percent)
		currentValue = value
		sliderFill.Size = UDim2.new(percent, 0, 1, 0)
		valueLabel.Text = tostring(value) .. (suffix or "")
		if onChanged then onChanged(value) end
	end

	local sliderBtn = mk("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 9,
	}, sliderTrack)

	sliderBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			sliderDragging = true
			updateSlider(input.Position.X)
		end
	end)

	sliderBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			sliderDragging = false
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSlider(input.Position.X)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			dragging = false
			sliderDragging = false
		end
	end)

	return {
		container = container,
		getValue = function() return currentValue end,
		setValue = function(val)
			currentValue = val
			local percent = (val - minVal) / (maxVal - minVal)
			sliderFill.Size = UDim2.new(percent, 0, 1, 0)
			valueLabel.Text = tostring(val) .. (suffix or "")
		end,
	}
end

-- ==================== GROUP BUILDER ====================
local function createGroup(parent, x, y, w, h, titleText)
	local g0 = mk("Frame", {
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.fromOffset(x, y),
		BackgroundColor3 = C.bg0,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, parent)

	local g1 = mk("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundColor3 = C.inner,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, g0)

	local g2 = mk("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundColor3 = C.groupBg,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = false,
	}, g1)

	local titleBack = mk("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		Position = UDim2.fromOffset(8, -7),
		BackgroundColor3 = C.groupBg,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, g2)

	mk("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		Text = " " .. titleText .. " ",
		Font = MENU_FONT,
		TextSize = 13,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, titleBack)

	return g2
end

-- ==================== PAGE 1 (RAGEBOT) ====================
local function buildRagebotPage(parent)
	local pageTopPadding = 5
	local pageBottomPadding = 10
	local leftX = 6
	local rightX = 290
	local groupGap = 10
	local totalH = contentHeight - pageTopPadding - pageBottomPadding

	local weaponGroupH = 40
	local aimbotGroupH = totalH - weaponGroupH - groupGap

	createGroup(parent, leftX, pageTopPadding, 274, weaponGroupH, "Weapon type")

	local aimbotGroup = createGroup(parent, leftX, pageTopPadding + weaponGroupH + groupGap, 274, aimbotGroupH, "Aimbot")

	createCheckboxWithBind(
		aimbotGroup, 12, "Enabled", false,
		"[-]",
		function(val)
			aimbotEnabled = val
			if not val then
				currentTarget = nil
				targetLocked = false
			end
		end,
		function(bindLabel)
			isRecordingKeybind = true
			bindLabel.Text = "[-]"
			bindLabel.TextColor3 = C.bindRecording
			local conn
			conn = UIS.InputBegan:Connect(function(input)
				if isRecordingKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
					isRecordingKeybind = false
					conn:Disconnect()
					aimlockKey = input.KeyCode
					aimlockKeyName = input.KeyCode.Name
					bindLabel.Text = "[" .. aimlockKeyName .. "]"
					bindLabel.TextColor3 = C.bindText
				end
			end)
			task.delay(5, function()
				if isRecordingKeybind then
					isRecordingKeybind = false
					if conn then conn:Disconnect() end
					bindLabel.Text = aimlockKey and ("[" .. aimlockKeyName .. "]") or "[-]"
					bindLabel.TextColor3 = C.bindText
				end
			end)
		end,
		function(mode)
			aimlockMode = mode
		end,
		function()
			return aimlockMode
		end
	)

	createCheckbox(aimbotGroup, 34, "Silent aim", false, function(val)
		silentAimEnabled = val
		if not val then silentAimTarget = nil end
	end)

	local otherGroup = createGroup(parent, rightX, pageTopPadding, 274, totalH, "Other")

	local y = 12
	createCheckbox(otherGroup, y, "Wallcheck", true, function(val) wallCheckEnabled = val end)
	y = y + 22
	createCheckbox(otherGroup, y, "Autofire", false, function(val) autofireEnabled = val end)
	y = y + 22
	createCheckbox(otherGroup, y, "Remove recoil", false, function(val)
		if val then activateNoVisualRecoil() else deactivateNoVisualRecoil() end
	end)
	y = y + 28
	createSlider(otherGroup, y, "FOV", 50, 500, 100, "px", function(val)
		fov = val
		FOV_RADIUS = val
	end)
	y = y + 38
	createCheckbox(otherGroup, y, "Show FOV", false, function(val) showFOV = val end)
end

-- ==================== PAGE 4 (ESP + MISC) ====================
local function buildESPPage(parent)
	local pageTopPadding = 5
	local pageBottomPadding = 10
	local leftX = 6
	local rightX = 290
	local totalH = contentHeight - pageTopPadding - pageBottomPadding

	local espGroup = createGroup(parent, leftX, pageTopPadding, 274, totalH, "ESP Settings")

	local y = 12
	createCheckbox(espGroup, y, "Health ESP", false, function(val) ESP_HPEnabled = val end)
	y = y + 22
	createCheckbox(espGroup, y, "Dynamic HP color", false, function(val) ESP_HPDynamicEnabled = val end)
	y = y + 22
	createCheckbox(espGroup, y, "Box ESP", false, function(val) Box_ESP_Enabled = val end)
	y = y + 22
	createCheckbox(espGroup, y, "Name ESP", false, function(val) ESP_NameEnabled = val end)
	y = y + 22
	createCheckbox(espGroup, y, "Weapon ESP", false, function(val) ESP_WeaponEnabled = val end)
	y = y + 28
	createSlider(espGroup, y, "Max distance", 1, 1500, 1500, " studs", function(val) ESP_MaxDistance = val end)

	local otherGroup = createGroup(parent, rightX, pageTopPadding, 274, totalH, "Other")

	createCheckbox(otherGroup, 12, "NoFall protection", false, function(val)
		if val then startNoFall() else stopNoFall() end
	end)
end

-- ==================== DEFAULT PAGE ====================
local function buildDefaultPage(parent)
	local pageTopPadding = 5
	local pageBottomPadding = 10
	local leftX = 6
	local rightX = 290
	local groupGap = 10
	local totalH = contentHeight - pageTopPadding - pageBottomPadding

	local leftTopH = math.floor(totalH * 0.45)
	local leftBottomH = totalH - leftTopH - groupGap

	local rightTopH = math.floor(totalH * 0.3)
	local rightMidH = math.floor(totalH * 0.3)
	local rightBottomH = totalH - rightTopH - rightMidH - (groupGap * 2)

	createGroup(parent, leftX, pageTopPadding, 274, leftTopH, "Group A")
	createGroup(parent, leftX, pageTopPadding + leftTopH + groupGap, 274, leftBottomH, "Group B")
	createGroup(parent, rightX, pageTopPadding, 274, rightTopH, "Group C")
	createGroup(parent, rightX, pageTopPadding + rightTopH + groupGap, 274, rightMidH, "Group D")
	createGroup(parent, rightX, pageTopPadding + rightTopH + groupGap + rightMidH + groupGap, 274, rightBottomH, "Group E")
end

-- ==================== CREATE TABS ====================
local function createTab(index, imageId)
	local y = math.floor(topPadding + (index - 1) * (iconSize + gapIcons))

	local holder = mk("TextButton", {
		Name = "TabButton_" .. index,
		Size = UDim2.fromOffset(buttonWidth, iconSize),
		Position = UDim2.fromOffset(12, y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 21,
	}, iconHolder)

	local icon = mk("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(36, 36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1,
		Image = imageId,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 22,
	}, holder)

	local page = mk("Frame", {
		Name = "Page_" .. index,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
	}, pageHolder)

	if index == 1 then
		buildRagebotPage(page)
	elseif index == 4 then
		buildESPPage(page)
	else
		buildDefaultPage(page)
	end

	tabButtons[index] = {button = holder, icon = icon}
	pages[index] = page

	holder.MouseButton1Click:Connect(function()
		closeActiveContext()
		for i = 1, #tabButtons do
			tabButtons[i].icon.ImageColor3 = (i == index) and C.iconOn or Color3.new(1, 1, 1)
			pages[i].Visible = (i == index)
		end
	end)
end

for i, id in ipairs(ICONS) do
	createTab(i, id)
end

for i = 1, #tabButtons do
	tabButtons[i].icon.ImageColor3 = (i == 1) and C.iconOn or Color3.new(1, 1, 1)
	pages[i].Visible = (i == 1)
end

local topLine = mk("Frame", {
	Size = UDim2.new(1, -2, 0, 2),
	Position = UDim2.fromOffset(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 100,
}, body)

gradient(topLine, 0, ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(55, 170, 255)),
	ColorSequenceKeypoint.new(0.18, Color3.fromRGB(80, 120, 255)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(150, 85, 255)),
	ColorSequenceKeypoint.new(0.53, Color3.fromRGB(255, 90, 210)),
	ColorSequenceKeypoint.new(0.76, Color3.fromRGB(255, 155, 70)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(170, 255, 0)),
}))

-- Dragging
do
	local dragging = false
	local dragStart, startPos

	dragZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not sliderDragging then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)

	dragZone.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and not sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- ==================== INPUT ====================
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.K then
		gui.Enabled = not gui.Enabled
		return
	end
	if isRecordingKeybind then return end
	if aimlockKey and input.KeyCode == aimlockKey then
		aimlockKeyHeld = true
		if aimlockMode == "Toggle" then
			keyHeld = not keyHeld
		elseif aimlockMode == "On hotkey" then
			keyHeld = true
			currentTarget = nil
			targetLocked = false
		elseif aimlockMode == "Off hotkey" then
			keyHeld = false
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if aimlockKey and input.KeyCode == aimlockKey then
		aimlockKeyHeld = false
		if aimlockMode == "On hotkey" then
			keyHeld = false
			currentTarget = nil
			targetLocked = false
		elseif aimlockMode == "Off hotkey" then
			keyHeld = true
		end
	end
end)

-- ==================== MAIN RENDER LOOP ====================
local currentTool
local lastSilentShot = 0
local SILENT_FIRE_RATE = 0.08

RunService.RenderStepped:Connect(function()
	updateFrameCache()

	local aimActive = isAimbotActive()

	if silentAimEnabled and aimActive then
		updateSilentAimTarget()
		if silentAimTarget then
			local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
			if tool and (tick() - lastSilentShot >= SILENT_FIRE_RATE) then
				lastSilentShot = tick()
				local savedCFrame = Camera.CFrame
				local predictedPos = getPredictedPosition(silentAimTarget)
				Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
				tool:Activate()
				Camera.CFrame = savedCFrame
			end
		end
	else
		silentAimTarget = nil
	end

	if aimbotEnabled and showFOV then
		local mousePos = frameCache.mousePos
		fovCircle.Position = mousePos
		fovCircle.Radius = fov
		fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end

	if aimbotEnabled and not silentAimEnabled and aimActive then
		local targetHead = getTarget()
		if targetHead then
			local plr = Players:GetPlayerFromCharacter(targetHead.Parent)
			local validTarget = plr and isValidTarget(plr, targetHead)
			if validTarget then
				Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, getPredictedPosition(targetHead))
				if autofireEnabled then
					currentTool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
					if currentTool then currentTool:Activate() end
				end
			else
				currentTarget = nil
				targetLocked = false
				if currentTool then currentTool:Deactivate(); currentTool = nil end
			end
		else
			if currentTool then currentTool:Deactivate(); currentTool = nil end
		end
	else
		if not silentAimEnabled and currentTool then currentTool:Deactivate(); currentTool = nil end
		if not aimActive then currentTarget = nil; targetLocked = false end
	end

	updatePlayersInRangeCache()
	cacheViewportPoints()
	for plr, isInRange in pairs(playersInRange) do
		if isInRange then updatePlayerESP(plr) else hidePlayerESP(plr) end
	end
end)
