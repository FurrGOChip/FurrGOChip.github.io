local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ESP = { Master = false, Box = false, Names = false, Distance = false, Tracers = false }
local Aimlock = { Master = false, AimAssist = false, AimLock = false, Target = "Cercano", FOV = 120, Smoothness = 45, Prediction = 8, AutoShoot = false, AutoShootBtn = false }
local Pointer = { Paw = false }
local LockedTarget = nil
local LockedPart = nil
local HoldingAim = false
local LastAimRefresh = 0
local SavedAutoRotate = nil
local ESPObjects = {}
local ESPColor = Color3.fromRGB(0, 255, 0)
local fovGui = nil
local TeamColorCache = {}
local RoleDataCache = nil
local LastRoleDataRefresh = 0
local TeamPalette = {
    Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(80, 145, 255),
    Color3.fromRGB(255, 204, 75),
    Color3.fromRGB(90, 230, 145),
    Color3.fromRGB(220, 105, 255),
    Color3.fromRGB(255, 140, 70),
    Color3.fromRGB(80, 225, 230),
    Color3.fromRGB(245, 245, 245)
}

local transData = {
    {v = 0, n = "Nada de transparencia"},
    {v = 0.25, n = "Poca transparencia"},
    {v = 0.65, n = "Mucha transparencia"}
}
local transIdx = 1

local WOLF_PAW_ID = "rbxassetid://1068832074"
local OriginalMouseIcon = Mouse.Icon or ""
local OriginalMouseIconEnabled = UserInputService.MouseIconEnabled

local function GetRoot(char)
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char.PrimaryPart
    if root and root:IsA("BasePart") then return root end
    
    local bestPart = nil
    local bestScore = -1
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 0.98 then
            local size = part.Size
            local score = size.X * size.Y * size.Z
            if score > bestScore then
                bestScore = score
                bestPart = part
            end
        end
    end
    return bestPart or char:FindFirstChildWhichIsA("BasePart", true)
end

local function IsAlive(player)
    local char = player and player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local root = GetRoot(char)
    if not char or not root then return false end
    if humanoid then
        return humanoid.Health > 0
    end
    return char.Parent ~= nil
end

local function GetPartScore(part)
    if not part or not part:IsA("BasePart") then return 0 end
    if part.Transparency >= 0.98 then return 0 end
    local size = part.Size
    return math.max(size.X * size.Y * size.Z, 0.001)
end

local function GetModelScore(model)
    if not model then return 0, 0 end
    local score = 0
    local count = 0
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then
            local partScore = GetPartScore(obj)
            if partScore > 0 then
                score = score + partScore
                count = count + 1
            end
        end
    end
    return score, count
end

local function GetHighlightAdornees(player)
    local adornees = {}
    local char = player.Character
    if not char then return adornees end
    
    table.insert(adornees, char)
    
    local root = GetRoot(char)
    if root then
        for _, part in ipairs(root:GetConnectedParts()) do
            if not part:IsDescendantOf(char) then
                local current = part
                local morph = nil
                while current and current ~= workspace do
                    if current:IsA("Model") then
                        morph = current
                    end
                    current = current.Parent
                end
                
                local targetAdornee = morph or part
                local alreadyIn = false
                for _, a in ipairs(adornees) do if a == targetAdornee then alreadyIn = true end end
                if not alreadyIn then table.insert(adornees, targetAdornee) end
            end
        end
    end
    
    local extMorph = workspace:FindFirstChild(player.Name)
    if extMorph and extMorph:IsA("Model") and extMorph ~= char then
        local alreadyIn = false
        for _, a in ipairs(adornees) do if a == extMorph then alreadyIn = true end end
        if not alreadyIn then table.insert(adornees, extMorph) end
    end
    
    return adornees
end

