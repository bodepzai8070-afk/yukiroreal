-- [[ Smart FPS Booster + Hitbox Extender + Aimbot 180° FOV + Lock Target (Delta Executor) ]]
-- Nâng cấp: FOV 180°, ưu tiên head, bù lead, silent aim, tự động bắn liên tục, chống giật

if _G.SmartFPSBoosterExecuted then return end
_G.SmartFPSBoosterExecuted = true

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Camera = Workspace.CurrentCamera

-- Cấu hình nâng cao
local CONFIG = {
    FOV = 180,                    -- Quét full 180°
    SMOOTH = 0.05,                -- Làm mượt cực nhanh
    TARGET_DISTANCE = 99999,      -- Không giới hạn khoảng cách
    HITBOX_SIZE = Vector3.new(12, 12, 12),
    SHOOT_INTERVAL = 0.015,       -- Bắn liên tục ~66 phát/giây
    LEAD_FACTOR = 0.4,            -- Bù đạn cho mục tiêu di chuyển
    SILENT_AIM = true,            -- Chỉ xoay camera ảo (không hiện cho server)
    AUTO_SHOOT = true,
    HIDE_DISTANCE = 400,
}

local ImportantNames = {
    "Baseplate", "SpawnLocation", "Floor", "Ground", "Sàn",
    "Checkpoint", "Teleport", "Terrain"
}
local function IsImportant(part)
    if not part then return false end
    local name = part.Name:lower()
    for _, v in ipairs(ImportantNames) do
        if name == v:lower() then return true end
    end
    if name:find("floor") or name:find("plate") or name:find("terrain") then return true end
    return false
end

-- Tối ưu FPS cực mạnh
local function SmartOptimize(obj)
    if not obj then return end
    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
        if not IsImportant(obj) then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.Transparency = 0.5  -- Giảm tải render
            if obj:IsA("MeshPart") then
                obj.TextureID = ""
                if obj.MeshId ~= "" then obj.MeshId = "" end
            end
        end
    end
    if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or
       obj:IsA("Sparkles") or obj:IsA("Trail") or obj:IsA("Beam") or
       obj:IsA("Attachment") or obj:IsA("Sound") then
        obj:Destroy()
        return
    end
    if (obj:IsA("Decal") or obj:IsA("Texture")) then
        local parent = obj.Parent
        if parent and not IsImportant(parent) then obj:Destroy() end
    end
    if obj:IsA("WedgePart") or obj:IsA("CornerWedgePart") then
        obj.Material = Enum.Material.Plastic
    end
end

task.spawn(function()
    local allParts = Workspace:GetDescendants()
    local count = 0
    for _, obj in ipairs(allParts) do
        count = count + 1
        SmartOptimize(obj)
        if count % 200 == 0 then RunService.Heartbeat:Wait() end
    end
    -- Xóa terrain chi tiết nếu có
    pcall(function()
        if Workspace.Terrain then
            Workspace.Terrain.WaterWaveSize = 0
            Workspace.Terrain.WaterReflectance = 0
            Workspace.Terrain.WaterTransparency = 1
        end
    end)
end)

Workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.1)
    if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
        if obj == Character then return end
    end
    SmartOptimize(obj)
end)

-- Lighting tối giản
Lighting.GlobalShadows = false
Lighting.Brightness = 0.5
Lighting.Ambient = Color3.fromRGB(80,80,80)
Lighting.ClockTime = 12
Lighting.FogEnd = 100000
for _, child in ipairs(Lighting:GetChildren()) do
    if child:IsA("BlurEffect") or child:IsA("SunRaysEffect") or
       child:IsA("BloomEffect") or child:IsA("DepthOfFieldEffect") or
       child:IsA("ColorCorrectionEffect") then
        child:Destroy()
    end
end

-- ===== HITBOX EXPANDER + KHÔNG COLLIDE =====
local HitboxSize = CONFIG.HITBOX_SIZE
local function ExpandHitbox(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.Size = HitboxSize
    hrp.CanCollide = false
    hrp.Massless = true
    -- Mở rộng tất cả các bộ phận khác
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Size = HitboxSize * 0.8
            part.CanCollide = false
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then task.spawn(ExpandHitbox, p) end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.3)
        ExpandHitbox(player)
    end)
end)

task.spawn(function()
    while true do
        task.wait(3)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then pcall(ExpandHitbox, p) end
        end
    end
end)

-- ===== AIMBOT 180° + SILENT + LEAD =====
local AimbotEnabled = true
local AutoShoot = CONFIG.AUTO_SHOOT
local CurrentTarget = nil

