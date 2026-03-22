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
"rbxassetid://105116724761033",
"rbxassetid://132839343837016",
"rbxassetid://115681878826468",
"rbxassetid://76086521145727",
"rbxassetid://87119088029378",
"rbxassetid://99464706835476",
"rbxassetid://70641337583472",
"rbxassetid://125924680442149"
}
local C = {
outer=Color3.fromRGB(3,3,3),inner=Color3.fromRGB(47,47,47),bg0=Color3.fromRGB(8,8,8),
side=Color3.fromRGB(12,12,12),divider=Color3.fromRGB(34,34,34),text=Color3.fromRGB(214,214,214),
textDim=Color3.fromRGB(120,120,120),iconOn=Color3.fromRGB(255,255,255),groupBg=Color3.fromRGB(23,23,23),
dotA=Color3.fromRGB(12,12,12),dotB=Color3.fromRGB(20,20,20),topMini=Color3.fromRGB(40,40,40),
checkOn=Color3.fromRGB(156,199,40),checkOff=Color3.fromRGB(35,35,35),sliderBg=Color3.fromRGB(8,8,8),
sliderFill=Color3.fromRGB(156,199,40),sliderFill2=Color3.fromRGB(180,220,60),
bindText=Color3.fromRGB(180,180,180),bindRecording=Color3.fromRGB(255,50,50),
contextBg=Color3.fromRGB(20,20,20),contextBorder=Color3.fromRGB(50,50,50),
contextHover=Color3.fromRGB(35,35,35),contextSelected=Color3.fromRGB(156,199,40),
contextUnselected=Color3.fromRGB(120,120,120),pickerBorder=Color3.fromRGB(3,3,3),
greenText=Color3.fromRGB(156,199,40),
groupLine=Color3.fromRGB(55,55,55),
triangleColor=Color3.fromRGB(55,55,55),
}

local aimbotEnabled=false
local autofireEnabled=false
local keyHeld=false
local fovDegrees=180
local showFOV=false
local fovColor=Color3.new(1,1,1)
local wallCheckEnabled=true
local FriendList={}
local NoVisualRecoilEnabled=false
local lastShotTime=0
local RECOIL_TAIL=0.3
local targetCFrame=Camera.CFrame
local silentAimEnabled=false
local silentAimTarget=nil
local lastSilentAimUpdate=0
local SILENT_AIM_UPDATE_INTERVAL=0.05
local aimlockKey=nil
local aimlockKeyName="Not Set"
local aimlockKeyHeld=false
local aimlockMode="On hotkey"
local isRecordingKeybind=false
local currentTarget=nil
local targetLocked=false
local NoFallEnabled=false
local NoFallConnection
local FALL_SPEED_THRESHOLD=-55
local SAFE_FALL_SPEED=-15
local espVisualEnabled=false
local espVisualKey=nil
local espVisualKeyName="Not Set"
local isRecordingESPKeybind=false
local espVisualMode="On hotkey"
local espVisualKeyHeld=false
local espVisualToggled=false
local Box_ESP_Enabled=false
local ESP_HPEnabled=false
local ESP_NameEnabled=false
local ESP_HPDynamicEnabled=false
local ESP_WeaponEnabled=false
local ESP_MaxDistance=1500
local Settings={
ESP_Color=Color3.fromRGB(255,0,0),Friend_Color=Color3.fromRGB(0,255,0),
Box_Color=Color3.fromRGB(255,0,0),HP_Color=Color3.fromRGB(255,0,0),
Name_Color=Color3.fromRGB(255,0,0),Weapon_Color=Color3.fromRGB(255,0,0)
}

local playerPageData={selectedPlayer=nil,playerSettings={},buttons={},searchText=""}

local function getPlayerSettings(plrName)
if not playerPageData.playerSettings[plrName] then
playerPageData.playerSettings[plrName]={
whitelisted=false,teamColor=false,disableVisuals=false,
boxColor=nil,nameColor=nil,hpColor=nil,weaponColor=nil,
}
end
return playerPageData.playerSettings[plrName]
end

local function getEffectiveColor(plrName,colorType)
local ps=playerPageData.playerSettings[plrName]
if ps then
if ps.disableVisuals then return nil end
if ps[colorType] then return ps[colorType] end
if ps.teamColor then return Color3.fromRGB(0,255,0) end
end
if colorType=="boxColor" then return Settings.Box_Color
elseif colorType=="hpColor" then return Settings.HP_Color
elseif colorType=="nameColor" then return Settings.Name_Color
elseif colorType=="weaponColor" then return Settings.Weapon_Color end
return Color3.fromRGB(255,0,0)
end

local fovCircle=Drawing.new("Circle")
fovCircle.Visible=false;fovCircle.Color=fovColor;fovCircle.Thickness=2;fovCircle.NumSides=100

local ESP_HPText={}
local ESP_NameText={}
local ESP_WeaponText={}
local ESP_Boxes={}
local characterCache={}
local viewportCache={}
local playersInRange={}
local lastDistanceCheck=0
local DISTANCE_CHECK_INTERVAL=0.25
local wallCheckCache={}
local WALLCHECK_CACHE_TIME=0.08
local frameCache={mousePos=Vector2.new(),cameraPos=Vector3.new(),cameraCFrame=CFrame.new(),time=0}

local function getFOVPixelRadius()
if fovDegrees>=180 then return 9999 end
return math.tan(math.rad(fovDegrees/2))*((Camera.ViewportSize.Y/2)/math.tan(math.rad(35)))
end

local function updateFrameCache()
frameCache.mousePos=UIS:GetMouseLocation()
frameCache.cameraCFrame=Camera.CFrame
frameCache.cameraPos=Camera.CFrame.Position
frameCache.time=tick()
end

local function monitorTool(tool)
if not tool then return end
tool.Activated:Connect(function() lastShotTime=tick();targetCFrame=Camera.CFrame end)
end

local function setupCharacter(char)
char:WaitForChild("Humanoid")
local tool=char:FindFirstChildOfClass("Tool")
if tool then monitorTool(tool) end
char.ChildAdded:Connect(function(c) if c:IsA("Tool") then monitorTool(c) end end)
char.ChildRemoved:Connect(function(c) if c:IsA("Tool") then lastShotTime=0 end end)
end

lp.CharacterAdded:Connect(function(char) task.wait(0.5);setupCharacter(char) end)
if lp.Character then setupCharacter(lp.Character) end

RunService.RenderStepped:Connect(function()
if NoVisualRecoilEnabled then
if(tick()-lastShotTime<=RECOIL_TAIL) then Camera.CFrame=targetCFrame
else local char=lp.Character;if char and char:FindFirstChild("HumanoidRootPart") then targetCFrame=CFrame.new(Camera.CFrame.Position)*(targetCFrame-targetCFrame.Position) end end
end
end)

local function activateNoVisualRecoil() NoVisualRecoilEnabled=true;lastShotTime=0;targetCFrame=Camera.CFrame end
local function deactivateNoVisualRecoil() NoVisualRecoilEnabled=false;lastShotTime=0 end

local function InFOV(worldPos)
local sp,on=Camera:WorldToViewportPoint(worldPos)
if not on then return false end
if fovDegrees>=180 then return true end
return(Vector2.new(sp.X,sp.Y)-frameCache.mousePos).Magnitude<=getFOVPixelRadius()
end

local function WallCheckRaw(targetHead,localChar)
if not wallCheckEnabled then return true end
if not targetHead or not localChar then return false end
if not InFOV(targetHead.Position) then return false end
local origin=frameCache.cameraPos
local dir=(targetHead.Position-origin).Unit
local dist=(targetHead.Position-origin).Magnitude
local rp=RaycastParams.new()
rp.FilterDescendantsInstances={localChar,targetHead.Parent}
rp.FilterType=Enum.RaycastFilterType.Exclude;rp.IgnoreWater=true
local r1=workspace:Raycast(origin,dir*dist,rp)
if not r1 then return true end
if r1.Instance:IsDescendantOf(targetHead.Parent) then return true end
if r1.Instance.Name=="DFrame" or r1.Instance.ClassName=="DFrame" then
local no=r1.Position+(dir*0.5);local rem=dist-(no-origin).Magnitude
if rem>0 then local r2=workspace:Raycast(no,dir*rem,rp);if not r2 then return true end;if r2.Instance:IsDescendantOf(targetHead.Parent) then return true end end
end
return false
end

