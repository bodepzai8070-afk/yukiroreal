-- [[ Smart FPS Booster + Hitbox Extender + Aimbot 120° FOV (Delta Executor) ]]
-- Quét góc 120 độ, ưu tiên mục tiêu gần nhất trong tầm

if _G.SmartFPSBoosterExecuted then return end
_G.SmartFPSBoosterExecuted = true

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Camera = Workspace.CurrentCamera

-- Danh sách bảo vệ Map
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

-- Tối ưu hóa thông minh
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

task.spawn(function()
    local allParts = Workspace:GetDescendants()
    local count = 0
    for _, obj in ipairs(allParts) do
        count = count + 1
        SmartOptimize(obj)
        if count % 150 == 0 then RunService.Heartbeat:Wait() end
    end
end)

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
        if obj == Character then return end
    end
    SmartOptimize(obj)
end)

-- Lighting
Lighting.GlobalShadows = false
Lighting.Brightness = 1
Lighting.ClockTime = 12
for _, child in ipairs(Lighting:GetChildren()) do
    if child:IsA("BlurEffect") or child:IsA("SunRaysEffect") or
       child:IsA("BloomEffect") or child:IsA("DepthOfFieldEffect") then
        child:Destroy()
    end
end

-- ===== HITBOX EXPANDER =====
local HitboxSize = Vector3.new(8, 8, 8)
local function ExpandHitbox(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.Size = HitboxSize
    hrp.CanCollide = false
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then task.spawn(ExpandHitbox, p) end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        ExpandHitbox(player)
    end)
end)

task.spawn(function()
    while true do
        task.wait(5)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then pcall(ExpandHitbox, p) end
        end
    end
end)

-- ===== AIMBOT 120° FOV - GHIM HEAD =====
local AimbotEnabled = true
local TargetDistance = 9999
local FOV = 120  -- ĐÃ ĐỔI TỪ 30 -> 120 ĐỘ
local Smoothness = 0

local function GetHeadPosition(player)
    local char = player.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head then return head.Position end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position + Vector3.new(0, 1.5, 0) end
    return nil
end

local function GetClosestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local myRoot = Character and Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local myPos = myRoot.Position
    local cameraCF = Camera.CFrame
    local cameraPos = cameraCF.Position
    local cameraDir = cameraCF.LookVector

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local headPos = GetHeadPosition(player)
            if headPos then
                local dist = (myPos - headPos).Magnitude
                if dist > TargetDistance then continue end
                local dirToTarget = (headPos - cameraPos).Unit
                local dot = cameraDir:Dot(dirToTarget)
                local angle = math.deg(math.acos(dot))
                if angle > FOV then continue end  -- Chỉ nhận trong 120°
                local score = angle * 0.5 + dist * 0.001
                if score < bestScore then
                    bestScore = score
                    bestTarget = player
                end
            end
        end
    end
    return bestTarget
end

local function AimAt(targetPlayer)
    if not targetPlayer then return end
    local headPos = GetHeadPosition(targetPlayer)
    if not headPos then return end
    local newCF = CFrame.new(Camera.CFrame.Position, headPos)
    if Smoothness > 0 then
        Camera.CFrame = Camera.CFrame:Lerp(newCF, 0.15)
    else
        Camera.CFrame = newCF
    end
end

local function Shoot()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

RunService.RenderStepped:Connect(function()
    if not AimbotEnabled then return end
    if not Character or not Character.Parent then return end
    local target = GetClosestTarget()
    if target then
        AimAt(target)
        Shoot()
    end
end)

-- Bật/tắt bằng phím F
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        AimbotEnabled = not AimbotEnabled
        print("Aimbot 120°: " .. (AimbotEnabled and "BẬT" or "TẮT"))
    end
end)

-- ===== Ẩn người chơi ở xa =====
local function HideFarPlayers()
    local root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local myPos = root.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local otherChar = player.Character
            if otherChar then
                local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local dist = (myPos - otherRoot.Position).Magnitude
                    if dist > 250 then
                        if otherChar.Parent == Workspace then
                            otherChar.Parent = nil
                        end
                    else
                        if otherChar.Parent == nil then
                            otherChar.Parent = Workspace
                            task.spawn(ExpandHitbox, player)
                        end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(3)
        pcall(HideFarPlayers)
    end
end)

-- Giải phóng RAM
local function FreeMemory()
    collectgarbage("collect")
    pcall(function()
        game:GetService("UserSettings"):GetService("UserGameSettings").GraphicsQualityLevel = Enum.QualityLevel.Level01
    end)
end

task.spawn(function()
    while true do
        task.wait(20)
        pcall(FreeMemory)
    end
end)

print("Smart FPS Booster + Hitbox + Aimbot 120° HEAD đã kích hoạt")
print("Nhấn F để bật/tắt Aimbot (FOV = 120°)")
