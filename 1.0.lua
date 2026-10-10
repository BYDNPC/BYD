-- ============================================
-- SkinHUB Lite v1.3 · 原生UI版
-- 功能：强制爆头 / 血液移除 / 去雾 / 透视
-- 适配：手机端 · 忍者注入器
-- 无 Obsidian 依赖，无网络 UI 依赖
-- ============================================

local fn
local v

fn = function()
    local cloneref = cloneref
    if not cloneref then
        return function(arg)
            return arg
        end
    end
    local obj = setmetatable({}, { __mode = "v" })

    return function(arg)
        if not arg then
            return nil
        end
        local debugId = arg:GetDebugId()
        local cached = obj[debugId]
        if cached then
            return cached
        end
        local cloned = cloneref(arg)
        obj[debugId] = cloned
        return cloned
    end
end

v = fn()

local Players           = v(game:GetService("Players"))
local Lighting          = v(game:GetService("Lighting"))
local ReplicatedStorage = v(game:GetService("ReplicatedStorage"))
local Workspace         = v(game:GetService("Workspace"))
local RunService        = v(game:GetService("RunService"))
local UserInputService  = v(game:GetService("UserInputService"))
local StarterGui        = v(game:GetService("StarterGui"))
local LocalPlayer       = Players.LocalPlayer

if getgenv().SkinHubLiteLoaded then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Skin HUB Lite",
            Text  = "请勿重复执行",
            Duration = 3,
        })
    end)
    return
end
getgenv().SkinHubLiteLoaded = true

-- ============ 加载 MSESP（失败自动降级） ============
local MSESP = nil
pcall(function()
    MSESP = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/mstudio45/MSESP/refs/heads/main/source.luau"
    ))()
end)

if MSESP == nil then
    MSESP = getgenv().mstudio45_ESP
end

if MSESP ~= nil then
    pcall(function()
        MSESP.GlobalConfig.Billboards = true
        MSESP.GlobalConfig.Distance   = true
    end)
end

local useNativeHighlight = (MSESP == nil)

-- 原生 Highlight 容器
local espFolder = Instance.new("Folder")
espFolder.Name = "SkinHubLiteESP"
espFolder.Parent = Workspace

-- 统一 ESP 添加接口
local function addESP(name, model, color)
    if not model or not model.Parent then return nil end

    -- 优先 MSESP
    if not useNativeHighlight and MSESP ~= nil then
        local ok, result = pcall(MSESP.Add, MSESP, {
            Name = name,
            Model = model,
            Color = color,
            MaxDistance = 200,
            TextSize = 14,
            ESPType = "Highlight",
            FillColor = color,
            OutlineColor = color,
            FillTransparency = 0.5,
            OutlineTransparency = 0,
        })
        if ok and result then
            return { obj = result, native = false }
        end
    end

    -- 降级：原生 Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "SkinHubLiteHL"
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = model
    hl.Parent = espFolder
    return { obj = hl, native = true }
end

local function removeESP(e)
    if not e or not e.obj then return end
    pcall(function()
        e.obj:Destroy()
    end)
end

-- ============================================
-- 强制爆头
-- ============================================
local headshotEnabled = false
local removeBloodEnabled = false
local hookInstalled = false
local originalBayonetHitCheck = nil
local originalMeleeHitCheck = nil
local lastZombieHitTime = {}
local ZOMBIE_HIT_COOLDOWN = 0.1

local function getZombieFromInstance(instance)
    if not instance then return nil end
    local parent = instance.Parent
    for _ = 1, 5 do
        if not parent then break end
        if parent:IsA("Model") and (parent.Name == "m_Zombie" or parent:FindFirstChild("Orig")) then
            return parent
        end
        parent = parent.Parent
    end
    return nil
end

local function getHeadFromZombie(model)
    if not model then return nil end
    for _, child in model:GetChildren() do
        if child.Name == "Head" and (child:IsA("Part") or child:IsA("MeshPart")) then
            return child
        end
    end
    return nil
end