local function WallCheck(targetHead,localChar,plr)
if not wallCheckEnabled then return true end
if plr then local cached=wallCheckCache[plr];if cached and(frameCache.time-cached.time)<WALLCHECK_CACHE_TIME then return cached.result end end
local result=WallCheckRaw(targetHead,localChar)
if plr then wallCheckCache[plr]={result=result,time=frameCache.time} end
return result
end

local weaponBulletSpeeds={
["Beretta"]=1624,["Magnum"]=2550,["G-17"]=1850,["UZI"]=2250,["UZI+"]=2250,["Mare"]=2000,
["Deagle"]=2200,["SKS"]=3750,["M1911"]=2230,["AKS-74U"]=3000,["FNP-45"]=1500,["TEC-9"]=2100,
["MAC-10+"]=2250,["MAC-10"]=2250,["MP7"]=2600,["Tommy+"]=2225,["Tommy"]=2225,
}

local function getCurrentWeaponSpeed()
local char=lp.Character;if char then local t=char:FindFirstChildOfClass("Tool");if t then return weaponBulletSpeeds[t.Name] or 1624 end end;return 1624
end
local function isFriend(plr) for _,n in pairs(FriendList) do if plr.Name==n then return true end end;return false end
local function isTargetDowned(tc) local cs=CharStats:FindFirstChild(tc.Name);if not cs then return false end;local dv=cs:FindFirstChild("Downed");if dv and dv:IsA("BoolValue") then return dv.Value end;return false end
local function hasSpawnShield(plr) return plr.Character and plr.Character:FindFirstChildOfClass("ForceField")~=nil end
local function getPredictedPosition(target)
local hrp=target.Parent:FindFirstChild("HumanoidRootPart");if not hrp then return target.Position end
return target.Position+hrp.Velocity*((hrp.Position-frameCache.cameraPos).Magnitude/getCurrentWeaponSpeed())
end
local function isValidTarget(plr,head)
if not plr or not plr.Character or isFriend(plr) or not head then return false end
local h=plr.Character:FindFirstChild("Humanoid")
if not h or h.Health<=0 or hasSpawnShield(plr) or isTargetDowned(plr.Character) then return false end;return true
end

