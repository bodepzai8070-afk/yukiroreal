-- [[ Smart FPS Booster + Hitbox Extender (Delta Executor) ]]
-- Bổ sung: phóng to hitbox người chơi khác để dễ bắn hơn

if _G.SmartFPSBoosterExecuted then return end
_G.SmartFPSBoosterExecuted = true

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

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

-- Hàm tối ưu thông minh
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

-- Quét map ban đầu
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

-- Tối ưu Lighting
Lighting.GlobalShadows = false
Lighting.Brightness = 1
Lighting.ClockTime = 12
for _, child in ipairs(Lighting:GetChildren()) do
    if child:IsA("BlurEffect") or child:IsA("SunRaysEffect") or
       child:IsA("BloomEffect") or child:IsA("DepthOfFieldEffect") then
        child:Destroy()
    end
end

-- ===== HITBOX EXPANDER CHO PLAYER KHÁC =====
local HitboxSize = Vector3.new(6, 6, 6)  -- kích thước hitbox (điều chỉnh tùy ý)
local IgnoredPlayers = {}  -- nếu muốn bỏ qua ai đó

local function ExpandHitbox(player)
    if player == LocalPlayer then return end
    if IgnoredPlayers[player] then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Chỉ phóng to hitbox của RootPart (không làm biến dạng model)
    hrp.Size = HitboxSize
    hrp.CanCollide = false  -- tránh đẩy vật lý
    -- Kéo theo các phần khác (tay, chân) để không bị lỗi nếu muốn
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("BasePart") and child ~= hrp then
            -- Không thay đổi size, chỉ bảo đảm chúng nằm gọn trong hitbox
            -- Hoặc có thể set Size theo tỉ lệ nhỏ hơn
        end
    end
end

-- Quét tất cả người chơi hiện tại
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        task.spawn(ExpandHitbox, p)
    end
end

-- Đón đầu khi người chơi mới xuất hiện
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)  -- đợi load xong
        ExpandHitbox(player)
    end)
end)

-- Lặp lại mỗi 5 giây để fix các phần bị reset
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

-- ===== Ẩn người chơi ở xa (giữ nguyên hitbox khi ẩn) =====
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
                            -- Khi hiện lại, áp dụng lại hitbox
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

print("Smart FPS Booster + Hitbox Extender đã kích hoạt")
