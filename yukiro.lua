-- Lua script Roblox (LocalScript) - Cải thiện Aimbot
-- Tăng độ mượt, dự đoán di chuyển, ưu tiên mục tiêu gần tâm FOV nhất

if _G.MegaScriptExecuted then return end
_G.MegaScriptExecuted = true

-- ====== THÔNG BÁO KHỞI ĐỘNG ======
local function ShowNotification()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NotificationGUI"
    ScreenGui.ResetOnSpawn = false
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if ScreenGui.Parent == nil then
        ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 280, 0, 60)
    Frame.Position = UDim2.new(0.5, -140, 0.1, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    Frame.BackgroundTransparency = 0.15
    Frame.ZIndex = 9999
    Frame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = Frame

    local Glow = Instance.new("UIGradient")
    Glow.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 200, 100)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 0))
    })
    Glow.Rotation = 45
    Glow.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = "✅ ON SCRIPT ✅"
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.Font = Enum.Font.SourceSansBold
    Label.TextSize = 24
    Label.TextScaled = true
    Label.ZIndex = 10000
    Label.Parent = Frame

    local TweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
    local scaleUp = TweenService:Create(Frame, tweenInfo, {Size = UDim2.new(0, 300, 0, 70)})
    local scaleDown = TweenService:Create(Frame, tweenInfo, {Size = UDim2.new(0, 280, 0, 60)})
    scaleUp:Play()
    scaleUp.Completed:Connect(function()
        task.wait(0.3)
        scaleDown:Play()
    end)

    task.delay(3.5, function()
        local fadeOut = TweenService:Create(Frame, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {BackgroundTransparency = 1})
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            ScreenGui:Destroy()
        end)
    end)

    task.spawn(function()
        local blink = true
        for i = 1, 6 do
            task.wait(0.2)
            Label.TextColor3 = blink and Color3.fromRGB(255, 255, 100) or Color3.fromRGB(255, 255, 255)
            blink = not blink
        end
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
end

task.spawn(ShowNotification)

-- ====== PHẦN 1: FPS BOOSTER (CHỈ GIẢM ĐỒ HỌA) ======
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local ImportantNames = {
    "Baseplate", "SpawnLocation", "Floor", "Ground", "Sàn",
    "Checkpoint", "Teleport"
}
local function IsImportant(part)
    if not part then return false end
    local name = part.Name:lower()
    for _, v in ipairs(ImportantNames) do
        if name == v:lower() then return true end
    end
    if name:find("floor") or name:find("plate") then return true end
    return false
end

local function SmartOptimize(obj)
    if not obj then return end
    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
        if not IsImportant(obj) then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
            obj.Reflectance = 0
            if obj:IsA("MeshPart") and obj.TextureID ~= "" then
                obj.TextureID = ""
            end
        end
    end
    if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or
       obj:IsA("Sparkles") or obj:IsA("Trail") or obj:IsA("Beam") then
        obj:Destroy()
        return
    end
    if (obj:IsA("Decal") or obj:IsA("Texture")) then
        local parent = obj.Parent
        if parent and not IsImportant(parent) then
            obj:Destroy()
        end
    end
end

local function ScanMap()
    local allParts = Workspace:GetDescendants()
    local count = 0
    for _, obj in ipairs(allParts) do
        count = count + 1
        SmartOptimize(obj)
        if count % 150 == 0 then
            RunService.Heartbeat:Wait()
        end
    end
end
task.spawn(ScanMap)

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
        if obj == Character then return end
    end
    SmartOptimize(obj)
end)

Lighting.GlobalShadows = false
Lighting.Brightness = 1
Lighting.ClockTime = 12
for _, child in ipairs(Lighting:GetChildren()) do
    if child:IsA("BlurEffect") or child:IsA("SunRaysEffect") or
       child:IsA("BloomEffect") or child:IsA("DepthOfFieldEffect") then
        child:Destroy()
    end
end

pcall(function()
    game:GetService("UserSettings"):GetService("UserGameSettings").GraphicsQualityLevel = Enum.QualityLevel.Level01
end)

local function FreeMemory()
    collectgarbage("collect")
end

task.spawn(function()
    while true do
        task.wait(30)
        pcall(FreeMemory)
    end
end)

-- ====== PHẦN 2: HITBOX EXTENDER ======
local HitboxSize = Vector3.new(6, 6, 6)
local IgnoredPlayers = {}