local function getNearestToCursor()
local lc=lp.Character;if not lc then return nil end
local mp=frameCache.mousePos;local pr=getFOVPixelRadius();local cands={}
for _,plr in pairs(Players:GetPlayers()) do
if plr~=lp and plr.Character then
local head=plr.Character:FindFirstChild("Head")
if head then local sp,on=Camera:WorldToViewportPoint(head.Position);if on then
local d=(Vector2.new(sp.X,sp.Y)-mp).Magnitude
if fovDegrees>=180 or d<=pr then if isValidTarget(plr,head) then cands[#cands+1]={plr=plr,head=head,dist=d} end end
end end
end
end
if #cands==0 then return nil end
table.sort(cands,function(a,b) return a.dist<b.dist end)
for _,c in ipairs(cands) do if WallCheck(c.head,lc,c.plr) then return c.head end end;return nil
end

local function getTarget()
if currentTarget and targetLocked then
local plr=Players:GetPlayerFromCharacter(currentTarget.Parent)
if not plr then currentTarget=nil;targetLocked=false;return nil end
if isValidTarget(plr,currentTarget) and WallCheck(currentTarget,lp.Character,plr) then return currentTarget end
currentTarget=nil;targetLocked=false;return nil
end
local nt=getNearestToCursor();if nt then currentTarget=nt;targetLocked=true end;return currentTarget
end

local function updateSilentAimTarget()
if not silentAimEnabled or not aimbotEnabled then silentAimTarget=nil;return end
local now=frameCache.time
if now-lastSilentAimUpdate<SILENT_AIM_UPDATE_INTERVAL then
if silentAimTarget then local plr=Players:GetPlayerFromCharacter(silentAimTarget.Parent);if not plr or not isValidTarget(plr,silentAimTarget) then silentAimTarget=nil end end;return
end
lastSilentAimUpdate=now;local lc=lp.Character;if not lc then silentAimTarget=nil;return end
local mp=frameCache.mousePos;local pr=getFOVPixelRadius();local cands={}
for _,plr in pairs(Players:GetPlayers()) do
if plr~=lp and plr.Character then local head=plr.Character:FindFirstChild("Head")
if head then local sp,on=Camera:WorldToViewportPoint(head.Position);if on then
local d=(Vector2.new(sp.X,sp.Y)-mp).Magnitude
if fovDegrees>=180 or d<=pr then if isValidTarget(plr,head) then cands[#cands+1]={plr=plr,head=head,dist=d} end end
end end
end
end
if #cands==0 then silentAimTarget=nil;return end
table.sort(cands,function(a,b) return a.dist<b.dist end)
for _,c in ipairs(cands) do if WallCheck(c.head,lc,c.plr) then silentAimTarget=c.head;return end end;silentAimTarget=nil
end

local function startNoFall()
if NoFallEnabled then return end;NoFallEnabled=true
NoFallConnection=RunService.Heartbeat:Connect(function()
if not NoFallEnabled then return end;local char=lp.Character;if not char then return end
local h=char:FindFirstChild("Humanoid");local hrp=char:FindFirstChild("HumanoidRootPart")
if not h or not hrp then return end
if h.SeatPart or h:GetState()==Enum.HumanoidStateType.Climbing then return end
if hrp.Velocity.Y<FALL_SPEED_THRESHOLD then hrp.Velocity=Vector3.new(hrp.Velocity.X,SAFE_FALL_SPEED,hrp.Velocity.Z) end
end)
end
local function stopNoFall() NoFallEnabled=false;if NoFallConnection then NoFallConnection:Disconnect();NoFallConnection=nil end end

local function isAimbotActive()
if not aimbotEnabled then return false end
if aimlockMode=="Always on" then return true
elseif aimlockMode=="On hotkey" then return aimlockKeyHeld
elseif aimlockMode=="Toggle" then return keyHeld
elseif aimlockMode=="Off hotkey" then return not aimlockKeyHeld end;return false
end

local function isESPActive()
if not espVisualEnabled then return false end
if espVisualMode=="Always on" then return true
elseif espVisualMode=="On hotkey" then return espVisualKeyHeld
elseif espVisualMode=="Toggle" then return espVisualToggled
elseif espVisualMode=="Off hotkey" then return not espVisualKeyHeld end;return false
end

local function cleanupPlayerESP(plr)
if ESP_HPText[plr] then ESP_HPText[plr].Visible=false;ESP_HPText[plr]:Remove();ESP_HPText[plr]=nil end
if ESP_NameText[plr] then ESP_NameText[plr].Visible=false;ESP_NameText[plr]:Remove();ESP_NameText[plr]=nil end
if ESP_WeaponText[plr] then ESP_WeaponText[plr].Visible=false;ESP_WeaponText[plr]:Remove();ESP_WeaponText[plr]=nil end
if ESP_Boxes[plr] then
if ESP_Boxes[plr].box then ESP_Boxes[plr].box.Visible=false;ESP_Boxes[plr].box:Remove() end
if ESP_Boxes[plr].boxoutline then ESP_Boxes[plr].boxoutline.Visible=false;ESP_Boxes[plr].boxoutline:Remove() end;ESP_Boxes[plr]=nil
end;characterCache[plr]=nil;viewportCache[plr]=nil;playersInRange[plr]=nil;wallCheckCache[plr]=nil
end
local function hidePlayerESP(plr)
if ESP_HPText[plr] then ESP_HPText[plr].Visible=false end
if ESP_NameText[plr] then ESP_NameText[plr].Visible=false end
if ESP_WeaponText[plr] then ESP_WeaponText[plr].Visible=false end
if ESP_Boxes[plr] then ESP_Boxes[plr].box.Visible=false;ESP_Boxes[plr].boxoutline.Visible=false end
end
local function createESPObjects(plr)
cleanupPlayerESP(plr)
ESP_HPText[plr]=Drawing.new("Text");ESP_HPText[plr].Visible=false;ESP_HPText[plr].Color=Settings.HP_Color;ESP_HPText[plr].Size=14;ESP_HPText[plr].Center=true;ESP_HPText[plr].Outline=true
ESP_NameText[plr]=Drawing.new("Text");ESP_NameText[plr].Visible=false;ESP_NameText[plr].Color=Settings.Name_Color;ESP_NameText[plr].Size=9;ESP_NameText[plr].Center=true;ESP_NameText[plr].Outline=true
ESP_WeaponText[plr]=Drawing.new("Text");ESP_WeaponText[plr].Visible=false;ESP_WeaponText[plr].Color=Settings.Weapon_Color;ESP_WeaponText[plr].Size=12;ESP_WeaponText[plr].Center=true;ESP_WeaponText[plr].Outline=true
local box=Drawing.new("Square");box.Visible=false;box.Thickness=1;box.Color=Settings.Box_Color
local bxo=Drawing.new("Square");bxo.Visible=false;bxo.Thickness=1;bxo.Color=Color3.new(0,0,0)
ESP_Boxes[plr]={box=box,boxoutline=bxo};characterCache[plr]=plr.Character
end
local function updatePlayersInRangeCache()
if frameCache.time-lastDistanceCheck<DISTANCE_CHECK_INTERVAL then return end;lastDistanceCheck=frameCache.time;local cp=frameCache.cameraPos
for _,plr in pairs(Players:GetPlayers()) do
if plr~=lp and plr.Character then local hrp=plr.Character:FindFirstChild("HumanoidRootPart");local h=plr.Character:FindFirstChild("Humanoid")
if hrp and h and h.Health>0 then playersInRange[plr]=(cp-hrp.Position).Magnitude<=ESP_MaxDistance;if not playersInRange[plr] then hidePlayerESP(plr) end
else playersInRange[plr]=false end
else playersInRange[plr]=false end
end
end
local function get3DBoxCorners(hrp) local cf=hrp.CFrame;return{cf*Vector3.new(-2,3,0),cf*Vector3.new(2,3,0),cf*Vector3.new(-2,-3,0),cf*Vector3.new(2,-3,0)} end
local function cacheViewportPoints()
viewportCache={}
for _,plr in pairs(Players:GetPlayers()) do
if plr~=lp and playersInRange[plr] and plr.Character then
local hrp=plr.Character:FindFirstChild("HumanoidRootPart");local h=plr.Character:FindFirstChild("Humanoid")
if hrp and h and h.Health>0 then
local data={head=nil,boxCorners={},anyVisible=false}
local head=plr.Character:FindFirstChild("Head")
if head then local hp,hv=Camera:WorldToViewportPoint(head.Position);data.head={pos=Vector2.new(hp.X,hp.Y),visible=hv,z=hp.Z};if hv then data.anyVisible=true end end
if Box_ESP_Enabled and data.anyVisible then for i,corner in ipairs(get3DBoxCorners(hrp)) do local p,v=Camera:WorldToViewportPoint(corner);data.boxCorners[i]={pos=Vector2.new(p.X,p.Y),visible=v,z=p.Z} end end
viewportCache[plr]=data
end
end
end
end

local function updatePlayerESP(plr)
if not isESPActive() then hidePlayerESP(plr);return end
local ps=playerPageData.playerSettings[plr.Name]
if ps and ps.disableVisuals then hidePlayerESP(plr);return end
if not ESP_HPEnabled and not ESP_NameEnabled and not ESP_WeaponEnabled and not Box_ESP_Enabled then hidePlayerESP(plr);return end
local char=plr.Character;if not char then cleanupPlayerESP(plr);return end
local h=char:FindFirstChild("Humanoid");if not h or h.Health<=0 then cleanupPlayerESP(plr);return end
if not ESP_HPText[plr] then createESPObjects(plr) end
local data=viewportCache[plr];if not data or not data.anyVisible then hidePlayerESP(plr);return end
local boxCol=getEffectiveColor(plr.Name,"boxColor")
local hpCol=getEffectiveColor(plr.Name,"hpColor")
local nameCol=getEffectiveColor(plr.Name,"nameColor")
local weapCol=getEffectiveColor(plr.Name,"weaponColor")
if data.head and data.head.visible then local hp2=data.head.pos
if ESP_HPEnabled then local hp=math.clamp(h.Health,0,h.MaxHealth);ESP_HPText[plr].Position=Vector2.new(hp2.X+20,hp2.Y);ESP_HPText[plr].Text=math.floor(hp).." HP";ESP_HPText[plr].Color=ESP_HPDynamicEnabled and Color3.fromHSV((hp/h.MaxHealth)/3,1,1) or hpCol;ESP_HPText[plr].Visible=true else ESP_HPText[plr].Visible=false end
if ESP_NameEnabled then ESP_NameText[plr].Position=Vector2.new(hp2.X,hp2.Y-15);ESP_NameText[plr].Text=plr.Name;ESP_NameText[plr].Color=nameCol;ESP_NameText[plr].Visible=true else ESP_NameText[plr].Visible=false end
if ESP_WeaponEnabled then local tool=char:FindFirstChildOfClass("Tool");ESP_WeaponText[plr].Position=Vector2.new(hp2.X,hp2.Y+15);ESP_WeaponText[plr].Text=tool and tool.Name or "None";ESP_WeaponText[plr].Color=weapCol;ESP_WeaponText[plr].Visible=true else ESP_WeaponText[plr].Visible=false end
else ESP_HPText[plr].Visible=false;ESP_NameText[plr].Visible=false;ESP_WeaponText[plr].Visible=false end
if Box_ESP_Enabled and ESP_Boxes[plr] then local bc=data.boxCorners
if bc and #bc>0 then local mnX,mnY,mxX,mxY=9e9,9e9,-9e9,-9e9;local av=false
for _,c in ipairs(bc) do if c.visible and c.z>0 then av=true;if c.pos.X<mnX then mnX=c.pos.X end;if c.pos.Y<mnY then mnY=c.pos.Y end;if c.pos.X>mxX then mxX=c.pos.X end;if c.pos.Y>mxY then mxY=c.pos.Y end end end
if av then local w,hh=mxX-mnX,mxY-mnY;ESP_Boxes[plr].box.Position=Vector2.new(mnX,mnY);ESP_Boxes[plr].box.Size=Vector2.new(w,hh);ESP_Boxes[plr].box.Color=boxCol;ESP_Boxes[plr].box.Visible=true;ESP_Boxes[plr].boxoutline.Position=Vector2.new(mnX-1,mnY-1);ESP_Boxes[plr].boxoutline.Size=Vector2.new(w+2,hh+2);ESP_Boxes[plr].boxoutline.Color=Color3.new(0,0,0);ESP_Boxes[plr].boxoutline.Visible=true
else ESP_Boxes[plr].box.Visible=false;ESP_Boxes[plr].boxoutline.Visible=false end
else ESP_Boxes[plr].box.Visible=false;ESP_Boxes[plr].boxoutline.Visible=false end
elseif ESP_Boxes[plr] then ESP_Boxes[plr].box.Visible=false;ESP_Boxes[plr].boxoutline.Visible=false end
end

local function initPlayer(plr) if plr==lp then return end;plr.CharacterAdded:Connect(function() cleanupPlayerESP(plr) end) end
for _,plr in pairs(Players:GetPlayers()) do if plr~=lp then initPlayer(plr) end end
Players.PlayerAdded:Connect(function(plr) if plr~=lp then initPlayer(plr) end end)
Players.PlayerRemoving:Connect(function(plr) cleanupPlayerESP(plr) end)
local function mk(class,props,parent) local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;if parent then o.Parent=parent end;return o end
local function gradient(parent,rotation,seq) local g=Instance.new("UIGradient");g.Rotation=rotation or 0;g.Color=seq;g.Parent=parent;return g end
local function addDotPattern(parent,colorA,colorB,tile)
mk("ImageLabel",{Name="DotPattern",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),BorderSizePixel=0,ZIndex=parent.ZIndex,Image="rbxassetid://9968344105",ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(tile or 6,tile or 6),ImageColor3=colorB or Color3.fromRGB(20,20,20)},parent)
mk("Frame",{Name="DotBase",BackgroundColor3=colorA or Color3.fromRGB(12,12,12),BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=math.max((parent.ZIndex or 1)-1,0)},parent)
end

local sliderDragging=false
local colorPickerDragging=false
local allColorPickers={}

local main=mk("Frame",{Name="Main",Size=UDim2.fromOffset(658,558),Position=UDim2.new(0.5,-329,0.5,-279),BackgroundColor3=C.outer,BorderSizePixel=0,ClipsDescendants=false},gui)
local border1=mk("Frame",{Size=UDim2.new(1,-2,1,-2),Position=UDim2.fromOffset(1,1),BackgroundColor3=C.inner,BorderSizePixel=0},main)
local border2=mk("Frame",{Size=UDim2.new(1,-2,1,-2),Position=UDim2.fromOffset(1,1),BackgroundColor3=C.bg0,BorderSizePixel=0},border1)
local body=mk("Frame",{Size=UDim2.new(1,-4,1,-4),Position=UDim2.fromOffset(2,2),BackgroundColor3=C.dotA,BorderSizePixel=0,ClipsDescendants=true},border2)
addDotPattern(body,C.dotA,C.dotB,6)
mk("Frame",{Size=UDim2.new(1,0,0,3),Position=UDim2.fromOffset(0,0),BackgroundColor3=C.topMini,BorderSizePixel=0,ZIndex=50},body)

local contentHeight=530;local contentYStart=20
local side=mk("Frame",{Size=UDim2.fromOffset(75,contentHeight+contentYStart),Position=UDim2.fromOffset(0,0),BackgroundColor3=C.side,BorderSizePixel=0,ClipsDescendants=true,ZIndex=2},body)
mk("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,-1,0,0),BackgroundColor3=C.divider,BorderSizePixel=0,ZIndex=3},side)
local content=mk("Frame",{Size=UDim2.fromOffset(570,contentHeight),Position=UDim2.fromOffset(82,contentYStart),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,ZIndex=2},body)
local pageHolder=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2},content)
local iconHolder=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,ZIndex=20},side)
local dragZone=mk("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,ZIndex=200},body)

local topPadding=25;local bottomPadding=30;local iconSize=36;local buttonWidth=50
local countIcons=#ICONS
local gapIcons=math.max((contentHeight-topPadding-bottomPadding-countIcons*iconSize)/(countIcons-1),2)

local tabButtons={};local pages={};local activeContextMenu=nil;local activeContextConn=nil

local function closeActiveContext()
if activeContextMenu then activeContextMenu:Destroy();activeContextMenu=nil end
if activeContextConn then activeContextConn:Disconnect();activeContextConn=nil end
end

local TEXT_OFFSET=22

local function openContextMenu(anchorFrame,modes,getCurrentMode,onSelect)
closeActiveContext()
local ctxH=#modes*22+8;local ctxW=95
local anchorAbs=anchorFrame.AbsolutePosition;local mainAbs=main.AbsolutePosition
local ctx=mk("Frame",{Size=UDim2.fromOffset(ctxW,ctxH),Position=UDim2.fromOffset(anchorAbs.X-mainAbs.X-ctxW-5,anchorAbs.Y-mainAbs.Y),BackgroundColor3=C.contextBg,BorderSizePixel=0,ZIndex=500},main)
mk("UIStroke",{Color=C.contextBorder,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},ctx)
activeContextMenu=ctx
local currentMode=getCurrentMode and getCurrentMode() or "On hotkey"
for i,mode in ipairs(modes) do
local sel=(mode==currentMode)
local itemBtn=mk("TextButton",{Size=UDim2.new(1,-4,0,20),Position=UDim2.fromOffset(2,4+(i-1)*22),BackgroundTransparency=1,BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=501},ctx)
mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.fromOffset(6,0),BackgroundTransparency=1,Text=mode,Font=MENU_FONT,TextSize=12,TextColor3=sel and C.contextSelected or C.contextUnselected,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=502},itemBtn)
itemBtn.MouseEnter:Connect(function() itemBtn.BackgroundTransparency=0;itemBtn.BackgroundColor3=C.contextHover end)
itemBtn.MouseLeave:Connect(function() itemBtn.BackgroundTransparency=1 end)
itemBtn.MouseButton1Down:Connect(function() if onSelect then onSelect(mode) end;task.defer(function() closeActiveContext() end) end)
end
task.delay(0.15,function()
if activeContextMenu~=ctx then return end
activeContextConn=UIS.InputBegan:Connect(function(input)
if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.MouseButton2 then return end
task.delay(0.05,function()
if not activeContextMenu or activeContextMenu~=ctx then if activeContextConn then activeContextConn:Disconnect();activeContextConn=nil end;return end
local mp=UIS:GetMouseLocation();local cp=ctx.AbsolutePosition;local cs=ctx.AbsoluteSize
if mp.X<cp.X or mp.X>cp.X+cs.X or mp.Y<cp.Y or mp.Y>cp.Y+cs.Y then closeActiveContext() end
end)
end)
end)
end