local function GetLabelAdornee(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head", true)
    if head and head:IsA("BasePart") then return head end
    local root = char:FindFirstChild("HumanoidRootPart", true)
    if root and root:IsA("BasePart") then return root end
    return GetRoot(char)
end

local function NormalizeRoleName(role)
    if not role then return nil end
    role = tostring(role)
    if role == "" then return nil end
    local lowerRole = string.lower(role)
    if lowerRole:find("murder") or lowerRole:find("asesino") or lowerRole:find("killer") then
        return "Asesino"
    end
    if lowerRole:find("sheriff") or lowerRole:find("policia") or lowerRole:find("detective") then
        return "Sheriff"
    end
    if lowerRole:find("hero") or lowerRole:find("heroe") then
        return "Heroe"
    end
    if lowerRole:find("innocent") or lowerRole:find("inocente") or lowerRole:find("civil") then
        return "Inocente"
    end
    return role
end

local function GetCachedRoleData()
    local now = os.clock()
    if now - LastRoleDataRefresh < 1.25 then
        return RoleDataCache ~= false and RoleDataCache or nil
    end
    LastRoleDataRefresh = now
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local extras = remotes and remotes:FindFirstChild("Extras")
    local getter = extras and extras:FindFirstChild("GetPlayerData")
    if not getter then
        getter = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    end
    if not getter or not getter:IsA("RemoteFunction") then
        RoleDataCache = false
        return nil
    end
    local ok, data = pcall(function()
        return getter:InvokeServer()
    end)
    if ok and type(data) == "table" then
        RoleDataCache = data
        return RoleDataCache
    end
    RoleDataCache = false
    return nil
end

local function ReadRoleRecord(record)
    if type(record) == "string" then
        return NormalizeRoleName(record)
    end
    if type(record) ~= "table" then
        return nil
    end
    return NormalizeRoleName(record.Role or record.role or record.Rol or record.rol or record.Team or record.team)
end

local function GetRemoteRoleName(player)
    local data = GetCachedRoleData()
    if not data then return nil end
    local directRole = ReadRoleRecord(data[player.Name]) or ReadRoleRecord(data[tostring(player.UserId)]) or ReadRoleRecord(data[player.UserId])
    if directRole then return directRole end
    for _, record in pairs(data) do
        if type(record) == "table" then
            local recordName = record.Name or record.PlayerName or record.Username
            local recordUserId = record.UserId or record.userId
            if recordName == player.Name or tostring(recordUserId) == tostring(player.UserId) then
                local role = ReadRoleRecord(record)
                if role then return role end
            end
        end
    end
    return nil
end

local function HasExactTool(container, exactNames)
    if not container then return false end
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Tool") then
            local lowerName = string.lower(obj.Name)
            for _, n in ipairs(exactNames) do
                if lowerName == n then
                    return true
                end
            end
        end
    end
    return false
end

local KNIFE_NAMES = {"knife", "cuchillo"}
local GUN_NAMES = {"gun", "revolver", "pistol", "pistola"}

local function PlayerHasKnife(player)
    if not player then return false end
    return HasExactTool(player.Character, KNIFE_NAMES) or HasExactTool(player:FindFirstChildOfClass("Backpack"), KNIFE_NAMES)
end

local function PlayerHasGun(player)
    if not player then return false end
    return HasExactTool(player.Character, GUN_NAMES) or HasExactTool(player:FindFirstChildOfClass("Backpack"), GUN_NAMES)
end

local PlayerRoleMap = {}
local LastRoleMapTime = 0
local ROLE_MAP_REFRESH = 0.4
local RoleMapBuildId = 0

local function GetPlayerTeamOrRoleNameRaw(player)
    local exactNames = {"Role", "role", "RoleValue", "Rol", "rol"}
    local possibleNames = {"role", "team", "squad", "rol"}
    local avoidNames = {"equip", "class", "job", "status", "level", "fruit", "fruta", "nivel", "clase", "weapon", "knife", "gun", "blade", "sword", "pet", "coin", "gem", "cash"}

    local locations = {player, player.Character, player:FindFirstChild("leaderstats")}

    for _, loc in ipairs(locations) do
        if loc then
            for _, exact in ipairs(exactNames) do
                local val = loc:GetAttribute(exact)
                if val and type(val) == "string" and val ~= "" then
                    return NormalizeRoleName(val)
                end
            end

            for _, exact in ipairs(exactNames) do
                local child = loc:FindFirstChild(exact)
                if child then
                    if child:IsA("StringValue") and child.Value ~= "" then
                        return NormalizeRoleName(child.Value)
                    elseif child:IsA("ObjectValue") and child.Value and child.Value.Name then
                        return NormalizeRoleName(child.Value.Name)
                    end
                end
            end
        end
    end

    local remoteRole = GetRemoteRoleName(player)
    if remoteRole then
        return remoteRole
    end

    for _, loc in ipairs(locations) do
        if loc then
            for attrName, attrValue in pairs(loc:GetAttributes()) do
                local lowerName = string.lower(attrName)
                local isGood, isBad = false, false
                for _, pName in ipairs(possibleNames) do if lowerName:find(pName) then isGood = true; break end end
                for _, aName in ipairs(avoidNames) do if lowerName:find(aName) then isBad = true; break end end

                if isGood and not isBad and type(attrValue) == "string" and attrValue ~= "" then
                    return NormalizeRoleName(attrValue)
                end
            end

            for _, child in ipairs(loc:GetChildren()) do
                local lowerName = string.lower(child.Name)
                local isGood, isBad = false, false
                for _, pName in ipairs(possibleNames) do if lowerName:find(pName) then isGood = true; break end end
                for _, aName in ipairs(avoidNames) do if lowerName:find(aName) then isBad = true; break end end

                if isGood and not isBad then
                    if child:IsA("StringValue") and child.Value ~= "" then
                        return NormalizeRoleName(child.Value)
                    end
                end
            end
        end
    end

    if player.Team then
        return player.Team.Name
    end

    return nil
end

local function BuildPlayerRoleMap(force)
    local now = os.clock()
    if not force and now - LastRoleMapTime < ROLE_MAP_REFRESH then return end
    LastRoleMapTime = now

    local myBuildId = RoleMapBuildId
    local players = Players:GetPlayers()
    local newMap = {}

    for _, p in ipairs(players) do
        local ok, role = pcall(GetPlayerTeamOrRoleNameRaw, p)
        if ok then newMap[p] = role end
    end

    if RoleMapBuildId ~= myBuildId then return end

    local toolMurderer = nil
    local toolSheriff = nil
    for _, p in ipairs(players) do
        if IsAlive(p) and PlayerHasKnife(p) then
            toolMurderer = p
            break
        end
    end
    for _, p in ipairs(players) do
        if IsAlive(p) and p ~= toolMurderer and PlayerHasGun(p) then
            toolSheriff = p
            break
        end
    end

    if toolMurderer then
        newMap[toolMurderer] = "Asesino"
        for _, p in ipairs(players) do
            if p ~= toolMurderer and newMap[p] == "Asesino" then
                newMap[p] = "Inocente"
            end
        end
    else
        for _, p in ipairs(players) do
            if newMap[p] == "Asesino" then
                newMap[p] = "Inocente"
            end
        end
    end

    if toolSheriff then
        newMap[toolSheriff] = "Sheriff"
        for _, p in ipairs(players) do
            if p ~= toolSheriff and newMap[p] == "Sheriff" then
                newMap[p] = "Inocente"
            end
        end
    else
        for _, p in ipairs(players) do
            if newMap[p] == "Sheriff" then
                newMap[p] = "Inocente"
            end
        end
    end

    local seenAsesino = nil
    local seenSheriff = nil
    for _, p in ipairs(players) do
        local role = newMap[p]
        if role == "Asesino" then
            if seenAsesino then newMap[p] = "Inocente" else seenAsesino = p end
        elseif role == "Sheriff" then
            if seenSheriff then newMap[p] = "Inocente" else seenSheriff = p end
        end
    end

    if RoleMapBuildId ~= myBuildId then return end
    PlayerRoleMap = newMap
end

local function GetPlayerTeamOrRoleName(player)
    if not player then return nil end
    BuildPlayerRoleMap(false)
    return PlayerRoleMap[player]
end

local function GetPlayerESPColor(player)
    local teamName = GetPlayerTeamOrRoleName(player)
    if teamName and teamName ~= "" then
        local lowerName = string.lower(teamName)
        
        if lowerName:find("murder") or lowerName:find("asesino") or lowerName:find("killer") then
            return Color3.fromRGB(255, 50, 50)
        elseif lowerName:find("sheriff") or lowerName:find("keeper") or lowerName:find("guard") or lowerName:find("policia") or lowerName:find("cop") or lowerName:find("detective") then
            return Color3.fromRGB(50, 150, 255)
        elseif lowerName:find("hero") or lowerName:find("heroe") then
            return Color3.fromRGB(255, 215, 70)
        elseif lowerName:find("innocent") or lowerName:find("inocente") or lowerName:find("civil") or lowerName:find("jugador") or lowerName:find("player") then
            return Color3.fromRGB(50, 220, 100)
        end
        
        if player.Team and player.TeamColor and player.TeamColor.Color ~= BrickColor.new("White").Color then
            return player.TeamColor.Color
        end
        
        if not TeamColorCache[teamName] then
            local hash = 0
            for i = 1, #teamName do
                hash = (hash + string.byte(teamName, i) * i) % #TeamPalette
            end
            TeamColorCache[teamName] = TeamPalette[hash + 1]
        end
        return TeamColorCache[teamName]
    end
    
    if player.TeamColor and player.TeamColor.Color ~= BrickColor.new("White").Color then
        return player.TeamColor.Color
    end
    
    return ESPColor
end

local function GetAimPart(player)
    local char = player and player.Character
    if not char then return nil end
    
    local function getValidPart(name)
        local p = char:FindFirstChild(name)
        return (p and p:IsA("BasePart")) and p or nil
    end

    if Aimlock.Target == "Cabeza" then
        return getValidPart("Head") or GetRoot(char)
    end
    if Aimlock.Target == "Torso" then
        return getValidPart("UpperTorso") or getValidPart("Torso") or GetRoot(char)
    end
    local parts = {
        getValidPart("Head"),
        getValidPart("UpperTorso"),
        getValidPart("Torso"),
        getValidPart("HumanoidRootPart")
    }
    local closestPart = nil
    local closestDist = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, part in ipairs(parts) do
        if part then
            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen and pos.Z > 0 then
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPart = part
                end
            end
        end
    end
    return closestPart or GetRoot(char)
end

local function GetClosestPlayerToCenter()
    local closestDist = math.huge
    local closestPlayer = nil
    local closestPart = nil
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local part = GetAimPart(player)
            if part then
                local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if onScreen and pos.Z > 0 and dist < closestDist and dist <= Aimlock.FOV then
                    closestDist = dist
                    closestPlayer = player
                    closestPart = part
                end
            end
        end
    end
    return closestPlayer, closestPart, closestDist
end

local function GetClosestPlayerByDistance()
    local closestDist = math.huge
    local closestPlayer = nil
    local closestPart = nil
    local myRoot = LocalPlayer.Character and GetRoot(LocalPlayer.Character)
    if not myRoot then return nil, nil, closestDist end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local root = GetRoot(player.Character)
            local part = GetAimPart(player)
            if root and part then
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = player
                    closestPart = part
                end
            end
        end
    end
    return closestPlayer, closestPart, closestDist
end

local function GetPredictedPosition(part)
    if not part then return end
    local velocity = Vector3.new(0, 0, 0)
    pcall(function() velocity = part.AssemblyLinearVelocity end)
    local prediction = math.clamp(Aimlock.Prediction, 0, 25) / 100
    return part.Position + (velocity * prediction)
end

local function GetAimAlpha(dt)
    return math.clamp((Aimlock.Smoothness / 100) + ((dt or 0) * 4), 0.05, 1)
end

local function AimAtPart(part, dt)
    if not part then return end
    local targetPosition = GetPredictedPosition(part)
    local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, GetAimAlpha(dt))
end

local function IsFirstPerson()
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    return LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson or (head and (Camera.CFrame.Position - head.Position).Magnitude < 1.6) or (Camera.CFrame.Position - Camera.Focus.Position).Magnitude < 1.2
end

local function SetCharacterAutoRotate(enabled)
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if enabled then
        if SavedAutoRotate ~= nil then
            humanoid.AutoRotate = SavedAutoRotate
            SavedAutoRotate = nil
        end
    else
        if SavedAutoRotate == nil then
            SavedAutoRotate = humanoid.AutoRotate
        end
        humanoid.AutoRotate = false
    end
end

local function RotateCharacterToPart(part, dt)
    local char = LocalPlayer.Character
    local root = char and GetRoot(char)
    if not root or not part then return end
    local targetPosition = GetPredictedPosition(part)
    local flatTarget = Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z)
    if (flatTarget - root.Position).Magnitude < 0.1 then return end
    SetCharacterAutoRotate(false)
    root.CFrame = root.CFrame:Lerp(CFrame.new(root.Position, flatTarget), GetAimAlpha(dt))
end

local function ReleaseAimlockMovement()
    SetCharacterAutoRotate(true)
end

local function GetESPObject(player)
    if not ESPObjects[player] then
        ESPObjects[player] = {}
    end
    if not ESPObjects[player].Tracer then
        local tracer = Instance.new("Frame")
        tracer.Name = "ESPTracer"
        tracer.AnchorPoint = Vector2.new(0.5, 0.5)
        tracer.BorderSizePixel = 0
        tracer.BackgroundColor3 = ESPColor
        tracer.Visible = false
        tracer.ZIndex = 15
        tracer.Parent = fovGui
        ESPObjects[player].Tracer = tracer
    end
    return ESPObjects[player]
end

local function UpdateTracer(player, root, color)
    local obj = GetESPObject(player)
    local tracer = obj.Tracer
    if not ESP.Master or not ESP.Tracers or not root or not IsAlive(player) then
        tracer.Visible = false
        return
    end
    local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
    if not onScreen or pos.Z <= 0 then
        tracer.Visible = false
        return
    end
    local from = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 10)
    local to = Vector2.new(pos.X, pos.Y)
    local delta = to - from
    tracer.Size = UDim2.new(0, delta.Magnitude, 0, 2)
    tracer.Position = UDim2.new(0, from.X + (delta.X / 2), 0, from.Y + (delta.Y / 2))
    local angle = math.atan2 and math.atan2(delta.Y, delta.X) or math.atan(delta.Y, delta.X)
    tracer.Rotation = math.deg(angle)
    tracer.BackgroundColor3 = color
    tracer.Visible = true
end

local function ClearESPObject(player)
    local obj = ESPObjects[player]
    if obj then
        if obj.Tracer then obj.Tracer:Destroy() end
        if obj.Highlights then
            for _, h in ipairs(obj.Highlights) do h:Destroy() end
        end
        if obj.NameTag then obj.NameTag:Destroy() end
        ESPObjects[player] = nil
    end
end

local function CleanOldUI(name)
    local g1 = CoreGui:FindFirstChild(name)
    if g1 then g1:Destroy() end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        local g2 = pg:FindFirstChild(name)
        if g2 then g2:Destroy() end
    end
end

CleanOldUI("FurrGOFov")
CleanOldUI("FurrGOPointer")
CleanOldUI("FurrGOChip")