local function GetHeadPosition(player)
    local char = player.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head.Position end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position + Vector3.new(0, 1.8, 0) end
    return nil
end

local function GetVelocity(player)
    local char = player.Character
    if not char then return Vector3.new(0,0,0) end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Velocity
    end
    return Vector3.new(0,0,0)
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
                if dist > CONFIG.TARGET_DISTANCE then continue end
                local dirToTarget = (headPos - cameraPos).Unit
                local dot = cameraDir:Dot(dirToTarget)
                local angle = math.deg(math.acos(dot))
                if angle > CONFIG.FOV then continue end
                -- Ưu tiên gần + góc nhỏ
                local score = angle * 0.3 + dist * 0.0005
                if score < bestScore then
                    bestScore = score
                    bestTarget = player
                end
            end
        end
    end
    return bestTarget
end

-- Silent Aim (chỉ xoay camera local, server không phát hiện)
local function SilentAim(targetPlayer)
    if not targetPlayer then return end
    local headPos = GetHeadPosition(targetPlayer)
    if not headPos then return end
    -- Bù lead
    local vel = GetVelocity(targetPlayer)
    local leadOffset = vel * CONFIG.LEAD_FACTOR
    local targetPos = headPos + leadOffset
    
    local newCF = CFrame.new(Camera.CFrame.Position, targetPos)
    if CONFIG.SMOOTH > 0 then
        Camera.CFrame = Camera.CFrame:Lerp(newCF, CONFIG.SMOOTH)
    else
        Camera.CFrame = newCF
    end
end

-- Bắn tự động với tốc độ cao
local function Shoot()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(CONFIG.SHOOT_INTERVAL)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

-- Vòng lặp chính
RunService.RenderStepped:Connect(function()
    if not AimbotEnabled then return end
    if not Character or not Character.Parent then return end
    local target = GetClosestTarget()
    CurrentTarget = target
    if target then
        if CONFIG.SILENT_AIM then
            SilentAim(target)
        else
            -- Nếu không silent thì dùng aim thường
            local headPos = GetHeadPosition(target)
            if headPos then
                local newCF = CFrame.new(Camera.CFrame.Position, headPos)
                Camera.CFrame = Camera.CFrame:Lerp(newCF, CONFIG.SMOOTH)
            end
        end
        if AutoShoot then
            Shoot()
        end
    end
end)

-- Phím F bật/tắt, phím G bật/tắt auto shoot
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        AimbotEnabled = not AimbotEnabled
        print("Aimbot 180°: " .. (AimbotEnabled and "BẬT" or "TẮT"))
    end
    if input.KeyCode == Enum.KeyCode.G then
        AutoShoot = not AutoShoot
        print("Auto Shoot: " .. (AutoShoot and "BẬT" or "TẮT"))
    end
end)

-- ===== ẨN NGƯỜI CHƠI XA + TELEPORT NGƯỢC =====
local hiddenPlayers = {}
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
                    if dist > CONFIG.HIDE_DISTANCE then
                        if otherChar.Parent == Workspace then
                            otherChar.Parent = nil
                            hiddenPlayers[player.UserId] = otherChar
                        end
                    else
                        if otherChar.Parent == nil and hiddenPlayers[player.UserId] then
                            hiddenPlayers[player.UserId].Parent = Workspace
                            hiddenPlayers[player.UserId] = nil
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
        task.wait(2)
        pcall(HideFarPlayers)
    end
end)

-- ===== GIẢI PHÓNG RAM TỐI ĐA =====
local function FreeMemory()
    collectgarbage("collect")
    collectgarbage("step", 1000)
    pcall(function()
        game:GetService("UserSettings"):GetService("UserGameSettings").GraphicsQualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    -- Xóa các đối tượng rác
    for _, v in pairs(Workspace:GetChildren()) do
        if v:IsA("Part") and v.Name == "" and v:GetChildren()[1] == nil then
            v:Destroy()
        end
    end
end

task.spawn(function()
    while true do
        task.wait(15)
        pcall(FreeMemory)
    end
end)

-- ===== CHỐNG CRASH =====
pcall(function()
    game:GetService("ScriptContext").Error:Connect(function(msg, stack)
        if string.find(msg, "Too many") or string.find(msg, "out of memory") then
            FreeMemory()
        end
    end)
end)

print("=== AIMBOT 180° SILENT + AUTO SHOOT + FPS BOOST ===")
print("F: Bật/tắt aimbot | G: Bật/tắt auto bắn")
print("Hitbox mở rộng x12, lead bù đạn, silent aim")