local function createCheckboxWithBind(parent,yPos,labelText,defaultValue,bindText,onToggle,onBindClick,onContextSelect,getCurrentMode)
local container=mk("Frame",{Size=UDim2.new(1,-16,0,18),Position=UDim2.fromOffset(8,yPos),BackgroundTransparency=1,ZIndex=5},parent)
local checkBox=mk("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.fromOffset(0,5),BackgroundColor3=defaultValue and C.checkOn or C.checkOff,BorderSizePixel=0,ZIndex=6},container)
mk("UIStroke",{Color=Color3.fromRGB(3,3,3),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},checkBox)
mk("TextLabel",{Size=UDim2.new(1,-55,1,0),Position=UDim2.fromOffset(TEXT_OFFSET,0),BackgroundTransparency=1,Text=labelText,Font=MENU_FONT,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ClipsDescendants=false,ZIndex=6},container)
local bindLabel=mk("TextLabel",{Size=UDim2.fromOffset(40,14),Position=UDim2.new(1,-40,0,2),BackgroundTransparency=1,Text=bindText or "[-]",Font=MENU_FONT,TextSize=11,TextColor3=C.bindText,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=7},container)
local bindClickArea=mk("TextButton",{Size=UDim2.fromOffset(40,18),Position=UDim2.new(1,-40,0,0),BackgroundTransparency=1,Text="",ZIndex=9},container)
local clickArea=mk("TextButton",{Size=UDim2.new(1,-45,1,0),Position=UDim2.fromOffset(0,0),BackgroundTransparency=1,Text="",ZIndex=8},container)
local enabled=defaultValue
clickArea.MouseButton1Click:Connect(function() enabled=not enabled;checkBox.BackgroundColor3=enabled and C.checkOn or C.checkOff;if onToggle then onToggle(enabled) end end)
bindClickArea.MouseButton1Click:Connect(function() if onBindClick then onBindClick(bindLabel) end end)
if onContextSelect and getCurrentMode then bindClickArea.MouseButton2Click:Connect(function() openContextMenu(bindLabel,{"Always on","On hotkey","Toggle","Off hotkey"},getCurrentMode,function(mode) if onContextSelect then onContextSelect(mode) end end) end) end
return{setEnabled=function(v) enabled=v;checkBox.BackgroundColor3=enabled and C.checkOn or C.checkOff end,getEnabled=function() return enabled end,setBindText=function(t) bindLabel.Text=t end}
end

local function createCheckbox(parent,yPos,labelText,defaultValue,onToggle)
local container=mk("Frame",{Size=UDim2.new(1,-16,0,18),Position=UDim2.fromOffset(8,yPos),BackgroundTransparency=1,ZIndex=5},parent)
local checkBox=mk("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.fromOffset(0,5),BackgroundColor3=defaultValue and C.checkOn or C.checkOff,BorderSizePixel=0,ZIndex=6},container)
mk("UIStroke",{Color=Color3.fromRGB(3,3,3),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},checkBox)
mk("TextLabel",{Size=UDim2.new(1,-30,1,0),Position=UDim2.fromOffset(TEXT_OFFSET,0),BackgroundTransparency=1,Text=labelText,Font=MENU_FONT,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ClipsDescendants=false,ZIndex=6},container)
local clickArea=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=8},container)
local enabled=defaultValue
clickArea.MouseButton1Click:Connect(function() enabled=not enabled;checkBox.BackgroundColor3=enabled and C.checkOn or C.checkOff;if onToggle then onToggle(enabled) end end)
return{setEnabled=function(v) enabled=v;checkBox.BackgroundColor3=enabled and C.checkOn or C.checkOff end,getEnabled=function() return enabled end}
end