fovGui = Instance.new("ScreenGui")
fovGui.Name = "FurrGOFov"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true
fovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local s = pcall(function() fovGui.Parent = CoreGui end)
if not s then fovGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local fovCircle = Instance.new("Frame")
fovCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fovCircle.BackgroundTransparency = 1
fovCircle.ZIndex = 30
fovCircle.Parent = fovGui
local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(0, 255, 0)
fovStroke.Thickness = 1
fovStroke.Parent = fovCircle
fovCircle.Visible = false

local fovPulsing = false
local function StartFovPulse()
    if fovPulsing then return end
    fovPulsing = true
    local function pulse()
        if not fovPulsing then return end
        TweenService:Create(fovStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Thickness = 1.6}):Play()
        task.delay(0.9, function()
            if not fovPulsing then fovStroke.Thickness = 1; return end
            TweenService:Create(fovStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Thickness = 0.6}):Play()
            task.delay(0.9, pulse)
        end)
    end
    pulse()
end
local function StopFovPulse()
    fovPulsing = false
    fovStroke.Thickness = 1
end

local pointerGui = Instance.new("ScreenGui")
pointerGui.Name = "FurrGOPointer"
pointerGui.ResetOnSpawn = false
pointerGui.IgnoreGuiInset = true
pointerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local ps = pcall(function() pointerGui.Parent = CoreGui end)
if not ps then pointerGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local pointerPaw = Instance.new("Frame")
pointerPaw.Size = UDim2.new(0, 34, 0, 34)
pointerPaw.BackgroundTransparency = 1
pointerPaw.Visible = false
pointerPaw.Rotation = -16
pointerPaw.ZIndex = 1000
pointerPaw.Parent = pointerGui

local function MakePawPart(size, pos, color, z)
    local part = Instance.new("Frame")
    part.Size = size
    part.Position = pos
    part.BackgroundColor3 = color
    part.BorderSizePixel = 0
    part.ZIndex = z
    part.Parent = pointerPaw
    Instance.new("UICorner", part).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", part)
    stroke.Color = Color3.fromRGB(18, 18, 18)
    stroke.Thickness = 1
    return part
end

MakePawPart(UDim2.new(0, 10, 0, 10), UDim2.new(0, 3, 0, 8), Color3.fromRGB(0, 255, 65), 1001)
MakePawPart(UDim2.new(0, 10, 0, 10), UDim2.new(0, 11, 0, 2), Color3.fromRGB(0, 255, 65), 1001)
MakePawPart(UDim2.new(0, 10, 0, 10), UDim2.new(0, 21, 0, 6), Color3.fromRGB(0, 255, 65), 1001)
MakePawPart(UDim2.new(0, 19, 0, 16), UDim2.new(0, 8, 0, 16), Color3.fromRGB(245, 245, 245), 1000)

UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.UserInputType == Enum.UserInputType.MouseButton2 then
        HoldingAim = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        HoldingAim = false
    end
end)

local function SimulateRightClick()
    local success = pcall(function()
        if mouse2click then
            mouse2click()
        else
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end
    end)
    if not success then
        pcall(function()
            local VirtualInputManager = game:GetService("VirtualInputManager")
            local mouseLoc = UserInputService:GetMouseLocation()
            VirtualInputManager:SendMouseButtonEvent(mouseLoc.X, mouseLoc.Y, 1, true, game, 1)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(mouseLoc.X, mouseLoc.Y, 1, false, game, 1)
        end)
    end
end

task.spawn(function()
    while fovGui and fovGui.Parent do
        task.wait(0.1)
        if Aimlock.AutoShoot then
            SimulateRightClick()
        end
    end
end)


local renderConn
renderConn = RunService.RenderStepped:Connect(function(dt)
    if not fovGui or not fovGui.Parent then
        if renderConn then renderConn:Disconnect() end
        return
    end
    fovCircle.Size = UDim2.new(0, Aimlock.FOV * 2, 0, Aimlock.FOV * 2)
    fovCircle.Position = UDim2.new(0, (Camera.ViewportSize.X / 2) - Aimlock.FOV, 0, (Camera.ViewportSize.Y / 2) - Aimlock.FOV)
    fovCircle.Visible = Aimlock.Master
    if Aimlock.Master and Aimlock.AimLock and not fovPulsing then
        StartFovPulse()
    elseif (not Aimlock.Master or not Aimlock.AimLock) and fovPulsing then
        StopFovPulse()
    end
    
    if Aimlock.AimLock then
        local valid = LockedTarget and IsAlive(LockedTarget) and LockedPart and LockedPart.Parent
        LastAimRefresh = LastAimRefresh + (dt or 0)
        if not valid or LastAimRefresh >= 0.18 then
            LockedTarget, LockedPart = GetClosestPlayerByDistance()
            LastAimRefresh = 0
        end
        if LockedTarget and LockedPart then
            RotateCharacterToPart(LockedPart, dt)
            if IsFirstPerson() then
                AimAtPart(LockedPart, dt)
            end
        end
    elseif Aimlock.Master and Aimlock.AimAssist and HoldingAim then
        ReleaseAimlockMovement()
        local target, part = GetClosestPlayerToCenter()
        if target and part then
            AimAtPart(part, dt)
        end
    else
        LockedTarget = nil
        LockedPart = nil
        LastAimRefresh = 0
        ReleaseAimlockMovement()
    end
    
    if Pointer.Paw then
        UserInputService.MouseIconEnabled = false
        pointerPaw.Visible = true
        local mouseLocation = UserInputService:GetMouseLocation()
        pointerPaw.Position = UDim2.new(0, mouseLocation.X + 4, 0, mouseLocation.Y + 4)
    else
        UserInputService.MouseIconEnabled = OriginalMouseIconEnabled
        Mouse.Icon = OriginalMouseIcon
        pointerPaw.Visible = false
    end
end)

local function UpdateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local root = GetRoot(char)
            local espColor = GetPlayerESPColor(player)
            local obj = GetESPObject(player)
            
            UpdateTracer(player, root, espColor)
            
            if ESP.Master and IsAlive(player) and char then
                local adornees = GetHighlightAdornees(player)
                
                if not obj.Highlights then obj.Highlights = {} end
                while #obj.Highlights > #adornees do
                    local h = table.remove(obj.Highlights)
                    h:Destroy()
                end
                
                for i, adornee in ipairs(adornees) do
                    local hl = obj.Highlights[i]
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "ESPHl_" .. player.Name .. "_" .. i
                        hl.FillTransparency = 0.35
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = fovGui
                        obj.Highlights[i] = hl
                    end
                    
                    hl.Adornee = adornee
                    hl.Enabled = not not ESP.Box
                    hl.FillColor = espColor
                    hl.OutlineColor = espColor
                end
                
                local labelAdornee = GetLabelAdornee(char)
                if labelAdornee then
                    local bg = obj.NameTag
                    if not bg then
                        bg = Instance.new("BillboardGui")
                        bg.Name = "ESPName_" .. player.Name
                        bg.Parent = fovGui
                        bg.Size = UDim2.new(0, 200, 0, 50)
                        bg.StudsOffset = Vector3.new(0, 2, 0)
                        bg.AlwaysOnTop = true
                        
                        local tl = Instance.new("TextLabel")
                        tl.Parent = bg
                        tl.Size = UDim2.new(1, 0, 1, 0)
                        tl.BackgroundTransparency = 1
                        tl.TextStrokeTransparency = 0
                        tl.TextScaled = true
                        
                        obj.NameTag = bg
                    end
                    
                    bg.Adornee = labelAdornee
                    local tl = bg:FindFirstChildOfClass("TextLabel")
                    if tl then
                        tl.TextColor3 = espColor
                        local distStr = ""
                        if ESP.Distance and root then
                            local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                            distStr = "\n[" .. tostring(dist) .. "m]"
                        end
                        if ESP.Names then
                            local teamName = GetPlayerTeamOrRoleName(player) or "Jugador"
                            tl.Text = player.Name .. " (" .. teamName .. ")" .. distStr
                        else
                            tl.Text = distStr
                        end
                    end
                    bg.Enabled = (ESP.Names or ESP.Distance)
                else
                    if obj.NameTag then obj.NameTag.Enabled = false end
                end
            else
                if obj.Highlights then
                    for _, h in ipairs(obj.Highlights) do h:Destroy() end
                    obj.Highlights = {}
                end
                if obj.NameTag then
                    obj.NameTag:Destroy()
                    obj.NameTag = nil
                end
            end
        end
    end
end

local hbConn
hbConn = RunService.Heartbeat:Connect(function()
    if not fovGui or not fovGui.Parent then
        if hbConn then hbConn:Disconnect() end
        return
    end
    UpdateESP()
end)

Players.PlayerRemoving:Connect(function(player)
    ClearESPObject(player)
    PlayerRoleMap[player] = nil
    if LockedTarget == player then
        LockedTarget = nil
        LockedPart = nil
    end
end)

local function InvalidateRoleCache()
    RoleMapBuildId = RoleMapBuildId + 1
    LastRoleMapTime = 0
    PlayerRoleMap = {}
end

local function HookPlayerForRoleInvalidation(player)
    if not player then return end
    local function bindBackpack(backpack)
        if not backpack then return end
        backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then InvalidateRoleCache() end
        end)
        backpack.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then InvalidateRoleCache() end
        end)
    end
    local function bindCharacter(char)
        if not char then return end
        InvalidateRoleCache()
        local humanoid = char:WaitForChild("Humanoid", 3)
        if humanoid then
            humanoid.Died:Connect(InvalidateRoleCache)
        end
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then InvalidateRoleCache() end
        end)
        char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then InvalidateRoleCache() end
        end)
    end
    bindBackpack(player:FindFirstChildOfClass("Backpack"))
    player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then bindBackpack(child) end
    end)
    if player.Character then bindCharacter(player.Character) end
    player.CharacterAdded:Connect(bindCharacter)
