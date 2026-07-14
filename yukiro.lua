-- Đợi game tải hoàn toàn
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Cấu hình
local AimbotEnabled = true
local FOV_RADIUS = 35
local TARGET_PART = "Head"
local SMOOTH_FACTOR = 0.25  -- Độ mượt xoay (0.1-0.5)
local UNLOCK_SWIPE_THRESHOLD = 35 -- pixel vuốt để unlock

-- Drawing objects
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(0, 0, 0)  -- BLACK
FOVCircle.Filled = false
FOVCircle.Radius = FOV_RADIUS
FOVCircle.Visible = true
FOVCircle.Transparency = 0.8

-- ESP: Text cho tên và khoảng cách
local ESPLabels = {}
local function createESPLabel(player)
    if ESPLabels[player] then return end
    local label = Drawing.new("Text")
    label.Size = 16
    label.Color = Color3.fromRGB(255, 255, 255)
    label.Center = true
    label.Outline = true
    label.OutlineColor = Color3.fromRGB(0, 0, 0)
    label.Visible = false
    ESPLabels[player] = label
end

local function updateESP()
    local camPos = Camera.CFrame.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local label = ESPLabels[player]
        if not label then createESPLabel(player) end
        
        local char = player.Character
        if char and char:FindFirstChild(TARGET_PART) and char:FindFirstChildOfClass("Humanoid") then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid.Health > 0 then
                local head = char[TARGET_PART]
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (camPos - head.Position).Magnitude
                    label.Text = string.format("%s [%.1fm]", player.Name, dist)
                    label.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
                    label.Visible = true
                    label.Color = (dist < 30) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
                else
                    label.Visible = false
                end
            else
                label.Visible = false
            end
        else
            label.Visible = false
        end
    end
end

-- Hàm tìm mục tiêu (tối ưu)
local function getClosestPlayer()
    local closest = nil
    local shortestDist = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local camPos = Camera.CFrame.Position
    local ignoreList = {LocalPlayer.Character}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local head = char:FindFirstChild(TARGET_PART)
        if not head then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        -- Line-of-sight check
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character, char}
        local ray = workspace:Raycast(camPos, head.Position - camPos, params)
        if ray then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then continue end

        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if dist2D <= FOV_RADIUS and dist2D < shortestDist then
            closest = player
            shortestDist = dist2D
        end
    end
    return closest
end

-- Biến theo dõi vuốt để unlock
local lastSwipeDelta = 0
local currentTarget = nil

-- Vòng lặp RenderStepped – SỬA LỖI CAMERA FIRST-PERSON
local aimConnection
local function startAimbot()
    aimConnection = RunService.RenderStepped:Connect(function()
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Position = screenCenter

        -- Cập nhật ESP
        updateESP()

        if not AimbotEnabled then return end

        local targetPlayer = getClosestPlayer()
        currentTarget = targetPlayer

        if targetPlayer and targetPlayer.Character then
            local targetHead = targetPlayer.Character:FindFirstChild(TARGET_PART)
            if targetHead then
                local targetPos = targetHead.Position
                local camPos = Camera.CFrame.Position
                
                -- Cách ép camera xoay mượt KHÔNG bị override bởi touch
                local lookAtCF = CFrame.lookAt(camPos, targetPos)
                -- Nội suy góc để xoay mượt
                local currentCF = Camera.CFrame
                local targetCF = lookAtCF
                -- Chỉ xoay quanh Y và X để tránh lật
                local currentAngles = currentCF:ToEulerAnglesYXZ()
                local targetAngles = targetCF:ToEulerAnglesYXZ()
                
                -- Lấy góc chênh lệch, áp dụng nội suy (smooth)
                local deltaY = targetAngles - currentAngles
                -- Chuẩn hóa góc để tránh xoay vòng
                deltaY = (deltaY + math.pi) % (2 * math.pi) - math.pi
                
                local newY = currentAngles + deltaY * SMOOTH_FACTOR
                local newX = currentAngles + (targetAngles - currentAngles) * SMOOTH_FACTOR
                
                -- Áp dụng CFrame mới
                Camera.CFrame = CFrame.new(camPos) * CFrame.Angles(newX, newY, 0)
            end
        end
    end)
end

-- Phát hiện vuốt mạnh để unlock
UserInputService.TouchEnabled = true
UserInputService.TouchStarted:Connect(function(input, processed)
    if processed then return end
    lastSwipeDelta = 0
end)

UserInputService.TouchMoved:Connect(function(input, processed)
    if processed or not currentTarget then return end
    local delta = input.Delta.Magnitude
    lastSwipeDelta = lastSwipeDelta + delta
    if lastSwipeDelta > UNLOCK_SWIPE_THRESHOLD then
        -- Unlock: reset mục tiêu
        currentTarget = nil
        lastSwipeDelta = 0
    end
end)

UserInputService.TouchEnded:Connect(function()
    lastSwipeDelta = 0
end)

local function stopAimbot()
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
    FOVCircle.Visible = false
    -- Ẩn tất cả ESP
    for _, label in pairs(ESPLabels) do
        label.Visible = false
    end
end

startAimbot()

-- Tạo GUI Toggle (Draggable)
if PlayerGui:FindFirstChild("MobileAimbotGui") then
    PlayerGui.MobileAimbotGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
local ToggleButton = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")

ScreenGui.Name = "MobileAimbotGui"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false

ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)  -- BLACK
ToggleButton.Position = UDim2.new(0.15, 0, 0.25, 0)
ToggleButton.Size = UDim2.new(0, 85, 0, 40)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "AIM: ON"
ToggleButton.TextColor3 = Color3.fromRGB(0, 255, 0)
ToggleButton.TextSize = 16
ToggleButton.Active = true

UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = ToggleButton

-- Kéo thả
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

ToggleButton.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    if AimbotEnabled then
        ToggleButton.Text = "AIM: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        ToggleButton.TextColor3 = Color3.fromRGB(0, 255, 0)
        FOVCircle.Visible = true
        if not aimConnection then startAimbot() end
    else
        ToggleButton.Text = "AIM: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        ToggleButton.TextColor3 = Color3.fromRGB(255, 0, 0)
        stopAimbot()
    end
end)

-- Khởi tạo ESP cho các player hiện có
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESPLabel(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createESPLabel(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPLabels[player] then
        ESPLabels[player]:Remove()
        ESPLabels[player] = nil
    end
end)