local function createCheckboxWithColor(parent,yPos,labelText,defaultValue,defaultColor,onToggle,onColorChanged)
local container=mk("Frame",{Size=UDim2.new(1,-16,0,18),Position=UDim2.fromOffset(8,yPos),BackgroundTransparency=1,ZIndex=5},parent)
local checkBox=mk("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.fromOffset(0,5),BackgroundColor3=defaultValue and C.checkOn or C.checkOff,BorderSizePixel=0,ZIndex=6},container)
mk("UIStroke",{Color=Color3.fromRGB(3,3,3),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},checkBox)
mk("TextLabel",{Size=UDim2.new(1,-40,1,0),Position=UDim2.fromOffset(TEXT_OFFSET,0),BackgroundTransparency=1,Text=labelText,Font=MENU_FONT,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ClipsDescendants=false,ZIndex=6},container)
local preview=mk("Frame",{Size=UDim2.fromOffset(16,10),Position=UDim2.new(1,-16,0,4),BackgroundColor3=defaultColor,BorderSizePixel=0,ZIndex=7},container)
mk("UIStroke",{Color=C.pickerBorder,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},preview)
local previewBtn=mk("TextButton",{Size=UDim2.fromOffset(16,14),Position=UDim2.new(1,-16,0,2),BackgroundTransparency=1,Text="",ZIndex=10},container)
local clickArea=mk("TextButton",{Size=UDim2.new(1,-22,1,0),BackgroundTransparency=1,Text="",ZIndex=8},container)
local enabled=defaultValue
local currentH,currentS,currentV=Color3.toHSV(defaultColor);local currentColor=defaultColor
local pickerOpen=false;local pickerFrame=nil;local pickerConns={}
clickArea.MouseButton1Click:Connect(function() enabled=not enabled;checkBox.BackgroundColor3=enabled and C.checkOn or C.checkOff;if onToggle then onToggle(enabled) end end)
local function applyColor() currentColor=Color3.fromHSV(currentH,currentS,currentV);preview.BackgroundColor3=currentColor;if onColorChanged then onColorChanged(currentColor) end end
local function closePicker() if pickerFrame then for _,c in ipairs(pickerConns) do c:Disconnect() end;pickerConns={};pickerFrame:Destroy();pickerFrame=nil;pickerOpen=false;for i,p in ipairs(allColorPickers) do if p==closePicker then table.remove(allColorPickers,i);break end end end end
previewBtn.MouseButton1Click:Connect(function()
if pickerOpen then closePicker();return end;for _,closeFunc in ipairs(allColorPickers) do closeFunc() end;pickerOpen=true;table.insert(allColorPickers,closePicker)
local PS=120;local HW=14;local anchorAbs=preview.AbsolutePosition;local mainAbs=main.AbsolutePosition
pickerFrame=mk("Frame",{Size=UDim2.fromOffset(PS+HW+12,PS+8),Position=UDim2.fromOffset(anchorAbs.X-mainAbs.X-PS-HW-16,anchorAbs.Y-mainAbs.Y-4),BackgroundColor3=C.contextBg,BorderSizePixel=0,ZIndex=600},main)
mk("UIStroke",{Color=C.contextBorder,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},pickerFrame)
local svField=mk("ImageLabel",{Size=UDim2.fromOffset(PS,PS),Position=UDim2.fromOffset(4,4),BackgroundColor3=Color3.fromHSV(currentH,1,1),BorderSizePixel=0,ZIndex=601,Image=""},pickerFrame)
mk("UIStroke",{Color=C.pickerBorder,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},svField)
local wg=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=602},svField)
local wgg=gradient(wg,0,ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}))
wgg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
local bg=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=603},svField)
local bgg=gradient(bg,90,ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}))
bgg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
local svCursor=mk("Frame",{Size=UDim2.fromOffset(6,6),Position=UDim2.new(currentS,-3,1-currentV,-3),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=605},svField)
mk("UICorner",{CornerRadius=UDim.new(0,3)},svCursor);mk("UIStroke",{Color=Color3.new(0,0,0),Thickness=1},svCursor)
local hueBar=mk("Frame",{Size=UDim2.fromOffset(HW,PS),Position=UDim2.fromOffset(PS+8,4),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=601},pickerFrame)
mk("UIStroke",{Color=C.pickerBorder,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},hueBar)
gradient(hueBar,90,ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.167,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.333,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.667,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.833,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))}))
local hueCursor=mk("Frame",{Size=UDim2.new(1,2,0,3),Position=UDim2.new(0,-1,currentH,-1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=605},hueBar)
mk("UIStroke",{Color=Color3.new(0,0,0),Thickness=1},hueCursor)
local svDrag,hueDrag=false,false
local svBtn=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=610},svField)
local hueBtn=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=610},hueBar)
local function updSV(pos) local ap,sz=svField.AbsolutePosition,svField.AbsoluteSize;currentS=math.clamp((pos.X-ap.X)/sz.X,0,1);currentV=math.clamp(1-(pos.Y-ap.Y)/sz.Y,0,1);svCursor.Position=UDim2.new(currentS,-3,1-currentV,-3);applyColor() end
local function updHue(pos) local ap,sz=hueBar.AbsolutePosition,hueBar.AbsoluteSize;currentH=math.clamp((pos.Y-ap.Y)/sz.Y,0,0.999);hueCursor.Position=UDim2.new(0,-1,currentH,-1);svField.BackgroundColor3=Color3.fromHSV(currentH,1,1);applyColor() end
svBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then svDrag=true;colorPickerDragging=true;sliderDragging=true;updSV(i.Position) end end)
svBtn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then svDrag=false;colorPickerDragging=false;sliderDragging=false end end)
hueBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=true;colorPickerDragging=true;sliderDragging=true;updHue(i.Position) end end)
hueBtn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=false;colorPickerDragging=false;sliderDragging=false end end)
table.insert(pickerConns,UIS.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then if svDrag then updSV(i.Position) end;if hueDrag then updHue(i.Position) end end end))
table.insert(pickerConns,UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then svDrag=false;hueDrag=false;colorPickerDragging=false;sliderDragging=false end end))
end)
return{setEnabled=function(v) enabled=v;checkBox.BackgroundColor3=enabled and C.checkOn or C.checkOff end,getEnabled=function() return enabled end,closePicker=closePicker}
end

local function createSlider(parent,yPos,labelText,minVal,maxVal,defaultVal,suffix,onChanged)
local container=mk("Frame",{Size=UDim2.new(1,-16,0,22),Position=UDim2.fromOffset(8,yPos),BackgroundTransparency=1,ZIndex=5},parent)
mk("TextLabel",{Size=UDim2.new(0.5,0,0,22),BackgroundTransparency=1,Text=labelText,Font=MENU_FONT,TextSize=13,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,ClipsDescendants=false,ZIndex=6},container)
local sliderTrack=mk("Frame",{Size=UDim2.new(0.47,0,0,12),Position=UDim2.new(0.53,0,0,5),BackgroundColor3=C.sliderBg,BorderSizePixel=0,ZIndex=6,ClipsDescendants=false},container)
mk("UIStroke",{Color=Color3.fromRGB(3,3,3),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},sliderTrack)
local fp=(defaultVal-minVal)/(maxVal-minVal)
local sliderFill=mk("Frame",{Size=UDim2.new(fp,0,1,0),BackgroundColor3=C.sliderFill,BorderSizePixel=0,ZIndex=7,ClipsDescendants=false},sliderTrack)
gradient(sliderFill,0,ColorSequence.new({ColorSequenceKeypoint.new(0,C.sliderFill),ColorSequenceKeypoint.new(1,C.sliderFill2)}))
local valueLabel=mk("TextLabel",{Size=UDim2.new(1,0,1,0),Position=UDim2.fromOffset(0,0),BackgroundTransparency=1,Text=tostring(defaultVal)..(suffix or ""),Font=MENU_FONT,TextSize=11,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=10},sliderTrack)
local currentValue=defaultVal;local dragging=false
local function upd(inputX)
local tp,ts=sliderTrack.AbsolutePosition.X,sliderTrack.AbsoluteSize.X
if ts==0 then return end
local p=math.clamp((inputX-tp)/ts,0,1)
local v=math.floor(minVal+(maxVal-minVal)*p)
currentValue=v
sliderFill.Size=UDim2.new(p,0,1,0)
valueLabel.Text=tostring(v)..(suffix or "")
if onChanged then onChanged(v) end
end
local sb=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=9},sliderTrack)
sb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;sliderDragging=true;upd(i.Position.X) end end)
sb.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false;sliderDragging=false end end)
UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 and dragging then dragging=false;sliderDragging=false end end)
return{getValue=function() return currentValue end}
end