local function unifiedBayonetHitCheck(self, origin, dir, params, swingType)
    local rp = type(params) == "table" and params.ray or params
    local hit = Workspace:Raycast(origin, dir, rp)

    if hit then
        local model = getZombieFromInstance(hit.Instance)
        if model then
            local now = os.clock()
            if lastZombieHitTime[model] and now - lastZombieHitTime[model] < ZOMBIE_HIT_COOLDOWN then
                return 0
            end
            local orig = model:FindFirstChild("Orig")
            if orig then
                local head = getHeadFromZombie(model)
                if head then
                    local value = orig.Value
                    local position = head.Position
                    local hitPart = (headshotEnabled or hit.Instance == head) and "Head" or "Torso"
                    local hitPos = position

                    if removeBloodEnabled then
                        local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
                        if hrp then
                            hitPos = hrp.Position + Vector3.new(0, -9999, 0)
                        end
                    end

                    self.remoteEvent:FireServer("Bayonet_HitZombie", value, hitPos, true, hitPart, swingType)
                    value:SetAttribute("WepHitID", now)
                    value:SetAttribute("WepHitDirection", dir * 10)
                    value:SetAttribute("WepHitPos", hitPos)
                    lastZombieHitTime[model] = now
                    return 1
                end
            end
        end
    end

    if originalBayonetHitCheck then
        return originalBayonetHitCheck(self, origin, dir, params, swingType)
    end
    return 0
end

local function unifiedMeleeHitCheck(self, origin, dir, params, arg5, charge)
    local rp = type(params) == "table" and params.ray or params
    local hit = Workspace:Raycast(origin, dir, rp)

    if hit then
        local model = getZombieFromInstance(hit.Instance)
        if model then
            local now = os.clock()
            if lastZombieHitTime[model] and now - lastZombieHitTime[model] < ZOMBIE_HIT_COOLDOWN then
                return 0
            end
            local orig = model:FindFirstChild("Orig")
            if orig then
                local head = getHeadFromZombie(model)
                if head then
                    local value = orig.Value
                    local position = head.Position
                    local hitPart = (headshotEnabled or hit.Instance == head) and "Head" or "Torso"

                    if removeBloodEnabled then
                        local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
                        if hrp then
                            position = hrp.Position + Vector3.new(0, -9999, 0)
                        end
                    end

                    local character = LocalPlayer.Character
                    local myHead = character and character:FindFirstChild("Head")
                    local pushDir = myHead and (position - myHead.Position).Unit or Vector3.new(0, 1, 0)

                    if charge then
                        self.remoteEvent:FireServer("ThrustCharge", value, position, hit.Normal)
                    else
                        self.remoteEvent:FireServer("HitZombieM", value, position, true, position, hitPart, pushDir)
                    end

                    lastZombieHitTime[model] = now
                    return 1
                end
            end
        end
    end

    if originalMeleeHitCheck then
        return originalMeleeHitCheck(self, origin, dir, params, arg5, charge)
    end
    return 0
end

