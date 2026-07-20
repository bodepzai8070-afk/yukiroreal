-- ============================================
-- CAMERA LOCK-ON SYSTEM V2 - MOBILE FIX
-- ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ===== CẤU HÌNH =====
local CONFIG = {
    FOV_RADIUS = 35,
    TARGET_PART = "Head",
    UNLOCK_SENSITIVITY = 0.15,  -- Ngưỡng vuốt để unlock (tính bằng radian)
    SMOOTH_FACTOR = 0.35        -- Độ mượt khi xoay (0->1, càng thấp càng mượt)
}

-- ===== STATE =====
local AimbotEnabled = true
local CurrentTarget = nil
local LastTouchDelta = Vector2.new(0, 0)
local IsTouching = false

-- ===== DRAWING =====
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 0)
FOVCircle.Filled = false
FOVCircle.Radius = CONFIG.FOV_RADIUS
FOVCircle.Visible = true
FOVCircle.Transparency = 1

-- ===== HÀM TIỆN: CHUYỂN CFAME -> YAW/PITCH =====
local function getYawPitch(cframe)
    local fwd = cframe.LookVector
    local yaw = math.atan2(-fwd.X, -fwd.Z)
    local pitch = math.asin(fwd.Y)
    return yaw, pitch
end

-- ===== TÌM MỤC TIÊU TỐT NHẤT =====
local function getClosestPlayer()
    local best = nil
    local bestDist = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local head = char:FindFirstChild(CONFIG.TARGET_PART)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not head or not hum or hum.Health <= 0 then continue end
        
        -- Raycast line-of-sight
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character, char}
        local origin = Camera.CFrame.Position
        local dir = head.Position - origin
        local result = workspace:Raycast(origin, dir, params)
        if result then continue end
        
        -- Check on-screen & FOV
        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then continue end
        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist2D <= CONFIG.FOV_RADIUS and dist2D < bestDist then
            best = plr
            bestDist = dist2D
        end
    end
    return best
end

-- ===== KIỂM TRA UNLOCK BẰNG VUỐT MÀN HÌNH =====
local function checkUnlockBySwipe()
    if not CurrentTarget then return false end
    local char = CurrentTarget.Character
    if not char then return true end  -- target died
    local head = char:FindFirstChild(CONFIG.TARGET_PART)
    if not head then return true end
    
    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then return true end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    
    -- Nếu target ra khỏi FOV + thêm ngưỡng vuốt
    if dist > CONFIG.FOV_RADIUS * 1.5 then
        return true
    end
    
    -- Nếu người chơi vuốt mạnh (dựa trên delta touch)
    if IsTouching and LastTouchDelta.Magnitude > 25 then  -- pixel
        return true
    end
    return false
end

-- ===== CẬP NHẬT CAMERA - KHẮC PHỤC LỖI FIRST-PERSON =====
local function updateCamera(targetPos)
    local camPos = Camera.CFrame.Position
    local targetYaw, targetPitch = getYawPitch(CFrame.lookAt(camPos, targetPos))
    
    -- Lấy góc hiện tại của camera
    local currentYaw, currentPitch = getYawPitch(Camera.CFrame)
    
    -- Nội suy góc để xoay mượt, tránh giật
    local newYaw = currentYaw + (targetYaw - currentYaw) * CONFIG.SMOOTH_FACTOR
    local newPitch = currentPitch + (targetPitch - currentPitch) * CONFIG.SMOOTH_FACTOR
    
    -- Ép buộc CFrame nhưng KHÔNG dùng phép nhân tuyệt đối gây override
    -- Dùng CFrame.Angles cộng dồn tương đối để không bị touch override
    local yawDiff = newYaw - currentYaw
    local pitchDiff = newPitch - currentPitch
    
    -- Áp dụng xoay tương đối quanh camera position
    Camera.CFrame = Camera.CFrame * CFrame.Angles(0, -yawDiff, 0) * CFrame.Angles(pitchDiff, 0, 0)
end

-- ===== VÒNG LẶP CHÍNH =====
local aimConnection = nil
local function startAimbot()
    if aimConnection then return end
    aimConnection = RunService.RenderStepped:Connect(function()
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Position = center
        
        if not AimbotEnabled then return end
        
        -- Tìm target mới nếu chưa có hoặc target cũ bị unlock
        if not CurrentTarget or checkUnlockBySwipe() then
            CurrentTarget = getClosestPlayer()
            if not CurrentTarget then
                -- Không có target -> reset touch delta
                LastTouchDelta = Vector2.new(0, 0)
                return
            end
        end
        
        -- Lấy vị trí đầu target
        local head = CurrentTarget.Character and CurrentTarget.Character:FindFirstChild(CONFIG.TARGET_PART)
        if not head then
            CurrentTarget = nil
            return
        end
        
        -- Cập nhật camera
        updateCamera(head.Position)
    end)
end

local function stopAimbot()
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
    FOVCircle.Visible = false
    CurrentTarget = nil
end

-- ===== THEO DÕI TOUCH ĐỂ PHÁT HIỆN VUỐT =====
UserInputService.TouchStarted:Connect(function(input, processed)
    if processed then return end
    IsTouching = true
    LastTouchDelta = Vector2.new(0, 0)
end)

UserInputService.TouchMoved:Connect(function(input, processed)
    if processed then return end
    if IsTouching then
        LastTouchDelta = input.Position - input.PreviousPosition
    end
end)

UserInputService.TouchEnded:Connect(function(input, processed)
    IsTouching = false
    LastTouchDelta = Vector2.new(0, 0)
end)

-- ===== GUI TOGGLE BUTTON (DRAGGABLE) =====
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
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
ToggleButton.Position = UDim2.new(0.15, 0, 0.25, 0)
ToggleButton.Size = UDim2.new(0, 75, 0, 35)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "TRACK: ON"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14
ToggleButton.Active = true
ToggleButton.AutoButtonColor = false

UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

-- Drag logic
local dragData = {dragging = false, dragInput = nil, dragStart = nil, startPos = nil}
local function updateDrag(input)
    local delta = input.Position - dragData.dragStart
    ToggleButton.Position = UDim2.new(
        dragData.startPos.X.Scale,
        dragData.startPos.X.Offset + delta.X,
        dragData.startPos.Y.Scale,
        dragData.startPos.Y.Offset + delta.Y
    )
end

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragData.dragging = true
        dragData.dragStart = input.Position
        dragData.startPos = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragData.dragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragData.dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragData.dragInput and dragData.dragging then
        updateDrag(input)
    end
end)

-- Toggle
ToggleButton.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    if AimbotEnabled then
        ToggleButton.Text = "TRACK: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        FOVCircle.Visible = true
        CurrentTarget = nil  -- reset target để quét lại
        if not aimConnection then startAimbot() end
    else
        ToggleButton.Text = "TRACK: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopAimbot()
    end
end)

-- ===== KHỞI ĐỘNG =====
startAimbot()

-- ===== DỌN DẸP KHI THOÁT =====
game:BindToClose(function()
    stopAimbot()
    if FOVCircle then FOVCircle:Remove() end
end)