local function ExpandHitbox(player)
    if player == LocalPlayer then return end
    if IgnoredPlayers[player] then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.Size = HitboxSize
    hrp.CanCollide = false
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        task.spawn(ExpandHitbox, p)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        ExpandHitbox(player)
    end)
end)

task.spawn(function()
    while true do
        task.wait(5)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                pcall(ExpandHitbox, p)
            end
        end
    end
end)

-- ====== PHẦN 3: ESP + AIMBOT CẢI THIỆN ======
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local CONFIG = {
    FOV_RADIUS = 40,
    TARGET_PART = "Head",
    SMOOTHNESS = 0.35,           -- Tăng độ mượt (0.35 thay vì 0.22)
    PREDICTION_FACTOR = 0.3,     -- Dự đoán di chuyển 30%
    SWIPE_THRESHOLD = 80,
    ESP_ENABLED = true,
    ESP_THICKNESS = 2,
    ESP_MAX_DISTANCE = 800,
    ESP_COLOR_TEAM = Color3.fromRGB(0, 255, 0),
    ESP_COLOR_ENEMY = Color3.fromRGB(255, 0, 0),
}

local SystemState = {
    AimbotEnabled = true,
}

local CurrentTarget = nil
local ESPObjects = {}
local DrawingSupported = pcall(function() return Drawing.new("Circle") end)

local FOVCircle = nil
if DrawingSupported then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1.8
    FOVCircle.Color = Color3.fromRGB(0, 255, 100)
    FOVCircle.Filled = false
    FOVCircle.Radius = CONFIG.FOV_RADIUS
    FOVCircle.Transparency = 0.7
    FOVCircle.Visible = true
end

local function CreateESP(player)
    if not DrawingSupported then return end
    if ESPObjects[player] then return end
    local line = Drawing.new("Line")
    line.Thickness = CONFIG.ESP_THICKNESS
    line.Transparency = 0.85
    line.Visible = false
    ESPObjects[player] = line
end

local function UpdateESP()
    if not DrawingSupported then return end
    if not CONFIG.ESP_ENABLED then
        for _, v in pairs(ESPObjects) do if v then v.Visible = false end end
        return
    end

    local myTeam = LocalPlayer.Team
    local camPos = Camera.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        CreateESP(player)

        local char = player.Character
        if not char then
            if ESPObjects[player] then ESPObjects[player].Visible = false end
            continue
        end

        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if not head or not root or not hum or hum.Health <= 0 then
            if ESPObjects[player] then ESPObjects[player].Visible = false end
            continue
        end

        local dist = (head.Position - camPos).Magnitude
        if dist > CONFIG.ESP_MAX_DISTANCE then
            if ESPObjects[player] then ESPObjects[player].Visible = false end
            continue
        end

        local headPos, headOn = Camera:WorldToViewportPoint(head.Position)
        local rootPos, rootOn = Camera:WorldToViewportPoint(root.Position)

        if not headOn or not rootOn then
            if ESPObjects[player] then ESPObjects[player].Visible = false end
            continue
        end

        local line = ESPObjects[player]
        line.From = Vector2.new(headPos.X, headPos.Y)
        line.To = Vector2.new(rootPos.X, rootPos.Y + 15)
        line.Visible = true

        if myTeam and player.Team and myTeam == player.Team then
            line.Color = CONFIG.ESP_COLOR_TEAM
        else
            line.Color = CONFIG.ESP_COLOR_ENEMY
        end
    end
end

local function IsSameTeam(player)
    return LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
end

-- HÀM TÍNH KHOẢNG CÁCH TỪ ĐIỂM ĐẾN TÂM FOV (CÓ TRỌNG SỐ)
local function GetScore(targetPart, targetVelocity)
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return math.huge end
    
    local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    if distFromCenter > CONFIG.FOV_RADIUS then return math.huge end
    
    -- Dự đoán vị trí dựa trên vận tốc (nếu có)
    local predictedPos = targetPart.Position
    if targetVelocity and targetVelocity.Magnitude > 1 then
        predictedPos = predictedPos + (targetVelocity * CONFIG.PREDICTION_FACTOR)
        local predScreen, predOn = Camera:WorldToViewportPoint(predictedPos)
        if predOn then
            local predDist = (Vector2.new(predScreen.X, predScreen.Y) - center).Magnitude
            -- Kết hợp khoảng cách hiện tại và dự đoán (ưu tiên gần tâm hơn)
            return distFromCenter * 0.6 + predDist * 0.4
        end
    end
    
    return distFromCenter