local function addFilledTriangle(parent, baseZIndex)
	local z = (baseZIndex or 2) + 10
	local triSize = 7
	local clipper = mk("Frame", {
		Size = UDim2.fromOffset(triSize, triSize),
		Position = UDim2.new(1, -triSize - 1, 1, -triSize - 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = z,
		ClipsDescendants = true,
	}, parent)
	mk("Frame", {
		Size = UDim2.fromOffset(triSize * 1.5, triSize * 1.5),
		Position = UDim2.fromOffset(triSize * 0.25, triSize * 0.25),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = C.triangleColor,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = z + 1,
	}, clipper)
end

local function createGroup(parent, x, y, w, h, titleText, addTriangle)
	local wrapper = mk("Frame", {
		Size = UDim2.fromOffset(w, h + 8),
		Position = UDim2.fromOffset(x, y - 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = false,
	}, parent)

	local g0 = mk("Frame", {
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = C.groupBg,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = false,
	}, wrapper)

	mk("Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.fromOffset(0,0), BackgroundColor3=C.groupLine, BorderSizePixel=0, ZIndex=3}, g0)
	mk("Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BackgroundColor3=C.groupLine, BorderSizePixel=0, ZIndex=3}, g0)
	mk("Frame", {Size=UDim2.new(0,1,1,0), Position=UDim2.fromOffset(0,0), BackgroundColor3=C.groupLine, BorderSizePixel=0, ZIndex=3}, g0)
	mk("Frame", {Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,-1,0,0), BackgroundColor3=C.groupLine, BorderSizePixel=0, ZIndex=3}, g0)

	local tb = mk("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		Position = UDim2.fromOffset(8, -7),
		BackgroundColor3 = C.groupBg,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, g0)
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
	}, tb)

	if addTriangle then
		addFilledTriangle(g0, 2)
	end

	return g0
end

local LEFT_PAD = 20

local function buildRagebotPage(parent)
local totalH=contentHeight-15;local wgH=40
createGroup(parent,6,5,274,wgH,"Weapon type")
local aimbotGroup=createGroup(parent,6,5+wgH+10,274,totalH-wgH-10,"Aimbot")
createCheckboxWithBind(aimbotGroup,12,"Enabled",false,"[-]",
function(val) aimbotEnabled=val;if not val then currentTarget=nil;targetLocked=false end end,
function(bindLabel) if isRecordingKeybind then return end;isRecordingKeybind=true;bindLabel.Text="[-]";bindLabel.TextColor3=C.bindRecording;local conn;conn=UIS.InputBegan:Connect(function(input) if not isRecordingKeybind then return end;if input.UserInputType~=Enum.UserInputType.Keyboard then return end;if input.KeyCode==Enum.KeyCode.Escape then isRecordingKeybind=false;conn:Disconnect();aimlockKey=nil;aimlockKeyName="Not Set";bindLabel.Text="[-]";bindLabel.TextColor3=C.bindText;return end;if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift or input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl or input.KeyCode==Enum.KeyCode.LeftAlt or input.KeyCode==Enum.KeyCode.RightAlt then return end;isRecordingKeybind=false;conn:Disconnect();aimlockKey=input.KeyCode;aimlockKeyName=input.KeyCode.Name;bindLabel.Text="["..aimlockKeyName.."]";bindLabel.TextColor3=C.bindText end);task.delay(5,function() if isRecordingKeybind then isRecordingKeybind=false;if conn then conn:Disconnect() end;bindLabel.Text=aimlockKey and("["..aimlockKeyName.."]") or "[-]";bindLabel.TextColor3=C.bindText end end) end,
function(mode) aimlockMode=mode end,function() return aimlockMode end)
local otherGroup=createGroup(parent,290,5,274,totalH,"Other")
local y=12
createCheckbox(otherGroup,y,"Automatic fire",false,function(v) autofireEnabled=v end);y=y+22
createCheckbox(otherGroup,y,"Silent aim",false,function(v) silentAimEnabled=v;if not v then silentAimTarget=nil end end);y=y+22
createCheckbox(otherGroup,y,"Remove recoil",false,function(v) if v then activateNoVisualRecoil() else deactivateNoVisualRecoil() end end);y=y+22
createCheckbox(otherGroup,y,"Wallcheck",true,function(v) wallCheckEnabled=v end);y=y+22
createSlider(otherGroup,y,"Maximum FOV",0,180,180,"°",function(v) fovDegrees=v end);y=y+28
createCheckboxWithColor(otherGroup,y,"Show FOV",false,Color3.new(1,1,1),function(v) showFOV=v end,function(c) fovColor=c;fovCircle.Color=c end)
end

local function buildAntiAimPage(parent)
	local leftW = 250
	local gap = 25
	local rightX = LEFT_PAD + leftW + gap
	local rightW = 250
	local leftH = 500
	local fakelagH = 230
	local otherY = 20 + fakelagH + 20
	local bottomY = 20 + leftH

	createGroup(parent, LEFT_PAD, 20, leftW, leftH, "Anti-aimbot angles", true)
	createGroup(parent, rightX, 20, rightW, fakelagH, "Fake lag", true)
	createGroup(parent, rightX, otherY, rightW, bottomY - otherY, "Other", true)
end

local function buildESPSettingsPage(parent)
	local topPad = 25
	local gapHoriz = 20
	local gapVert = 20
	local wtW = 250
	local wtH = 60
	local wtX = LEFT_PAD
	local wtY = topPad
	createGroup(parent, wtX, wtY, wtW, wtH, "Weapon type", true)
	local aimbotW = 250
	local aimbotH = 420
	local aimbotX = LEFT_PAD
	local aimbotY = wtY + wtH + gapVert
	createGroup(parent, aimbotX, aimbotY, aimbotW, aimbotH, "Aimbot", true)
	local rightX = LEFT_PAD + 250 + gapHoriz
	local trigY = topPad
	local otherH = 130
	local aimbotBottom = aimbotY + aimbotH
	local otherY = aimbotBottom - otherH
	local trigH = otherY - trigY - gapVert
	createGroup(parent, rightX, trigY, 250, trigH, "Triggerbot", true)
	createGroup(parent, rightX, otherY, 250, otherH, "Other", true)
end

local function buildPlayerESPPage(parent)
local leftX=LEFT_PAD;local rightX=LEFT_PAD+250+24
local playerGroup=createGroup(parent,leftX,5,250,270,"Player ESP")
local otherGroup=createGroup(parent,rightX,5,250,250,"Other ESP")
local coloredGroup=createGroup(parent,leftX,295,250,220,"Colored models")
local effectsGroup=createGroup(parent,rightX,280,250,235,"Effects")
local y=12
createCheckboxWithBind(playerGroup,y,"Activation type",false,"[-]",
function(val) espVisualEnabled=val;if not val then for plr,_ in pairs(ESP_HPText) do hidePlayerESP(plr) end end end,
function(bindLabel) if isRecordingESPKeybind then return end;isRecordingESPKeybind=true;bindLabel.Text="[-]";bindLabel.TextColor3=C.bindRecording;local conn;conn=UIS.InputBegan:Connect(function(input) if not isRecordingESPKeybind then return end;if input.UserInputType~=Enum.UserInputType.Keyboard then return end;if input.KeyCode==Enum.KeyCode.Escape then isRecordingESPKeybind=false;conn:Disconnect();espVisualKey=nil;espVisualKeyName="Not Set";bindLabel.Text="[-]";bindLabel.TextColor3=C.bindText;return end;if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift or input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl or input.KeyCode==Enum.KeyCode.LeftAlt or input.KeyCode==Enum.KeyCode.RightAlt then return end;isRecordingESPKeybind=false;conn:Disconnect();espVisualKey=input.KeyCode;espVisualKeyName=input.KeyCode.Name;bindLabel.Text="["..espVisualKeyName.."]";bindLabel.TextColor3=C.bindText end);task.delay(5,function() if isRecordingESPKeybind then isRecordingESPKeybind=false;if conn then conn:Disconnect() end;bindLabel.Text=espVisualKey and("["..espVisualKeyName.."]") or "[-]";bindLabel.TextColor3=C.bindText end end) end,
function(mode) espVisualMode=mode end,function() return espVisualMode end)
y=y+22
createCheckboxWithColor(playerGroup,y,"Bounding box",false,Color3.fromRGB(255,0,0),function(v) Box_ESP_Enabled=v end,function(c) Settings.Box_Color=c end);y=y+22
createCheckboxWithColor(playerGroup,y,"Health bar",false,Color3.fromRGB(255,0,0),function(v) ESP_HPEnabled=v end,function(c) Settings.HP_Color=c end);y=y+22
createCheckboxWithColor(playerGroup,y,"Name",false,Color3.fromRGB(255,0,0),function(v) ESP_NameEnabled=v end,function(c) Settings.Name_Color=c end);y=y+22
createCheckboxWithColor(playerGroup,y,"Weapon text",false,Color3.fromRGB(255,0,0),function(v) ESP_WeaponEnabled=v end,function(c) Settings.Weapon_Color=c end);y=y+22
createCheckbox(playerGroup,y,"Dynamic HP color",false,function(v) ESP_HPDynamicEnabled=v end);y=y+28
createSlider(playerGroup,y,"Max distance",1,1500,1500," studs",function(v) ESP_MaxDistance=v end)
createCheckbox(effectsGroup,12,"NoFall protection",false,function(v) if v then startNoFall() else stopNoFall() end end)
end

local function buildMiscPage(parent)
local miscGroup = createGroup(parent, LEFT_PAD, 5, 250, 510, "Miscellaneous", true)
local movGroup = createGroup(parent, LEFT_PAD + 250 + 11, 5, 250, 245, "Movement", true)
local setGroup = createGroup(parent, LEFT_PAD + 250 + 11, 270, 250, 245, "Settings", true)
local my = 12
createCheckbox(movGroup, my, "NoFall protection", false, function(v)
	if v then startNoFall() else stopNoFall() end
end)
end

local function buildSkinsPage(parent)
	createGroup(parent, LEFT_PAD, 20, 250, 500, "Model options")
	createGroup(parent, LEFT_PAD + 250 + 20, 20, 250, 500, "Weapon skin")
end

local function buildPlayersPage(parent)
local playersGroup=createGroup(parent,6,5,250,510,"Players", true)
local adjustGroup=createGroup(parent,266,5,298,510,"Adjustments", true)
local listFrame=mk("Frame",{Size=UDim2.new(1,-16,1,-52),Position=UDim2.fromOffset(8,12),BackgroundColor3=Color3.fromRGB(15,15,15),BorderSizePixel=0,ZIndex=4,ClipsDescendants=true},playersGroup)
mk("UIStroke",{Color=Color3.fromRGB(3,3,3),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},listFrame)
local scrollFrame=mk("ScrollingFrame",{Size=UDim2.new(1,0,1,0),Position=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(80,80,80),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=5},listFrame)
mk("UIListLayout",{SortOrder=Enum.SortOrder.Name,Padding=UDim.new(0,1)},scrollFrame)
local searchBox=mk("TextBox",{Size=UDim2.new(1,-16,0,22),Position=UDim2.new(0,8,1,-32),BackgroundColor3=Color3.fromRGB(15,15,15),BorderSizePixel=0,Text="",PlaceholderText="Search player...",Font=MENU_FONT,TextSize=12,TextColor3=C.text,PlaceholderColor3=C.textDim,ClearTextOnFocus=false,ZIndex=5},playersGroup)
mk("UIStroke",{Color=Color3.fromRGB(3,3,3),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},searchBox)
local rightContent=mk("Frame",{Size=UDim2.new(1,-16,1,-20),Position=UDim2.fromOffset(8,12),BackgroundTransparency=1,ZIndex=4},adjustGroup)
local selectedLabel=mk("TextLabel",{Size=UDim2.new(1,0,0,18),Position=UDim2.fromOffset(0,0),BackgroundTransparency=1,Text="No player selected",Font=MENU_FONT,TextSize=13,TextColor3=C.textDim,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5},rightContent)
local adjustY=24
local whitelistCB=createCheckbox(rightContent,adjustY,"Add to whitelist",false,function(v) if playerPageData.selectedPlayer then local ps=getPlayerSettings(playerPageData.selectedPlayer);ps.whitelisted=v;if v then local found=false;for _,n in pairs(FriendList) do if n==playerPageData.selectedPlayer then found=true;break end end;if not found then table.insert(FriendList,playerPageData.selectedPlayer) end else for i,n in pairs(FriendList) do if n==playerPageData.selectedPlayer then table.remove(FriendList,i);break end end end end end);adjustY=adjustY+22
local teamColorCB=createCheckbox(rightContent,adjustY,"Team color",false,function(v) if playerPageData.selectedPlayer then local ps=getPlayerSettings(playerPageData.selectedPlayer);ps.teamColor=v end end);adjustY=adjustY+22
local disableVisCB=createCheckbox(rightContent,adjustY,"Disable visuals",false,function(v) if playerPageData.selectedPlayer then local ps=getPlayerSettings(playerPageData.selectedPlayer);ps.disableVisuals=v;if v then local plr=Players:FindFirstChild(playerPageData.selectedPlayer);if plr then hidePlayerESP(plr) end end end end);adjustY=adjustY+28
createCheckboxWithColor(rightContent,adjustY,"Box color",false,Color3.fromRGB(255,0,0),nil,function(c) if playerPageData.selectedPlayer then getPlayerSettings(playerPageData.selectedPlayer).boxColor=c end end);adjustY=adjustY+22
createCheckboxWithColor(rightContent,adjustY,"HP color",false,Color3.fromRGB(255,0,0),nil,function(c) if playerPageData.selectedPlayer then getPlayerSettings(playerPageData.selectedPlayer).hpColor=c end end);adjustY=adjustY+22
createCheckboxWithColor(rightContent,adjustY,"Name color",false,Color3.fromRGB(255,0,0),nil,function(c) if playerPageData.selectedPlayer then getPlayerSettings(playerPageData.selectedPlayer).nameColor=c end end);adjustY=adjustY+22
createCheckboxWithColor(rightContent,adjustY,"Weapon color",false,Color3.fromRGB(255,0,0),nil,function(c) if playerPageData.selectedPlayer then getPlayerSettings(playerPageData.selectedPlayer).weaponColor=c end end)
local function refreshPlayerList()
for _,child in pairs(scrollFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end;playerPageData.buttons={}
local search=searchBox.Text:lower();local plist=Players:GetPlayers();table.sort(plist,function(a,b) return a.Name:lower()<b.Name:lower() end)
for _,plr in pairs(plist) do if plr~=lp then if search=="" or plr.Name:lower():find(search,1,true) then
local isSelected=(playerPageData.selectedPlayer==plr.Name)
local btn=mk("TextButton",{Size=UDim2.new(1,-2,0,20),BackgroundColor3=isSelected and Color3.fromRGB(35,35,35) or Color3.fromRGB(18,18,18),BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=6,Name=plr.Name},scrollFrame)
local ps=getPlayerSettings(plr.Name);local nameCol=ps.whitelisted and Settings.Friend_Color or C.text
mk("TextLabel",{Size=UDim2.new(1,-8,1,0),Position=UDim2.fromOffset(6,0),BackgroundTransparency=1,Text=plr.Name,Font=MENU_FONT,TextSize=12,TextColor3=nameCol,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7},btn)
btn.MouseEnter:Connect(function() if playerPageData.selectedPlayer~=plr.Name then btn.BackgroundColor3=Color3.fromRGB(28,28,28) end end)
btn.MouseLeave:Connect(function() if playerPageData.selectedPlayer~=plr.Name then btn.BackgroundColor3=Color3.fromRGB(18,18,18) end end)
btn.MouseButton1Click:Connect(function() playerPageData.selectedPlayer=plr.Name;selectedLabel.Text=plr.Name;selectedLabel.TextColor3=C.text;local s=getPlayerSettings(plr.Name);whitelistCB.setEnabled(s.whitelisted);teamColorCB.setEnabled(s.teamColor or false);disableVisCB.setEnabled(s.disableVisuals);for _,b in pairs(playerPageData.buttons) do b.BackgroundColor3=(b.Name==plr.Name) and Color3.fromRGB(35,35,35) or Color3.fromRGB(18,18,18) end end)
playerPageData.buttons[#playerPageData.buttons+1]=btn
end end end end
refreshPlayerList();searchBox:GetPropertyChangedSignal("Text"):Connect(function() refreshPlayerList() end)
Players.PlayerAdded:Connect(function() task.wait(0.5);refreshPlayerList() end)
Players.PlayerRemoving:Connect(function(plr) if playerPageData.selectedPlayer==plr.Name then playerPageData.selectedPlayer=nil;selectedLabel.Text="No player selected";selectedLabel.TextColor3=C.textDim end;task.wait(0.1);refreshPlayerList() end)
end

local function buildConfigPage(parent)
	createGroup(parent, LEFT_PAD, 20, 250, 500, "Presets", true)
	createGroup(parent, LEFT_PAD + 250 + 20, 20, 250, 500, "Lua", true)
end

local function createTab(index,imageId)
local y=math.floor(topPadding+(index-1)*(iconSize+gapIcons))
local holder=mk("TextButton",{Size=UDim2.fromOffset(buttonWidth,iconSize),Position=UDim2.fromOffset(12,y),BackgroundTransparency=1,BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=21},iconHolder)
local icon=mk("ImageLabel",{Size=UDim2.fromOffset(120,120),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundTransparency=1,Image=imageId,ScaleType=Enum.ScaleType.Fit,ZIndex=22},holder)
local page=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=2},pageHolder)
if index==1 then buildRagebotPage(page)
elseif index==2 then buildAntiAimPage(page)
elseif index==3 then buildESPSettingsPage(page)
elseif index==4 then buildPlayerESPPage(page)
elseif index==5 then buildMiscPage(page)
elseif index==6 then buildSkinsPage(page)
elseif index==7 then buildPlayersPage(page)
elseif index==8 then buildConfigPage(page)
end
tabButtons[index]={button=holder,icon=icon};pages[index]=page
holder.MouseButton1Click:Connect(function() closeActiveContext();for _,closeFunc in ipairs(allColorPickers) do closeFunc() end;for i=1,#tabButtons do tabButtons[i].icon.ImageColor3=(i==index) and C.iconOn or Color3.new(1,1,1);pages[i].Visible=(i==index) end end)
end

for i,id in ipairs(ICONS) do createTab(i,id) end
for i=1,#tabButtons do tabButtons[i].icon.ImageColor3=(i==1) and C.iconOn or Color3.new(1,1,1);pages[i].Visible=(i==1) end

local topLine=mk("Frame",{Size=UDim2.new(1,-2,0,2),Position=UDim2.fromOffset(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=100},body)
gradient(topLine,0,ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(55,170,255)),ColorSequenceKeypoint.new(0.18,Color3.fromRGB(80,120,255)),ColorSequenceKeypoint.new(0.35,Color3.fromRGB(150,85,255)),ColorSequenceKeypoint.new(0.53,Color3.fromRGB(255,90,210)),ColorSequenceKeypoint.new(0.76,Color3.fromRGB(255,155,70)),ColorSequenceKeypoint.new(1,Color3.fromRGB(170,255,0))}))