end

for _, p in ipairs(Players:GetPlayers()) do
    HookPlayerForRoleInvalidation(p)
end
Players.PlayerAdded:Connect(HookPlayerForRoleInvalidation)

LocalPlayer.CharacterAdded:Connect(function()
    LockedTarget = nil
    LockedPart = nil
    LastAimRefresh = 0
    SavedAutoRotate = nil
    InvalidateRoleCache()
end)

local LOGO_ID      = "rbxassetid://86235109599983"
local C_ACCENT     = Color3.fromRGB(0, 255, 65)
local C_ACCENT_DIM = Color3.fromRGB(0, 168, 46)
local C_BG         = Color3.fromRGB(10, 10, 10)
local C_SIDEBAR    = Color3.fromRGB(6,  6,  6)
local C_CARD       = Color3.fromRGB(16, 16, 16)
local C_BORDER     = Color3.fromRGB(34, 34, 34)
local C_PRI        = Color3.fromRGB(235, 235, 235)
local C_SEC        = Color3.fromRGB(108, 108, 108)
local C_MUT        = Color3.fromRGB(48,  48,  48)

local function Tw(obj, props, t, style, dir)
    local ti = TweenInfo.new(t or 0.28, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, ti, props)
    tw:Play()
    return tw
end

local function Drag(handle, target)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = target.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then dragInput = inp end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp == dragInput and dragging then
            local d = inp.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function IcoESP(parent)
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 18, 0, 18)
    img.Position = UDim2.new(0.5, -9, 0.5, -9)
    img.BackgroundTransparency = 1
    img.ImageColor3 = C_MUT
    img.ZIndex = 8
    img.Image = "rbxassetid://16898669897"
    img.ImageRectOffset = Vector2.new(0, 0)
    img.ImageRectSize = Vector2.new(256, 256)
    img.Parent = parent
    return {img}
end

local function IcoAim(parent)
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 18, 0, 18)
    img.Position = UDim2.new(0.5, -9, 0.5, -9)
    img.BackgroundTransparency = 1
    img.ImageColor3 = C_MUT
    img.ZIndex = 8
    img.Image = "rbxassetid://16898668482"
    img.ImageRectOffset = Vector2.new(514, 257)
    img.ImageRectSize = Vector2.new(256, 256)
    img.Parent = parent
    return {img}
end

local function IcoPtr(parent)
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 18, 0, 18)
    img.Position = UDim2.new(0.5, -9, 0.5, -9)
    img.BackgroundTransparency = 1
    img.ImageColor3 = C_MUT
    img.ZIndex = 8
    img.Image = "rbxassetid://16898732061"
    img.ImageRectOffset = Vector2.new(514, 514)
    img.ImageRectSize = Vector2.new(256, 256)
    img.Parent = parent
    return {img}
end

local function IcoCreditos(parent)
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 18, 0, 18)
    img.Position = UDim2.new(0.5, -9, 0.5, -9)
    img.BackgroundTransparency = 1
    img.ImageColor3 = C_MUT
    img.ZIndex = 8
    img.Image = "rbxassetid://16898673523"
    img.ImageRectOffset = Vector2.new(257, 257)
    img.ImageRectSize = Vector2.new(256, 256)
    img.Parent = parent
    return {img}
end

local function IcoConfig(parent)
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, 18, 0, 18)
    img.Position = UDim2.new(0.5, -9, 0.5, -9)
    img.BackgroundTransparency = 1
    img.ImageColor3 = C_MUT
    img.ZIndex = 8
    img.Image = "rbxassetid://16898735040"
    img.ImageRectOffset = Vector2.new(257, 257)
    img.ImageRectSize = Vector2.new(256, 256)
    img.Parent = parent
    return {img}
end