local function updateHitHooks()
    local want = headshotEnabled or removeBloodEnabled
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local weapons = modules and modules:FindFirstChild("Weapons")
    local canHookFunc = type(hookfunction) == "function"

    if want and not hookInstalled then
        if weapons then
            local ok1, flintlock = pcall(require, weapons:FindFirstChild("Flintlock"))
            if ok1 and flintlock and flintlock.BayonetHitCheck then
                if canHookFunc then
                    if not originalBayonetHitCheck then
                        originalBayonetHitCheck = hookfunction(flintlock.BayonetHitCheck, unifiedBayonetHitCheck)
                    else
                        hookfunction(flintlock.BayonetHitCheck, unifiedBayonetHitCheck)
                    end
                else
                    if not originalBayonetHitCheck then
                        originalBayonetHitCheck = flintlock.BayonetHitCheck
                    end
                    flintlock.BayonetHitCheck = unifiedBayonetHitCheck
                end
            end

            local ok2, meleeBase = pcall(require, weapons:FindFirstChild("MeleeBase"))
            if ok2 and meleeBase and meleeBase.MeleeHitCheck then
                if canHookFunc then
                    if not originalMeleeHitCheck then
                        originalMeleeHitCheck = hookfunction(meleeBase.MeleeHitCheck, unifiedMeleeHitCheck)
                    else
                        hookfunction(meleeBase.MeleeHitCheck, unifiedMeleeHitCheck)
                    end
                else
                    if not originalMeleeHitCheck then
                        originalMeleeHitCheck = meleeBase.MeleeHitCheck
                    end
                    meleeBase.MeleeHitCheck = unifiedMeleeHitCheck
                end
            end
        end
        hookInstalled = true
    elseif not want and hookInstalled then
        if weapons then
            if originalBayonetHitCheck then
                local ok, flintlock = pcall(require, weapons:FindFirstChild("Flintlock"))
                if ok and flintlock then
                    if canHookFunc then
                        hookfunction(flintlock.BayonetHitCheck, originalBayonetHitCheck)
                    else
                        flintlock.BayonetHitCheck = originalBayonetHitCheck
                    end
                end
            end
            if originalMeleeHitCheck then
                local ok, meleeBase = pcall(require, weapons:FindFirstChild("MeleeBase"))
                if ok and meleeBase then
                    if canHookFunc then
                        hookfunction(meleeBase.MeleeHitCheck, originalMeleeHitCheck)
                    else
                        meleeBase.MeleeHitCheck = originalMeleeHitCheck
                    end
                end
            end
        end
        hookInstalled = false
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if headshotEnabled or removeBloodEnabled then
        hookInstalled = false
        updateHitHooks()
    end
end)

-- ============================================
-- 透视
-- ============================================
local ZOMBIE_ESP_RANGE = 200

local function lightenColor(c, ratio)
    local r = ratio or 0.5
    return Color3.new(
        c.R + (1 - c.R) * r,
        c.G + (1 - c.G) * r,
        c.B + (1 - c.B) * r
    )
end

local ZOMBIE_TYPES = {
    Eye      = { name = "红眼",     color = Color3.fromRGB(255, 50, 50),  part = "Eye" },
    Sword    = { name = "胸甲骑兵", color = Color3.fromRGB(255, 0, 255),  part = "Sword" },
    Barrel   = { name = "自爆",     color = Color3.fromRGB(250, 250, 0),  part = "Barrel" },
    Headless = { name = "无头骑士", color = Color3.fromRGB(255, 215, 0),  matchName = "HeadlessHorseman" },
}

for _, t in ZOMBIE_TYPES do
    t.highlightColor = lightenColor(t.color)
end

local zombieEspEnabled = { Eye = false, Sword = false, Barrel = false, Headless = false }
local playerEspEnabled = false
local playerEspTeamCheck = false

local zombieEffects = {}
local playerEffects = {}

local function getZombieTypeKey(model)
    for k, def in ZOMBIE_TYPES do
        if def.part and model:FindFirstChild(def.part) then
            return k
        end
    end
    for k, def in ZOMBIE_TYPES do
        if def.matchName and model.Name == def.matchName then
            return k
        end
    end
    return nil
end

local function createZombieESP(model, key)
    local def = ZOMBIE_TYPES[key]
    if not def then return nil end
    return addESP(def.name, model, def.highlightColor)
end

local function removeZombieEffects(model)
    local e = zombieEffects[model]
    if e then
        removeESP(e.esp)
        zombieEffects[model] = nil
    end
end

local function clearAllZombieEffects()
    for k in zombieEffects do
        removeZombieEffects(k)
    end
end