end

local function GetClosestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local camPos = Camera.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if IsSameTeam(player) then continue end

        local char = player.Character
        if not char then continue end

        local targetPart = char:FindFirstChild(CONFIG.TARGET_PART)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not targetPart or not hum or hum.Health <= 0 then continue end

        -- Lấy vận tốc của nhân vật (nếu có)
        local velocity = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.AssemblyLinearVelocity or Vector3.new(0,0,0)

        local score = GetScore(targetPart, velocity)
        if score == math.huge then continue end

        -- Kiểm tra vật cản
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {LocalPlayer.Character or {}, char}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ray = workspace:Raycast(camPos, targetPart.Position - camPos, params)

        if not ray and score < bestScore then
            bestTarget = player
            bestScore = score
        end
    end
    return bestTarget
end

local function UpdateCamera(targetPos)
    if not targetPos then return end
    local current = Camera.CFrame
    local target = CFrame.lookAt(current.Position, targetPos)
    
    -- Sử dụng SMOOTHNESS cao hơn để mượt mà hơn
    local smoothFactor = CONFIG.SMOOTHNESS
    -- Nếu target ở xa tâm, tăng tốc độ bám
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
    if onScreen then
        local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if distFromCenter > CONFIG.FOV_RADIUS * 0.7 then
            smoothFactor = math.min(smoothFactor * 1.5, 0.6) -- Bám nhanh hơn khi target ở rìa FOV
        end
    end
    
    Camera.CFrame = current:Lerp(target, smoothFactor)
end

local lastTouchPos = nil
UserInputService.TouchStarted:Connect(function(touch)
    lastTouchPos = touch.Position
end)

UserInputService.TouchEnded:Connect(function(touch)
    if not lastTouchPos or not CurrentTarget then return end
    if (touch.Position - lastTouchPos).Magnitude >= CONFIG.SWIPE_THRESHOLD then
        CurrentTarget = nil
    end
    lastTouchPos = nil
end)

local function MainUpdate()
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Visible = SystemState.AimbotEnabled and DrawingSupported
    end

    UpdateESP()

    if not SystemState.AimbotEnabled then return end

    if not CurrentTarget then
        CurrentTarget = GetClosestTarget()
    else
        local char = CurrentTarget.Character
        if not char then
            CurrentTarget = nil
            return
        end
        local targetPart = char:FindFirstChild(CONFIG.TARGET_PART)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not targetPart or not hum or hum.Health <= 0 or IsSameTeam(CurrentTarget) then
            CurrentTarget = nil
            return
        end
        
        -- Kiểm tra target có còn trong FOV không
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then
            CurrentTarget = nil
            return
        end
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist > CONFIG.FOV_RADIUS then
            CurrentTarget = nil
            return
        end
        
        -- Kiểm tra vật cản
        local camPos = Camera.CFrame.Position
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {LocalPlayer.Character or {}, char}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ray = workspace:Raycast(camPos, targetPart.Position - camPos, params)
        if ray then
            CurrentTarget = nil
            return
        end
    end

    if CurrentTarget then
        local char = CurrentTarget.Character
        if not char then CurrentTarget = nil return end
        local targetPart = char:FindFirstChild(CONFIG.TARGET_PART)
        if targetPart then
            -- Dự đoán vị trí dựa trên vận tốc để aim trước
            local velocity = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local predictedPos = targetPart.Position
            if velocity.Magnitude > 1 then
                predictedPos = predictedPos + (velocity * CONFIG.PREDICTION_FACTOR)
            end
            UpdateCamera(predictedPos)
        end
    end
end

local MainConnection = RunService.RenderStepped:Connect(MainUpdate)

Players.PlayerRemoving:Connect(function(plr)
    if ESPObjects[plr] then
        if type(ESPObjects[plr].Remove) == "function" then
            ESPObjects[plr]:Remove()
        end
        ESPObjects[plr] = nil
    end
end)

print("✅ Script đã kích hoạt: ESP + Aimbot cải thiện (dự đoán di chuyển, độ mượt cao) + FPS Booster + Hitbox Extender ✅")