local function CreateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "FurrGOChip"
    gui.ResetOnSpawn = false
    local ok = pcall(function() gui.Parent = CoreGui end)
    if not ok then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local floatBtn = Instance.new("TextButton")
    floatBtn.Name = "AutoShootFloatBtn"
    floatBtn.Size = UDim2.new(0, 50, 0, 50)
    floatBtn.Position = UDim2.new(0.3, 25, 0.5, 25)
    floatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    floatBtn.BackgroundColor3 = C_BG
    floatBtn.Text = ""
    floatBtn.AutoButtonColor = false
    floatBtn.ZIndex = 500
    floatBtn.Visible = false
    floatBtn.Parent = gui
    
    Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0.5, 0)
    local floatStr = Instance.new("UIStroke", floatBtn)
    floatStr.Color = C_BORDER
    floatStr.Thickness = 1.5
    
    local floatIcon = Instance.new("ImageLabel")
    floatIcon.Size = UDim2.new(0, 24, 0, 24)
    floatIcon.Position = UDim2.new(0.5, -12, 0.5, -12)
    floatIcon.BackgroundTransparency = 1
    floatIcon.Image = "rbxassetid://16898668482"
    floatIcon.ImageColor3 = C_ACCENT
    floatIcon.ImageRectOffset = Vector2.new(514, 257)
    floatIcon.ImageRectSize = Vector2.new(256, 256)
    floatIcon.ZIndex = 501
    floatIcon.Parent = floatBtn

    Drag(floatBtn, floatBtn)

    floatBtn.MouseEnter:Connect(function()
        Tw(floatBtn, {BackgroundColor3 = Color3.fromRGB(18, 18, 18), Size = UDim2.new(0, 54, 0, 54)}, 0.15)
        Tw(floatStr, {Color = C_ACCENT}, 0.2)
        Tw(floatIcon, {Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0.5, -13, 0.5, -13)}, 0.15)
    end)
    
    floatBtn.MouseLeave:Connect(function()
        Tw(floatBtn, {BackgroundColor3 = C_BG, Size = UDim2.new(0, 50, 0, 50)}, 0.2)
        Tw(floatStr, {Color = C_BORDER}, 0.25)
        Tw(floatIcon, {Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0.5, -12, 0.5, -12)}, 0.2)
    end)

    floatBtn.MouseButton1Down:Connect(function()
        Tw(floatBtn, {Size = UDim2.new(0, 44, 0, 44)}, 0.1, Enum.EasingStyle.Sine)
        Tw(floatStr, {Thickness = 2.5, Color = C_ACCENT_DIM}, 0.1)
    end)

    floatBtn.MouseButton1Up:Connect(function()
        Tw(floatBtn, {Size = UDim2.new(0, 54, 0, 54)}, 0.15, Enum.EasingStyle.Back)
        Tw(floatStr, {Thickness = 1.5, Color = C_ACCENT}, 0.15)
    end)

    floatBtn.MouseButton1Click:Connect(function()
        SimulateRightClick()
    end)


    local WIN_W, WIN_H = 560, 400
    local SB_W, TB_H  = 48, 36
    local isOpen = false
    local CUR_W, CUR_H = WIN_W, WIN_H

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0)
    main.Size   = UDim2.new(0, WIN_W, 0, WIN_H)
    main.Position = UDim2.new(0.5, 0, 0.18, 0)
    main.BackgroundColor3 = C_BG
    main.BackgroundTransparency = transData[transIdx].v
    main.BorderSizePixel  = 0
    main.ClipsDescendants = true
    main.Visible = false
    main.Parent  = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
    local mainBorder = Instance.new("UIStroke", main)
    mainBorder.Color = C_BORDER; mainBorder.Thickness = 1

    local function CreateCornerGlow(position, anchor)
        local glow = Instance.new("Frame")
        glow.Size = UDim2.new(0, 6, 0, 6)
        glow.Position = position
        glow.AnchorPoint = anchor
        glow.BackgroundColor3 = C_ACCENT
        glow.BorderSizePixel = 0
        glow.ZIndex = 99
        glow.Parent = main
        Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
        
        local stroke = Instance.new("UIStroke", glow)
        stroke.Color = C_ACCENT
        stroke.Thickness = 1.5
        stroke.Transparency = 0.4
        
        task.spawn(function()
            while true do
                if not main or not main.Parent then break end
                Tw(glow, {BackgroundTransparency = 0.1}, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                Tw(stroke, {Transparency = 0.2, Thickness = 2.5}, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(1)
                Tw(glow, {BackgroundTransparency = 0.6}, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                Tw(stroke, {Transparency = 0.7, Thickness = 1.2}, 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(1)
            end
        end)
        return glow
    end

    CreateCornerGlow(UDim2.new(0, 5, 0, 5), Vector2.new(0, 0))
    CreateCornerGlow(UDim2.new(1, -5, 0, 5), Vector2.new(1, 0))
    CreateCornerGlow(UDim2.new(0, 5, 1, -5), Vector2.new(0, 1))
    CreateCornerGlow(UDim2.new(1, -5, 1, -5), Vector2.new(1, 1))

    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(0, 0, 0, 1)
    accentLine.Position = UDim2.new(0, SB_W, 0, 0)
    accentLine.BackgroundColor3 = C_ACCENT
    accentLine.BorderSizePixel = 0
    accentLine.ZIndex = 8
    accentLine.Parent = main

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SB_W, 1, 0)
    sidebar.BackgroundColor3 = C_SIDEBAR
    sidebar.BackgroundTransparency = transData[transIdx].v
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 5
    sidebar.Parent = main
    local sbBorder = Instance.new("UIStroke", sidebar)
    sbBorder.Color = C_BORDER; sbBorder.Thickness = 1
    sbBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local logoImg = Instance.new("ImageLabel")
    logoImg.Size = UDim2.new(0, 34, 0, 34)
    logoImg.Position = UDim2.new(0.5, -17, 0, 7)
    logoImg.BackgroundTransparency = 1
    logoImg.Image = LOGO_ID
    logoImg.ZIndex = 6
    logoImg.Parent = sidebar
    Instance.new("UICorner", logoImg).CornerRadius = UDim.new(0, 6)
    local logoStr = Instance.new("UIStroke", logoImg)
    logoStr.Color = C_ACCENT; logoStr.Thickness = 1

    local verLbl = Instance.new("TextLabel")
    verLbl.Size = UDim2.new(1, 0, 0, 12)
    verLbl.Position = UDim2.new(0, 0, 0, 44)
    verLbl.BackgroundTransparency = 1
    verLbl.Text = "v3.0"
    verLbl.TextColor3 = C_MUT
    verLbl.Font = Enum.Font.Code
    verLbl.TextSize = 8
    verLbl.ZIndex = 6
    verLbl.Parent = sidebar

    local topbar = Instance.new("Frame")
    topbar.Size = UDim2.new(1, -SB_W, 0, TB_H)
    topbar.Position = UDim2.new(0, SB_W, 0, 0)
    topbar.BackgroundTransparency = 1
    topbar.ZIndex = 5
    topbar.Parent = main
    Drag(topbar, main)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0, 120, 0, TB_H)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "FURR_GO"
    titleLbl.TextColor3 = C_ACCENT
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 6
    titleLbl.Parent = topbar

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(0, 110, 0, TB_H)
    subLbl.Position = UDim2.new(0, 88, 0, 0)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = "EDICION CHIP"
    subLbl.TextColor3 = C_MUT
    subLbl.Font = Enum.Font.Code
    subLbl.TextSize = 8
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.ZIndex = 6
    subLbl.Parent = topbar

    local sizeData = {
        {w = 440, h = 320, n = "Chico"},
        {w = 560, h = 400, n = "Mediano"},
        {w = 700, h = 480, n = "Grande"},
    }
    local sizeIdx = 2

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -SB_W, 0, 1)
    divider.Position = UDim2.new(0, SB_W, 0, TB_H)
    divider.BackgroundColor3 = C_BORDER
    divider.BorderSizePixel = 0
    divider.ZIndex = 4
    divider.Parent = main

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -SB_W, 1, -(TB_H + 1))
    contentArea.Position = UDim2.new(0, SB_W, 0, TB_H + 1)
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.Parent = main

    local tooltip = Instance.new("Frame")
    tooltip.Size = UDim2.new(0, 0, 0, 20)
    tooltip.Position = UDim2.new(0, SB_W + 6, 0, 0)
    tooltip.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    tooltip.BorderSizePixel = 0
    tooltip.ZIndex = 20
    tooltip.ClipsDescendants = true
    tooltip.Visible = false
    tooltip.Parent = main
    Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 4)
    local ttStr = Instance.new("UIStroke", tooltip); ttStr.Color = C_BORDER; ttStr.Thickness = 1
    local ttLbl = Instance.new("TextLabel", tooltip)
    ttLbl.Size = UDim2.new(1, -8, 1, 0)
    ttLbl.Position = UDim2.new(0, 4, 0, 0)
    ttLbl.BackgroundTransparency = 1
    ttLbl.TextColor3 = C_PRI
    ttLbl.Font = Enum.Font.GothamMedium
    ttLbl.TextSize = 10
    ttLbl.TextXAlignment = Enum.TextXAlignment.Left
    ttLbl.ZIndex = 21

    local tabs = {}
    local tabButtons = {}
    local activeKey = nil

    local TAB_ORDER = {ESP = 1, Aim = 2, Ptr = 3, Config = 4, Creditos = 5}
    local TAB_NAMES = {ESP = "ESP", Aim = "Aimbot", Ptr = "Cursor", Config = "Ajustes", Creditos = "Créditos"}

    local function TwIconParts(parts, col)
        for _, p in ipairs(parts or {}) do
            if p:IsA("ImageLabel") then Tw(p, {ImageColor3 = col}, 0.2)
            elseif p:IsA("UIStroke") then Tw(p, {Color = col}, 0.2)
            else Tw(p, {BackgroundColor3 = col}, 0.2) end
        end
    end

    local function SwitchTab(key)
        if activeKey == key then return end

        local oldKey = activeKey
        local dir = ((TAB_ORDER[key] or 0) > (TAB_ORDER[oldKey] or 0)) and 1 or -1

        local oldPg = tabs[oldKey]
        if oldPg and oldPg.Visible then
            local exitX = dir > 0 and -22 or 40
            Tw(oldPg, {Position = UDim2.new(0, exitX, 0, 10)}, 0.17, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            task.delay(0.17, function()
                if oldPg.Visible then
                    oldPg.Visible = false
                    oldPg.Position = UDim2.new(0, 14, 0, 10)
                end
            end)
        end

        divider.BackgroundColor3 = C_ACCENT
        Tw(divider, {BackgroundColor3 = C_BORDER}, 0.5)

        accentLine.Size = UDim2.new(0, 0, 0, 1)
        Tw(accentLine, {Size = UDim2.new(1, -SB_W, 0, 1)}, 0.45, Enum.EasingStyle.Quint)

        for k, d in pairs(tabButtons) do
            local on = (k == key)
            TwIconParts(d.parts, on and C_ACCENT or C_MUT)
            if on then
                Tw(d.ind, {Size = UDim2.new(0, 2, 0, 26), Position = UDim2.new(0, 0, 0.5, -13)}, 0.3, Enum.EasingStyle.Back)
            else
                Tw(d.ind, {Size = UDim2.new(0, 2, 0, 0),  Position = UDim2.new(0, 0, 0.5, 0)},   0.2)
            end
        end

        activeKey = key

        task.delay(0.07, function()
            local pg = tabs[key]
            if pg and activeKey == key then
                local enterX = dir > 0 and 42 or -20
                pg.Position = UDim2.new(0, enterX, 0, 10)
                pg.Visible = true
                Tw(pg, {Position = UDim2.new(0, 14, 0, 10)}, 0.27, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            end
        end)
    end

    local function MakeTab(yOff, key, iconFn)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 44)
        btn.Position = UDim2.new(0, 0, 0, yOff)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.ZIndex = 6
        btn.AutoButtonColor = false
        btn.Parent = sidebar

        local iconParts = iconFn(btn)

        local ind = Instance.new("Frame")
        ind.Size = UDim2.new(0, 2, 0, 0)
        ind.Position = UDim2.new(0, 0, 0.5, 0)
        ind.BackgroundColor3 = C_ACCENT
        ind.BorderSizePixel = 0
        ind.ZIndex = 7
        ind.Parent = btn
        Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 1)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -28, 1, -20)
        page.Position = UDim2.new(0, 14, 0, 10)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = Color3.fromRGB(42, 42, 42)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.Parent = contentArea

        local list = Instance.new("UIListLayout", page)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 6)

        btn.MouseEnter:Connect(function()
            if activeKey ~= key then TwIconParts(iconParts, C_SEC) end
            local btnAbsPos = btn.AbsolutePosition
            local btnAbsSize = btn.AbsoluteSize
            tooltip.Position = UDim2.new(0, SB_W + 6, 0, btnAbsPos.Y - main.AbsolutePosition.Y + (btnAbsSize.Y / 2) - 10)
            ttLbl.Text = TAB_NAMES[key] or key
            tooltip.Size = UDim2.new(0, 0, 0, 20)
            tooltip.Visible = true
            Tw(tooltip, {Size = UDim2.new(0, math.max(58, #(TAB_NAMES[key] or key) * 7 + 14), 0, 20)}, 0.18, Enum.EasingStyle.Back)
        end)
        btn.MouseLeave:Connect(function()
            if activeKey ~= key then TwIconParts(iconParts, C_MUT) end
            Tw(tooltip, {Size = UDim2.new(0, 0, 0, 20)}, 0.12)
            task.delay(0.13, function() tooltip.Visible = false end)
        end)
        btn.MouseButton1Click:Connect(function() SwitchTab(key) end)

        tabs[key] = page
        tabButtons[key] = {parts = iconParts, ind = ind}
        return page
    end

    local function SecHead(parent, text, sub)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, sub and 40 or 28)
        f.BackgroundTransparency = 1
        f.Parent = parent

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 5, 0, 5)
        dot.Position = UDim2.new(0, 0, 0, sub and 9 or 11)
        dot.BackgroundColor3 = C_ACCENT
        dot.BorderSizePixel = 0
        dot.Parent = f
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local line = Instance.new("Frame")
        line.Size = UDim2.new(0.3, -8, 0, 1)
        line.Position = UDim2.new(0, 9, 0, sub and 11 or 13)
        line.BackgroundColor3 = C_BORDER
        line.BorderSizePixel = 0
        line.Parent = f

        local h = Instance.new("TextLabel")
        h.Size = UDim2.new(1, -14, 0, 18)
        h.Position = UDim2.new(0, 12, 0, sub and 4 or 5)
        h.BackgroundTransparency = 1
        h.Text = text
        h.TextColor3 = C_PRI
        h.Font = Enum.Font.GothamBold
        h.TextSize = 13
        h.TextXAlignment = Enum.TextXAlignment.Left
        h.Parent = f

        if sub then
            local s = Instance.new("TextLabel")
            s.Size = UDim2.new(1, -14, 0, 14)
            s.Position = UDim2.new(0, 12, 0, 22)
            s.BackgroundTransparency = 1
            s.Text = sub
            s.TextColor3 = C_MUT
            s.Font = Enum.Font.Gotham
            s.TextSize = 9
            s.TextXAlignment = Enum.TextXAlignment.Left
            s.Parent = f
        end
        return f
    end

    local function Card(parent)
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, 0, 0, 0)
        c.AutomaticSize = Enum.AutomaticSize.Y
        c.BackgroundColor3 = C_CARD
        c.BorderSizePixel = 0
        c.Parent = parent
        Instance.new("UICorner", c).CornerRadius = UDim.new(0, 8)
        local s = Instance.new("UIStroke", c); s.Color = C_BORDER; s.Thickness = 1

        local accentBar = Instance.new("Frame")
        accentBar.Size = UDim2.new(0, 2, 0, 0)
        accentBar.Position = UDim2.new(0, 0, 0, 8)
        accentBar.BackgroundColor3 = C_ACCENT
        accentBar.BackgroundTransparency = 1
        accentBar.BorderSizePixel = 0
        accentBar.ZIndex = 2
        accentBar.Parent = c
        Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 1)

        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 0)
        container.AutomaticSize = Enum.AutomaticSize.Y
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.Parent = c

        local p = Instance.new("UIPadding", container)
        p.PaddingTop = UDim.new(0, 4); p.PaddingBottom = UDim.new(0, 4)
        local l = Instance.new("UIListLayout", container)
        l.SortOrder = Enum.SortOrder.LayoutOrder; l.Padding = UDim.new(0, 0)

        c:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            accentBar.Size = UDim2.new(0, 2, 0, math.max(0, c.AbsoluteSize.Y - 16))
        end)

        c.MouseEnter:Connect(function()
            Tw(s, {Color = Color3.fromRGB(52, 52, 52)}, 0.2)
            Tw(c, {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}, 0.2)
            Tw(accentBar, {BackgroundTransparency = 0}, 0.22)
        end)
        c.MouseLeave:Connect(function()
            Tw(s, {Color = C_BORDER}, 0.3)
            Tw(c, {BackgroundColor3 = C_CARD}, 0.3)
            Tw(accentBar, {BackgroundTransparency = 1}, 0.25)
        end)
        return container
    end

    local function Toggle(parent, label, key, tbl, cb)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundTransparency = 1
        row.ClipsDescendants = true
        row.Parent = parent

        local ripple = Instance.new("Frame")
        ripple.Size = UDim2.new(0, 0, 0, 0)
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)
        ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
        ripple.BackgroundColor3 = C_ACCENT
        ripple.BackgroundTransparency = 1
        ripple.BorderSizePixel = 0
        ripple.ZIndex = 1
        ripple.Parent = row
        Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -56, 1, 0)
        lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = tbl[key] and C_PRI or C_SEC
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 2
        lbl.Parent = row

        local sw = Instance.new("TextButton")
        sw.Size = UDim2.new(0, 32, 0, 16)
        sw.Position = UDim2.new(1, -44, 0.5, -8)
        sw.BackgroundColor3 = tbl[key] and C_ACCENT or Color3.fromRGB(38, 38, 38)
        sw.Text = ""; sw.AutoButtonColor = false; sw.ZIndex = 3
        sw.Parent = row
        Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
        local swStr = Instance.new("UIStroke", sw)
        swStr.Color = tbl[key] and C_ACCENT or Color3.fromRGB(55, 55, 55); swStr.Thickness = 1

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 10, 0, 10)
        dot.Position = tbl[key] and UDim2.new(1, -13, 0.5, -5) or UDim2.new(0, 3, 0.5, -5)
        dot.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
        dot.ZIndex = 4; dot.Parent = sw
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local isOn = tbl[key]
        sw.MouseButton1Click:Connect(function()
            isOn = not isOn; tbl[key] = isOn
            ripple.Size = UDim2.new(0, 0, 0, 0)
            ripple.BackgroundTransparency = 0.82
            Tw(ripple, {Size = UDim2.new(1.6, 0, 3.2, 0), BackgroundTransparency = 1}, 0.45, Enum.EasingStyle.Quint)
            if isOn then
                Tw(sw,    {BackgroundColor3 = C_ACCENT}, 0.18)
                Tw(swStr, {Color = C_ACCENT}, 0.18)
                Tw(dot,   {Position = UDim2.new(1, -13, 0.5, -5), Size = UDim2.new(0, 12, 0, 12)}, 0.22, Enum.EasingStyle.Back)
                task.delay(0.22, function() Tw(dot, {Size = UDim2.new(0, 10, 0, 10)}, 0.15) end)
                Tw(lbl,   {TextColor3 = C_PRI}, 0.15)
            else
                Tw(sw,    {BackgroundColor3 = Color3.fromRGB(38, 38, 38)}, 0.18)
                Tw(swStr, {Color = Color3.fromRGB(55, 55, 55)}, 0.18)
                Tw(dot,   {Position = UDim2.new(0, 3, 0.5, -5), Size = UDim2.new(0, 10, 0, 10)}, 0.18)
                Tw(lbl,   {TextColor3 = C_SEC}, 0.15)
            end
            if cb then cb(isOn) end
        end)
    end

    local function Slider(parent, label, mn, mx, key, tbl)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 46)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, 0, 0, 18)
        lbl.Position = UDim2.new(0, 14, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C_SEC
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0.45, -14, 0, 18)
        valLbl.Position = UDim2.new(0.55, 0, 0, 6)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(tbl[key])
        valLbl.TextColor3 = C_ACCENT
        valLbl.Font = Enum.Font.Code
        valLbl.TextSize = 11
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = frame

        local track = Instance.new("TextButton")
        track.Size = UDim2.new(1, -28, 0, 4)
        track.Position = UDim2.new(0, 14, 0, 33)
        track.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
        track.Text = ""; track.AutoButtonColor = false
        track.Parent = frame
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
        local trackStr = Instance.new("UIStroke", track)
        trackStr.Color = Color3.fromRGB(36, 36, 36); trackStr.Thickness = 1

        local pct = (tbl[key] - mn) / (mx - mn)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = C_ACCENT
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local handle = Instance.new("Frame")
        handle.Size = UDim2.new(0, 10, 0, 10)
        handle.Position = UDim2.new(1, -5, 0.5, -5)
        handle.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        handle.ZIndex = 2; handle.Parent = fill
        Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)
        local hRing = Instance.new("Frame")
        hRing.Size = UDim2.new(0, 4, 0, 4)
        hRing.Position = UDim2.new(0.5, -2, 0.5, -2)
        hRing.BackgroundTransparency = 1
        hRing.ZIndex = 3
        hRing.Parent = handle
        Instance.new("UICorner", hRing).CornerRadius = UDim.new(1, 0)
        local hRingStr = Instance.new("UIStroke", hRing)
        hRingStr.Color = C_ACCENT_DIM; hRingStr.Thickness = 1

        local dragging = false
        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                Tw(handle, {Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -7, 0.5, -7)}, 0.14, Enum.EasingStyle.Back)
                Tw(trackStr, {Color = C_ACCENT_DIM}, 0.18)
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) and dragging then
                dragging = false
                Tw(handle, {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(1, -5, 0.5, -5)}, 0.15)
                Tw(trackStr, {Color = Color3.fromRGB(36, 36, 36)}, 0.2)
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                local p = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                fill.Size = UDim2.new(p, 0, 1, 0)
                local v = math.floor(mn + (mx - mn) * p)
                tbl[key] = v; valLbl.Text = tostring(v)
            end
        end)
    end

    local function SegSel(parent, opts, key, tbl, cb)
        local outer = Instance.new("Frame")
        outer.Size = UDim2.new(1, 0, 0, 44)
        outer.BackgroundTransparency = 1
        outer.Parent = parent

        local wrap = Instance.new("Frame")
        wrap.Size = UDim2.new(1, -28, 0, 24)
        wrap.Position = UDim2.new(0, 14, 0, 10)
        wrap.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        wrap.BorderSizePixel = 0
        wrap.Parent = outer
        Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, 4)
        local wStr = Instance.new("UIStroke", wrap); wStr.Color = C_BORDER; wStr.Thickness = 1

        local btns = {}
        local n = #opts
        local function refresh()
            for _, d in ipairs(btns) do
                local sel = (tbl[key] == d.v)
                Tw(d.bg, {BackgroundTransparency = sel and 0 or 1}, 0.18)
                Tw(d.lbl, {TextColor3 = sel and C_ACCENT or C_SEC}, 0.2)
            end
        end
        for i, opt in ipairs(opts) do
            local bg = Instance.new("TextButton")
            bg.Size = UDim2.new(1/n, 0, 1, 0)
            bg.Position = UDim2.new((i-1)/n, 0, 0, 0)
            bg.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
            bg.BackgroundTransparency = tbl[key] == opt and 0 or 1
            bg.Text = ""; bg.AutoButtonColor = false; bg.Parent = wrap
            Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

            local lbl2 = Instance.new("TextLabel")
            lbl2.Size = UDim2.new(1, 0, 1, 0)
            lbl2.BackgroundTransparency = 1
            lbl2.Text = opt
            lbl2.TextColor3 = tbl[key] == opt and C_ACCENT or C_SEC
            lbl2.Font = Enum.Font.GothamMedium
            lbl2.TextSize = 11
            lbl2.Parent = bg
            table.insert(btns, {bg = bg, lbl = lbl2, v = opt})

            bg.MouseButton1Click:Connect(function()
                tbl[key] = opt; refresh()
                if cb then cb(opt) end
            end)
        end
    end

    local function SizeDropdown(parent, label)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -56, 1, 0)
        lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C_PRI
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local hamburger = Instance.new("TextButton")
        hamburger.Size = UDim2.new(0, 24, 0, 24)
        hamburger.Position = UDim2.new(1, -38, 0.5, -12)
        hamburger.BackgroundTransparency = 1
        hamburger.Text = ""
        hamburger.AutoButtonColor = false
        hamburger.Parent = row

        local lines = {}
        for i = 1, 3 do
            local line = Instance.new("Frame")
            line.Size = UDim2.new(0, 14, 0, 2)
            line.Position = UDim2.new(0.5, -7, 0.5, (i - 2) * 4 - 1)
            line.BackgroundColor3 = C_SEC
            line.BorderSizePixel = 0
            line.Parent = hamburger
            Instance.new("UICorner", line).CornerRadius = UDim.new(1, 0)
            table.insert(lines, line)
        end

        local dropdown = Instance.new("Frame")
        dropdown.Size = UDim2.new(1, 0, 0, 0)
        dropdown.BackgroundTransparency = 1
        dropdown.ClipsDescendants = true
        dropdown.Visible = false
        dropdown.Parent = parent

        local dList = Instance.new("UIListLayout", dropdown)
        dList.SortOrder = Enum.SortOrder.LayoutOrder
        dList.Padding = UDim.new(0, 4)

        local dpPadding = Instance.new("UIPadding", dropdown)
        dpPadding.PaddingLeft = UDim.new(0, 14)
        dpPadding.PaddingRight = UDim.new(0, 14)
        dpPadding.PaddingBottom = UDim.new(0, 6)

        local buttons = {}
        local menuOpen = false

        local function refreshSelection()
            for i, opt in ipairs(sizeData) do
                local btn = buttons[i]
                local isSel = (sizeIdx == i)
                if isSel then
                    Tw(btn.bg, {BackgroundColor3 = Color3.fromRGB(26, 26, 26)}, 0.18)
                    Tw(btn.lbl, {TextColor3 = C_ACCENT}, 0.18)
                    Tw(btn.stroke, {Color = C_ACCENT_DIM}, 0.18)
                else
                    Tw(btn.bg, {BackgroundColor3 = Color3.fromRGB(16, 16, 16)}, 0.18)
                    Tw(btn.lbl, {TextColor3 = C_SEC}, 0.18)
                    Tw(btn.stroke, {Color = C_BORDER}, 0.18)
                end
            end
        end

        for i, s in ipairs(sizeData) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.Parent = dropdown
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            local btnStroke = Instance.new("UIStroke", btn)
            btnStroke.Color = C_BORDER
            btnStroke.Thickness = 1

            local btnLbl = Instance.new("TextLabel")
            btnLbl.Size = UDim2.new(1, 0, 1, 0)
            btnLbl.BackgroundTransparency = 1
            btnLbl.Text = s.n
            btnLbl.TextColor3 = C_SEC
            btnLbl.Font = Enum.Font.GothamMedium
            btnLbl.TextSize = 11
            btnLbl.Parent = btn

            buttons[i] = {bg = btn, lbl = btnLbl, stroke = btnStroke}

            btn.MouseEnter:Connect(function()
                if sizeIdx ~= i then
                    Tw(btnStroke, {Color = C_SEC}, 0.15)
                    Tw(btnLbl, {TextColor3 = C_PRI}, 0.15)
                end
            end)
            btn.MouseLeave:Connect(function()
                if sizeIdx ~= i then
                    Tw(btnStroke, {Color = C_BORDER}, 0.2)
                    Tw(btnLbl, {TextColor3 = C_SEC}, 0.2)
                end
            end)

            btn.MouseButton1Click:Connect(function()
                sizeIdx = i
                local sd = sizeData[sizeIdx]
                CUR_W, CUR_H = sd.w, sd.h
                if isOpen then
                    Tw(main, {Size = UDim2.new(0, CUR_W, 0, CUR_H)}, 0.35, Enum.EasingStyle.Quint)
                end
                refreshSelection()
                menuOpen = false
                Tw(dropdown, {Size = UDim2.new(1, 0, 0, 0)}, 0.25, Enum.EasingStyle.Quint)
                task.delay(0.25, function() if not menuOpen then dropdown.Visible = false end end)
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_SEC}, 0.2) end
            end)
        end

        hamburger.MouseEnter:Connect(function()
            for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_ACCENT}, 0.15) end
        end)
        hamburger.MouseLeave:Connect(function()
            if not menuOpen then
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_SEC}, 0.2) end
            end
        end)

        hamburger.MouseButton1Click:Connect(function()
            menuOpen = not menuOpen
            if menuOpen then
                dropdown.Visible = true
                refreshSelection()
                Tw(dropdown, {Size = UDim2.new(1, 0, 0, 90)}, 0.3, Enum.EasingStyle.Back)
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_ACCENT}, 0.2) end
            else
                Tw(dropdown, {Size = UDim2.new(1, 0, 0, 0)}, 0.25, Enum.EasingStyle.Quint)
                task.delay(0.25, function() if not menuOpen then dropdown.Visible = false end end)
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_SEC}, 0.2) end
            end
        end)
    end

    local function TransparencyDropdown(parent, label)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -56, 1, 0)
        lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C_PRI
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local hamburger = Instance.new("TextButton")
        hamburger.Size = UDim2.new(0, 24, 0, 24)
        hamburger.Position = UDim2.new(1, -38, 0.5, -12)
        hamburger.BackgroundTransparency = 1
        hamburger.Text = ""
        hamburger.AutoButtonColor = false
        hamburger.Parent = row

        local lines = {}
        for i = 1, 3 do
            local line = Instance.new("Frame")
            line.Size = UDim2.new(0, 14, 0, 2)
            line.Position = UDim2.new(0.5, -7, 0.5, (i - 2) * 4 - 1)
            line.BackgroundColor3 = C_SEC
            line.BorderSizePixel = 0
            line.Parent = hamburger
            Instance.new("UICorner", line).CornerRadius = UDim.new(1, 0)
            table.insert(lines, line)
        end

        local dropdown = Instance.new("Frame")
        dropdown.Size = UDim2.new(1, 0, 0, 0)
        dropdown.BackgroundTransparency = 1
        dropdown.ClipsDescendants = true
        dropdown.Visible = false
        dropdown.Parent = parent

        local dList = Instance.new("UIListLayout", dropdown)
        dList.SortOrder = Enum.SortOrder.LayoutOrder
        dList.Padding = UDim.new(0, 4)

        local dpPadding = Instance.new("UIPadding", dropdown)
        dpPadding.PaddingLeft = UDim.new(0, 14)
        dpPadding.PaddingRight = UDim.new(0, 14)
        dpPadding.PaddingBottom = UDim.new(0, 6)

        local buttons = {}
        local menuOpen = false

        local function refreshSelection()
            for i, opt in ipairs(transData) do
                local btn = buttons[i]
                local isSel = (transIdx == i)
                if isSel then
                    Tw(btn.bg, {BackgroundColor3 = Color3.fromRGB(26, 26, 26)}, 0.18)
                    Tw(btn.lbl, {TextColor3 = C_ACCENT}, 0.18)
                    Tw(btn.stroke, {Color = C_ACCENT_DIM}, 0.18)
                else
                    Tw(btn.bg, {BackgroundColor3 = Color3.fromRGB(16, 16, 16)}, 0.18)
                    Tw(btn.lbl, {TextColor3 = C_SEC}, 0.18)
                    Tw(btn.stroke, {Color = C_BORDER}, 0.18)
                end
            end
        end

        local function applyTransparency(tVal)
            if isOpen then
                Tw(main, {BackgroundTransparency = tVal}, 0.3, Enum.EasingStyle.Quint)
                Tw(sidebar, {BackgroundTransparency = tVal}, 0.3, Enum.EasingStyle.Quint)
            end
        end

        for i, s in ipairs(transData) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.Parent = dropdown
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            local btnStroke = Instance.new("UIStroke", btn)
            btnStroke.Color = C_BORDER
            btnStroke.Thickness = 1

            local btnLbl = Instance.new("TextLabel")
            btnLbl.Size = UDim2.new(1, 0, 1, 0)
            btnLbl.BackgroundTransparency = 1
            btnLbl.Text = s.n
            btnLbl.TextColor3 = C_SEC
            btnLbl.Font = Enum.Font.GothamMedium
            btnLbl.TextSize = 11
            btnLbl.Parent = btn

            buttons[i] = {bg = btn, lbl = btnLbl, stroke = btnStroke}

            btn.MouseEnter:Connect(function()
                if transIdx ~= i then
                    Tw(btnStroke, {Color = C_SEC}, 0.15)
                    Tw(btnLbl, {TextColor3 = C_PRI}, 0.15)
                end
            end)
            btn.MouseLeave:Connect(function()
                if transIdx ~= i then
                    Tw(btnStroke, {Color = C_BORDER}, 0.2)
                    Tw(btnLbl, {TextColor3 = C_SEC}, 0.2)
                end
            end)

            btn.MouseButton1Click:Connect(function()
                transIdx = i
                local tVal = transData[transIdx].v
                applyTransparency(tVal)
                refreshSelection()
                menuOpen = false
                Tw(dropdown, {Size = UDim2.new(1, 0, 0, 0)}, 0.25, Enum.EasingStyle.Quint)
                task.delay(0.25, function() if not menuOpen then dropdown.Visible = false end end)
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_SEC}, 0.2) end
            end)
        end

        hamburger.MouseEnter:Connect(function()
            for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_ACCENT}, 0.15) end
        end)
        hamburger.MouseLeave:Connect(function()
            if not menuOpen then
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_SEC}, 0.2) end
            end
        end)

        hamburger.MouseButton1Click:Connect(function()
            menuOpen = not menuOpen
            if menuOpen then
                dropdown.Visible = true
                refreshSelection()
                Tw(dropdown, {Size = UDim2.new(1, 0, 0, 90)}, 0.3, Enum.EasingStyle.Back)
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_ACCENT}, 0.2) end
            else
                Tw(dropdown, {Size = UDim2.new(1, 0, 0, 0)}, 0.25, Enum.EasingStyle.Quint)
                task.delay(0.25, function() if not menuOpen then dropdown.Visible = false end end)
                for _, l in ipairs(lines) do Tw(l, {BackgroundColor3 = C_SEC}, 0.2) end
            end
        end)
    end

    local espPage = MakeTab(58, "ESP", IcoESP)
    SecHead(espPage, "ESP", "Resalta jugadores, equipos, distancia y trazadores.")
    local cESP1 = Card(espPage)
    Toggle(cESP1, "Activar ESP", "Master", ESP)
    local cESP2 = Card(espPage)
    Toggle(cESP2, "Resaltado ESP", "Box",      ESP)
    Toggle(cESP2, "Nombres",       "Names",    ESP)
    Toggle(cESP2, "Distancia",     "Distance", ESP)
    Toggle(cESP2, "Trazadores",    "Tracers",  ESP)

    local aimPage = MakeTab(104, "Aim", IcoAim)
    SecHead(aimPage, "Bloqueo de mira", "Ajusta como seguir y fijar al jugador mas cercano.")
    local cAim1 = Card(aimPage)
    Toggle(cAim1, "Interruptor principal", "Master", Aimlock, function(on)
        if not on then LockedTarget = nil; LockedPart = nil; LastAimRefresh = 0 end
    end)
    SecHead(aimPage, "Modos")
    local cAim2 = Card(aimPage)
    Toggle(cAim2, "Asistencia de mira (clic derecho)", "AimAssist", Aimlock)
    Toggle(cAim2, "Bloqueo de mira",                   "AimLock",   Aimlock, function(on)
        if on then
            LockedTarget, LockedPart = GetClosestPlayerByDistance()
            LastAimRefresh = 0
        else
            LockedTarget = nil
            LockedPart = nil
            LastAimRefresh = 0
            ReleaseAimlockMovement()
        end
    end)
    SecHead(aimPage, "Parte objetivo")
    local cAim3 = Card(aimPage)
    SegSel(cAim3, {"Cabeza", "Torso", "Cercano"}, "Target", Aimlock, function() LockedPart = nil end)
    SecHead(aimPage, "Campo de vision (FOV)")
    local cAim4 = Card(aimPage)
    Slider(cAim4, "Radio", 10, 500, "FOV", Aimlock)
    SecHead(aimPage, "Ajustes")
    local cAim5 = Card(aimPage)
    Slider(cAim5, "Suavidad", 1, 100, "Smoothness", Aimlock)
    Slider(cAim5, "Prediccion",  0, 25,  "Prediction", Aimlock)

    SecHead(aimPage, "Auto Disparo")
    local cAim6 = Card(aimPage)
    Toggle(cAim6, "Auto Disparo", "AutoShoot", Aimlock)
    Toggle(cAim6, "Auto Disparo (boton)", "AutoShootBtn", Aimlock, function(on)
        if floatBtn then floatBtn.Visible = on end
    end)


    local pntPage = MakeTab(150, "Ptr", IcoPtr)
    SecHead(pntPage, "Configuracion del puntero", "Personaliza el cursor que ves al jugar.")
    local cPnt1 = Card(pntPage)
    Toggle(cPnt1, "Cursor de huella furry", "Paw", Pointer)

    local configPage = MakeTab(196, "Config", IcoConfig)
    SecHead(configPage, "Ajustes de Interfaz", "Personaliza la apariencia y el tamaño de la ventana.")
    local cConfig = Card(configPage)
    SizeDropdown(cConfig, "Tamaño de Ventana")
    TransparencyDropdown(cConfig, "Transparencia de Ventana")

    local credPage = MakeTab(242, "Creditos", IcoCreditos)
    SecHead(credPage, "Creditos", "Informacion del proyecto y sus responsables.")
    local cCred = Card(credPage)
    local creditos = {
        {"Desarrollador", "@TheRealBanHammer"},
        {"Dueño", "@LokyChips"},
        {"Versión", "1.1"}
    }
    for _, dato in ipairs(creditos) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundTransparency = 1
        row.Parent = cCred

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.42, -10, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = dato[1]
        label.TextColor3 = C_SEC
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(0.58, -18, 1, 0)
        value.Position = UDim2.new(0.42, 0, 0, 0)
        value.BackgroundTransparency = 1
        value.Text = dato[2]
        value.TextColor3 = C_PRI
        value.Font = Enum.Font.GothamBold
        value.TextSize = 12
        value.TextXAlignment = Enum.TextXAlignment.Right
        value.Parent = row
    end

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 42, 0, 42)
    toggleBtn.Position = UDim2.new(0.85, -21, 0.1, -21)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 100
    toggleBtn.Parent = gui
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)
    local tbStr = Instance.new("UIStroke", toggleBtn)
    tbStr.Color = C_BORDER; tbStr.Thickness = 1

    local tbLogo = Instance.new("ImageLabel")
    tbLogo.Size = UDim2.new(0, 30, 0, 30)
    tbLogo.Position = UDim2.new(0.5, -15, 0.5, -15)
    tbLogo.BackgroundTransparency = 1
    tbLogo.Image = LOGO_ID
    tbLogo.ZIndex = 101
    tbLogo.Parent = toggleBtn
    Instance.new("UICorner", tbLogo).CornerRadius = UDim.new(0, 5)

    Drag(toggleBtn, toggleBtn)

    toggleBtn.MouseEnter:Connect(function()
        Tw(toggleBtn, {BackgroundColor3 = Color3.fromRGB(18, 18, 18)}, 0.15)
        Tw(tbStr, {Color = C_ACCENT}, 0.2)
        Tw(tbLogo, {ImageTransparency = 0.08, Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0.5, -14, 0.5, -14)}, 0.15)
    end)
    toggleBtn.MouseLeave:Connect(function()
        Tw(toggleBtn, {BackgroundColor3 = Color3.fromRGB(10, 10, 10)}, 0.2)
        Tw(tbLogo, {ImageTransparency = 0, Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.5, -15, 0.5, -15)}, 0.2)
        if not main.Visible then Tw(tbStr, {Color = C_BORDER}, 0.25) end
    end)

    local function Open()
        isOpen = true
        main.Size = UDim2.new(0, CUR_W * 0.93, 0, 0)
        local tVal = transData[transIdx].v
        main.BackgroundTransparency = math.clamp(tVal + 0.2, 0, 1)
        sidebar.BackgroundTransparency = math.clamp(tVal + 0.2, 0, 1)
        main.Visible = true
        Tw(main, {Size = UDim2.new(0, CUR_W, 0, CUR_H), BackgroundTransparency = tVal}, 0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Tw(sidebar, {BackgroundTransparency = tVal}, 0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        mainBorder.Color = C_ACCENT
        Tw(mainBorder, {Color = C_BORDER}, 0.7)
        Tw(tbStr, {Color = C_ACCENT}, 0.2)
        accentLine.Size = UDim2.new(0, 0, 0, 1)
        task.delay(0.15, function()
            Tw(accentLine, {Size = UDim2.new(1, -SB_W, 0, 1)}, 0.5, Enum.EasingStyle.Quint)
        end)
        tbLogo.Size = UDim2.new(0, 20, 0, 20)
        tbLogo.Position = UDim2.new(0.5, -10, 0.5, -10)
        Tw(tbLogo, {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.5, -15, 0.5, -15)}, 0.32, Enum.EasingStyle.Back)
        titleLbl.TextTransparency = 1; subLbl.TextTransparency = 1
        task.delay(0.14, function()
            Tw(titleLbl, {TextTransparency = 0}, 0.25)
            task.delay(0.07, function() Tw(subLbl, {TextTransparency = 0}, 0.2) end)
        end)
    end

    local function Close()
        isOpen = false
        Tw(titleLbl, {TextTransparency = 1}, 0.12)
        Tw(subLbl,   {TextTransparency = 1}, 0.1)
        Tw(accentLine, {Size = UDim2.new(0, 0, 0, 1)}, 0.18)
        local tVal = transData[transIdx].v
        local tw = Tw(main, {Size = UDim2.new(0, CUR_W * 0.95, 0, 0), BackgroundTransparency = math.clamp(tVal + 0.2, 0, 1)}, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Tw(sidebar, {BackgroundTransparency = math.clamp(tVal + 0.2, 0, 1)}, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tw.Completed:Connect(function()
            if not isOpen then
                main.Visible = false
                main.BackgroundTransparency = tVal
                sidebar.BackgroundTransparency = tVal
            end
        end)
        Tw(tbStr, {Color = C_BORDER}, 0.3)
        Tw(tbLogo, {Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0.5, -11, 0.5, -11)}, 0.15)
        task.delay(0.15, function()
            Tw(tbLogo, {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.5, -15, 0.5, -15)}, 0.22, Enum.EasingStyle.Back)
        end)
    end

    toggleBtn.MouseButton1Click:Connect(function()
        if isOpen then Close() else Open() end
    end)

    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or UserInputService:GetFocusedTextBox() then return end
        if inp.KeyCode == Enum.KeyCode.LeftControl or inp.KeyCode == Enum.KeyCode.RightControl then
            if isOpen then Close() else Open() end
        end
    end)

    SwitchTab("ESP")
end

CreateUI()