local function updateZombieESP()
    local anyEnabled = false
    for _, vv in zombieEspEnabled do
        if vv then anyEnabled = true break end
    end
    if not anyEnabled then
        clearAllZombieEffects()
        return
    end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position
    if not myPos then
        clearAllZombieEffects()
        return
    end

    for model, e in zombieEffects do
        if not model.Parent or e.esp == nil then
            removeZombieEffects(model)
        end
    end

    local list = {}
    local camera = Workspace:FindFirstChild("Camera")
    if camera then
        for _, m in camera:GetDescendants() do
            if m:IsA("Model") and m.Name:find("Zombie") then
                table.insert(list, m)
            end
        end
    end
    local zombies = Workspace:FindFirstChild("Zombies")
    if zombies then
        for _, m in zombies:GetChildren() do
            if m:IsA("Model") and m.Name:find("Zombie") then
                table.insert(list, m)
            end
        end
    end

    for _, model in list do
        local root = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("Head")
            or model:FindFirstChild("Torso")
        if root then
            local dist = (root.Position - myPos).Magnitude
            local key = getZombieTypeKey(model)
            local enabled = key and zombieEspEnabled[key]
            local e = zombieEffects[model]

            if enabled and dist <= ZOMBIE_ESP_RANGE then
                if e == nil then
                    local esp = createZombieESP(model, key)
                    if esp then
                        zombieEffects[model] = { esp = esp, typeKey = key }
                    end
                elseif e.typeKey ~= key then
                    removeZombieEffects(model)
                    local esp = createZombieESP(model, key)
                    if esp then
                        zombieEffects[model] = { esp = esp, typeKey = key }
                    end
                end
            elseif e then
                removeZombieEffects(model)
            end
        end
    end
end

local function getTeam(plr)
    if plr.Team then return plr.Team end
    return plr:GetAttribute("Team")
end

local function updatePlayerESP(plr)
    local e = playerEffects[plr]

    if not playerEspEnabled then
        if e then
            removeESP(e.esp)
            playerEffects[plr] = nil
        end
        return
    end

    local character = plr.Character
    if not character or character == LocalPlayer.Character then
        if e then
            removeESP(e.esp)
            playerEffects[plr] = nil
        end
        return
    end
    if not character:FindFirstChild("HumanoidRootPart") then return end

    if e and e.model ~= character then
        removeESP(e.esp)
        playerEffects[plr] = nil
        e = nil
    end

    local col
    if not playerEspTeamCheck then
        col = Color3.fromRGB(255, 255, 255)
    else
        local a, b = getTeam(LocalPlayer), getTeam(plr)
        if a and b and a == b then
            col = Color3.fromRGB(100, 150, 255)
        else
            col = Color3.fromRGB(255, 100, 100)
        end
    end

    if e == nil then
        local esp = addESP(plr.Name, character, col)
        if esp then
            playerEffects[plr] = { esp = esp, model = character }
        end
    end
end

task.spawn(function()
    while true do
        pcall(function()
            updateZombieESP()
            for _, plr in Players:GetPlayers() do
                if plr ~= LocalPlayer then
                    updatePlayerESP(plr)
                end
            end
        end)
        task.wait(0.3)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    local e = playerEffects[plr]
    if e then removeESP(e.esp) end
    playerEffects[plr] = nil
end)

-- ============================================
-- 去雾
-- ============================================
local noFogEnabled = false
local noFogOriginal = {}
local noFogSaved = false
local noFogAtmosphereBackup = {}

local function saveNoFogOriginal()
    if noFogSaved then return end
    pcall(function()
        noFogOriginal = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart }
        noFogSaved = true
    end)
end

saveNoFogOriginal()

local function applyNoFog()
    pcall(function()
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        noFogAtmosphereBackup = {}
        for _, inst in Lighting:GetDescendants() do
            if inst:IsA("Atmosphere") then
                table.insert(noFogAtmosphereBackup, { Instance = inst, Parent = inst.Parent })
                inst.Parent = nil
            end
        end
    end)
end

local function restoreNoFog()
    pcall(function()
        Lighting.FogEnd = noFogOriginal.FogEnd or 100000
        Lighting.FogStart = noFogOriginal.FogStart or 0
        for _, entry in noFogAtmosphereBackup do
            if entry.Instance and entry.Parent then
                entry.Instance.Parent = entry.Parent
            end
        end
        noFogAtmosphereBackup = {}
    end)
end

-- ============================================
-- 原生 UI
-- ============================================
local COLORS = {
    bg      = Color3.fromRGB(10, 15, 25),
    bg2     = Color3.fromRGB(18, 26, 40),
    border  = Color3.fromRGB(45, 90, 140),
    accent  = Color3.fromRGB(80, 200, 255),
    text    = Color3.fromRGB(220, 220, 220),
    textDim = Color3.fromRGB(140, 160, 180),
    on      = Color3.fromRGB(80, 200, 255),
    off     = Color3.fromRGB(55, 65, 80),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkinHubLiteUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 240, 0, 400)