do local dragging=false;local dragStart,startPos
dragZone.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 and not sliderDragging and not colorPickerDragging then dragging=true;dragStart=input.Position;startPos=main.Position end end)
dragZone.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
UIS.InputChanged:Connect(function(input) if dragging and not sliderDragging and not colorPickerDragging and input.UserInputType==Enum.UserInputType.MouseMovement then local delta=input.Position-dragStart;main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y) end end)
end

UIS.InputBegan:Connect(function(input,gp)
if gp then return end
if input.KeyCode==Enum.KeyCode.K then gui.Enabled=not gui.Enabled;return end
if isRecordingKeybind or isRecordingESPKeybind then return end
if espVisualKey and input.KeyCode==espVisualKey then
if espVisualMode=="Toggle" then espVisualToggled=not espVisualToggled;if not isESPActive() then for plr,_ in pairs(ESP_HPText) do hidePlayerESP(plr) end end
elseif espVisualMode=="On hotkey" then espVisualKeyHeld=true
elseif espVisualMode=="Off hotkey" then espVisualKeyHeld=true;if not isESPActive() then for plr,_ in pairs(ESP_HPText) do hidePlayerESP(plr) end end end end
if aimlockKey and input.KeyCode==aimlockKey then aimlockKeyHeld=true;if aimlockMode=="Toggle" then keyHeld=not keyHeld elseif aimlockMode=="On hotkey" then keyHeld=true;currentTarget=nil;targetLocked=false elseif aimlockMode=="Off hotkey" then keyHeld=false end end
end)