mainFrame.Position = UDim2.new(0, 20, 0, 100)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COLORS.border
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

-- 标题栏
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = COLORS.bg2
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleMask = Instance.new("Frame")
titleMask.Size = UDim2.new(1, 0, 0, 10)
titleMask.Position = UDim2.new(0, 0, 1, -10)
titleMask.BackgroundColor3 = COLORS.bg2
titleMask.BorderSizePixel = 0
titleMask.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SkinHUB Lite"
titleLabel.TextColor3 = COLORS.accent
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

-- 拖动
local dragging = false
local dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging then
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- 内容区
local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Size = UDim2.new(1, -12, 1, -44)
content.Position = UDim2.new(0, 6, 0, 38)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = COLORS.border
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

-- 分组标题
local function createSection(text, order)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -8, 0, 22)
    section.BackgroundTransparency = 1
    section.LayoutOrder = order
    section.Parent = content

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = COLORS.accent
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = section

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -8, 0, 1)
    line.Position = UDim2.new(0, 8, 1, -3)
    line.BackgroundColor3 = COLORS.border
    line.BackgroundTransparency = 0.5
    line.BorderSizePixel = 0
    line.Parent = section

    return section
end

-- 开关行
local function createToggleRow(text, defaultOn, callback, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 28)
    row.BackgroundColor3 = COLORS.bg2
    row.BackgroundTransparency = 0.4
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = content

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = COLORS.text
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local state = defaultOn
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 20)
    btn.Position = UDim2.new(1, -58, 0.5, -10)
    btn.BackgroundColor3 = state and COLORS.on or COLORS.off
    btn.Text = state and "开" or "关"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and COLORS.on or COLORS.off
        btn.Text = state and "开" or "关"
        if callback then
            pcall(callback, state)
        end
    end)

    return row
end

-- ============ 填充 UI ============
local order = 0
local function nextOrder()
    order = order + 1
    return order
end

createSection("战斗", nextOrder())
createToggleRow("近战强制爆头", false, function(state)
    headshotEnabled = state
    updateHitHooks()
end, nextOrder())
createToggleRow("移除血液粒子", false, function(state)
    removeBloodEnabled = state
    updateHitHooks()
end, nextOrder())

createSection("环境", nextOrder())
createToggleRow("去雾", false, function(state)
    noFogEnabled = state
    if state then
        applyNoFog()
        task.spawn(function()
            while noFogEnabled do
                pcall(applyNoFog)
                task.wait(2)
            end
        end)
    else
        restoreNoFog()
    end
end, nextOrder())

createSection("僵尸透视", nextOrder())
createToggleRow("红眼", false, function(state)
    zombieEspEnabled.Eye = state
end, nextOrder())
createToggleRow("胸甲骑兵", false, function(state)
    zombieEspEnabled.Sword = state
end, nextOrder())
createToggleRow("自爆", false, function(state)
    zombieEspEnabled.Barrel = state
end, nextOrder())
createToggleRow("无头骑士", false, function(state)
    zombieEspEnabled.Headless = state
end, nextOrder())

createSection("玩家透视", nextOrder())
createToggleRow("高亮玩家", false, function(state)
    playerEspEnabled = state
    if not state then
        for _, e in playerEffects do
            removeESP(e.esp)
        end
        playerEffects = {}
    end
end, nextOrder())
createToggleRow("队伍检测", false, function(state)
    playerEspTeamCheck = state
end, nextOrder())

-- 关闭按钮
closeBtn.MouseButton1Click:Connect(function()
    pcall(clearAllZombieEffects)
    for _, e in playerEffects do
        removeESP(e.esp)
    end
    playerEffects = {}
    if noFogEnabled then
        noFogEnabled = false
        restoreNoFog()
    end
    screenGui:Destroy()
    getgenv().SkinHubLiteLoaded = nil
end)

-- 提示信息
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "SkinHUB Lite",
        Text  = useNativeHighlight and "已加载（原生高亮模式）" or "已加载（MSESP 模式）",
        Duration = 3,
    })
end)