UIS.InputEnded:Connect(function(input)
if espVisualKey and input.KeyCode==espVisualKey then
if espVisualMode=="On hotkey" then espVisualKeyHeld=false;if not isESPActive() then for plr,_ in pairs(ESP_HPText) do hidePlayerESP(plr) end end
elseif espVisualMode=="Off hotkey" then espVisualKeyHeld=false end end
if aimlockKey and input.KeyCode==aimlockKey then aimlockKeyHeld=false;if aimlockMode=="On hotkey" then keyHeld=false;currentTarget=nil;targetLocked=false elseif aimlockMode=="Off hotkey" then keyHeld=true end end
end)

local currentTool;local lastSilentShot=0;local SILENT_FIRE_RATE=0.08
RunService.RenderStepped:Connect(function()
updateFrameCache();local aimActive=isAimbotActive()
if silentAimEnabled and aimActive then updateSilentAimTarget();if silentAimTarget then local tool=lp.Character and lp.Character:FindFirstChildOfClass("Tool");if tool and(tick()-lastSilentShot>=SILENT_FIRE_RATE) then lastSilentShot=tick();local saved=Camera.CFrame;Camera.CFrame=CFrame.lookAt(Camera.CFrame.Position,getPredictedPosition(silentAimTarget));tool:Activate();Camera.CFrame=saved end end else silentAimTarget=nil end
if aimbotEnabled and showFOV and fovDegrees<180 then fovCircle.Position=frameCache.mousePos;fovCircle.Radius=getFOVPixelRadius();fovCircle.Color=fovColor;fovCircle.Visible=true else fovCircle.Visible=false end
if aimbotEnabled and not silentAimEnabled and aimActive then local th=getTarget();if th then local plr=Players:GetPlayerFromCharacter(th.Parent);if plr and isValidTarget(plr,th) then Camera.CFrame=CFrame.lookAt(Camera.CFrame.Position,getPredictedPosition(th));if autofireEnabled then currentTool=lp.Character and lp.Character:FindFirstChildOfClass("Tool");if currentTool then currentTool:Activate() end end else currentTarget=nil;targetLocked=false;if currentTool then currentTool:Deactivate();currentTool=nil end end else if currentTool then currentTool:Deactivate();currentTool=nil end end
else if not silentAimEnabled and currentTool then currentTool:Deactivate();currentTool=nil end;if not aimActive then currentTarget=nil;targetLocked=false end end
updatePlayersInRangeCache();cacheViewportPoints()
for plr,inR in pairs(playersInRange) do if inR then updatePlayerESP(plr) else hidePlayerESP(plr) end end
end)
