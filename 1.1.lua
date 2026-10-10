-- ============================================
-- SkinHUB Lite v1.5
-- 精简版：强制爆头 / 玩家透视 / 僵尸透视 / 去雾
-- 核心功能写法完全照 SkinHUBv4.2 原脚本
-- UI 使用原生（手机端优化）
-- ============================================

local clock = os.clock
local floor = math.floor
local vector = Vector3.new
local color = Color3.fromRGB
local cframe = CFrame.new
local format = string.format
local v

local function fn()
    local v2 = cloneref
    if not v2 then
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
        local v3 = obj[debugId]
        if v3 then
            return v3
        end
        local v4 = v2(arg)
        obj[debugId] = v4
        return v4
    end
end

v = fn()

if getgenv().SkinHubLoaded then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Skin HUB Lite",
        Text = "请勿重复执行",
        Duration = 3,
    })
    return
end

getgenv().SkinHubLoaded = true

local v2, tbl, lib4, fn2, localPlayer, v4, v5, v6, v7, v9, v10

do
    v2 = v(game:GetService("HttpService"))
    v4 = v(game:GetService("Players"))
    v5 = v(game:GetService("RunService"))
    v6 = v(game:GetService("UserInputService"))
    v7 = v(game:GetService("ReplicatedStorage"))
    v9 = v(game:GetService("Lighting"))
    v10 = v(game:GetService("Stats"))
    localPlayer = v4.LocalPlayer

    tbl = {}
    lib4 = nil

    -- 照原脚本加载 MSESP
    pcall(function()
        lib4 = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/MSESP/refs/heads/main/source.luau"))()
    end)

    if lib4 == nil then
        lib4 = getgenv().mstudio45_ESP
    end

    if lib4 ~= nil then
        pcall(function()
            lib4.GlobalConfig.Billboards = true
            lib4.GlobalConfig.Distance = true
        end)
    end

    tbl.addESP = function(arg)
        if lib4 == nil then
            return nil
        end
        local ok, result = pcall(lib4.Add, lib4, arg)
        if ok then
            return result
        end
        return nil
    end

    tbl.destroyESP = function(arg)
        if arg ~= nil then
            pcall(function()
                arg:Destroy()
            end)
        end
    end

    tbl.notify = function(arg, arg2)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Skin HUB Lite",
                Text = arg,
                Duration = arg2 or 2,
            })
        end)
    end

    fn2 = function(arg, ...)
        local tbl4 = { ... }
        for i = 1, #tbl4 do
            local v13 = tbl4[i]
            if arg then
                arg = arg:FindFirstChild(v13)
            else
                arg = nil
            end
            if not arg then
                return nil
            end
        end
        return arg
    end
end

-- ============ onCharacterAdded（照原脚本） ============
tbl._charAddedHandlers = {}

localPlayer.CharacterAdded:Connect(function(character)
    local charAddedHandlers = tbl._charAddedHandlers
    for i = 1, #charAddedHandlers do
        local v14 = charAddedHandlers[i]
        if v14 then
            local ok, result = pcall(v14, character)
            if not ok then
                warn("[SkinHub] CharacterAdded handler error: " .. tostring(result))
            end
        end
    end
end)

tbl.onCharacterAdded = function(arg)
    table.insert(tbl._charAddedHandlers, arg)
    return function()
        for i = #tbl._charAddedHandlers, 1, -1 do
            if tbl._charAddedHandlers[i] == arg then
                table.remove(tbl._charAddedHandlers, i)
                break
            end
        end
    end
end

-- ============ ZombieWatch（照原脚本） ============
tbl.ZombieWatch = { _models = {}, _addedSubs = {}, _started = false }
local tbl4 = { "Zombies", "Camera" }

tbl.ZombieWatch.start = function()
    if tbl.ZombieWatch._started then
        return
    end
    tbl.ZombieWatch._started = true
    local addedSubs = tbl.ZombieWatch._addedSubs

    local function fn6(arg)
        if arg:IsA("Model") and not tbl.ZombieWatch._models[arg] then
            tbl.ZombieWatch._models[arg] = true
            for _, v14 in addedSubs, nil, nil do
                task.spawn(v14, arg)
            end
        end
    end

    local function fn7(arg)
        if not arg or arg:GetAttribute("SkinHubZombieWatch") then
            return
        end
        arg:SetAttribute("SkinHubZombieWatch", true)

        arg.ChildAdded:Connect(function(child)
            task.defer(fn6, child)
        end)
        arg.ChildRemoved:Connect(function(child)
            tbl.ZombieWatch._models[child] = nil
        end)

        for _, v14 in arg:GetChildren() do
            task.spawn(fn6, v14)
        end
    end

    local function fn8()
        for _, v14 in tbl4, nil, nil do
            fn7(workspace:FindFirstChild(v14))
        end
    end

    fn8()

    workspace.ChildAdded:Connect(function(child)
        for _, v14 in tbl4, nil, nil do
            if child.Name == v14 then
                task.defer(fn7, child)
            end
        end
    end)
end

tbl.ZombieWatch.getAll = function()
    local tbl5 = {}
    for k in tbl.ZombieWatch._models, nil, nil do
        if k.Parent then
            tbl5[#tbl5 + 1] = k
        else
            tbl.ZombieWatch._models[k] = nil
        end
    end
    return tbl5
end

tbl.ZombieWatch.onAdded = function(arg)
    table.insert(tbl.ZombieWatch._addedSubs, arg)
    return function()
        local v14 = table.find(tbl.ZombieWatch._addedSubs, arg)
        if v14 then
            table.remove(tbl.ZombieWatch._addedSubs, v14)
        end
    end
end

tbl.ZombieWatch.forEach = function(arg)
    for _, v14 in tbl.ZombieWatch.getAll() do
        pcall(arg, v14)
    end
end

-- ============================================
-- 强制爆头（完全照原脚本）
-- ============================================
tbl.headshotEnabled = false
tbl.removeBloodEnabled = false
tbl.hookInstalled = false
tbl.originalBayonetHitCheck = nil
tbl.originalMeleeHitCheck = nil
tbl.lastZombieHitTime = {}
tbl.ZOMBIE_HIT_COOLDOWN = 0.1

local function fn17(arg)
    if not arg then
        return nil
    end
    local parent = arg.Parent
    for i = 1, 5 do
        if not parent then
            break
        end
        if parent:IsA("Model") and (parent.Name == "m_Zombie" or parent:FindFirstChild("Orig")) then
            return parent
        end
        parent = parent.Parent
    end
    return nil
end

local function fn18(arg)
    if not arg then
        return nil
    end
    for _, v30 in arg:GetChildren() do
        if v30.Name == "Head" and (v30:IsA("Part") or v30:IsA("MeshPart")) then
            return v30
        end
    end
    return nil
end

tbl.unifiedBayonetHitCheck = function(arg, arg2, arg3, arg4, arg5)
    local hit = workspace:Raycast(arg2, arg3, type(arg4) == "table" and arg4.ray or arg4)
    if hit then
        local instance = hit.Instance
        local v30 = fn17(instance)
        if v30 then
            local v31 = clock()
            if tbl.lastZombieHitTime[v30] and v31 - tbl.lastZombieHitTime[v30] < tbl.ZOMBIE_HIT_COOLDOWN then
                return 0
            end
            local orig = v30:FindFirstChild("Orig")
            if orig then
                local v32 = fn18(v30)
                if v32 then
                    local value = orig.Value
                    local position = v32.Position
                    local str2
                    if tbl.headshotEnabled then
                        str2 = "Head"
                    elseif instance == v32 then
                        str2 = "Head"
                    else
                        str2 = "Torso"
                    end
                    local n2
                    if tbl.removeBloodEnabled then
                        local humanoidRootPart = v30:FindFirstChild("HumanoidRootPart") or v30:FindFirstChild("Torso")
                        if humanoidRootPart then
                            n2 = humanoidRootPart.Position + Vector3.new(0, -9999, 0)
                        else
                            n2 = position
                        end
                    else
                        n2 = position
                    end
                    arg.remoteEvent:FireServer("Bayonet_HitZombie", value, n2, true, str2, arg.swingType)
                    value:SetAttribute("WepHitID", clock())
                    value:SetAttribute("WepHitDirection", arg3 * 10)
                    value:SetAttribute("WepHitPos", n2)
                    tbl.lastZombieHitTime[v30] = v31
                    return 1
                end
            end
        end
    end
    if tbl.originalBayonetHitCheck then
        return tbl.originalBayonetHitCheck(arg, arg2, arg3, arg4, arg5)
    end
    return 0
end

tbl.unifiedMeleeHitCheck = function(arg, arg2, arg3, arg4, arg5, arg6)
    local hit = workspace:Raycast(arg2, arg3, type(arg4) == "table" and arg4.ray or arg4)
    if hit then
        local instance = hit.Instance
        local v30 = fn17(instance)
        if v30 then
            local v31 = clock()
            if tbl.lastZombieHitTime[v30] and v31 - tbl.lastZombieHitTime[v30] < tbl.ZOMBIE_HIT_COOLDOWN then
                return 0
            end
            local orig = v30:FindFirstChild("Orig")
            if orig then
                local v32 = fn18(v30)
                if v32 then
                    local value = orig.Value
                    local position = v32.Position
                    local str2
                    if tbl.headshotEnabled then
                        str2 = "Head"
                    elseif instance == v32 then
                        str2 = "Head"
                    else
                        str2 = "Torso"
                    end
                    if tbl.removeBloodEnabled then
                        local humanoidRootPart = v30:FindFirstChild("HumanoidRootPart") or v30:FindFirstChild("Torso")
                        if humanoidRootPart then
                            position = humanoidRootPart.Position + Vector3.new(0, -9999, 0)
                        end
                    end
                    local character = localPlayer.Character
                    local head = character and character:FindFirstChild("Head")
                    head = head and (position - head.Position).Unit or Vector3.new(0, 1, 0)
                    if arg6 then
                        arg.remoteEvent:FireServer("ThrustCharge", value, position, hit.Normal)
                    else
                        arg.remoteEvent:FireServer("HitZombieM", value, position, true, position, str2, head)
                    end
                    tbl.lastZombieHitTime[v30] = v31
                    return 1
                end
            end
        end
    end
    if tbl.originalMeleeHitCheck then
        return tbl.originalMeleeHitCheck(arg, arg2, arg3, arg4, arg5, arg6)
    end
    return 0
end

tbl.updateHitHooks = function()
    local headshotEnabled = tbl.headshotEnabled or tbl.removeBloodEnabled
    local v30 = v7
    local weapons = v7:FindFirstChild("Modules") and v30.Modules:FindFirstChild("Weapons")
    local flag = type(hookfunction) == "function"

    if headshotEnabled and not tbl.hookInstalled then
        if weapons then
            local ok, result = pcall(require, weapons:FindFirstChild("Flintlock"))
            if ok and result and result.BayonetHitCheck then
                if flag then
                    if not tbl.originalBayonetHitCheck then
                        tbl.originalBayonetHitCheck = hookfunction(result.BayonetHitCheck, tbl.unifiedBayonetHitCheck)
                    else
                        hookfunction(result.BayonetHitCheck, tbl.unifiedBayonetHitCheck)
                    end
                else
                    if not tbl.originalBayonetHitCheck then
                        tbl.originalBayonetHitCheck = result.BayonetHitCheck
                    end
                    result.BayonetHitCheck = tbl.unifiedBayonetHitCheck
                end
            end
            local ok2, result2 = pcall(require, weapons:FindFirstChild("MeleeBase"))
            if ok2 and result2 and result2.MeleeHitCheck then
                if flag then
                    if not tbl.originalMeleeHitCheck then
                        tbl.originalMeleeHitCheck = hookfunction(result2.MeleeHitCheck, tbl.unifiedMeleeHitCheck)
                    else
                        hookfunction(result2.MeleeHitCheck, tbl.unifiedMeleeHitCheck)
                    end
                else
                    if not tbl.originalMeleeHitCheck then
                        tbl.originalMeleeHitCheck = result2.MeleeHitCheck
                    end
                    result2.MeleeHitCheck = tbl.unifiedMeleeHitCheck
                end
            end
        end
        tbl.hookInstalled = true
    elseif not headshotEnabled and tbl.hookInstalled then
        if weapons then
            if tbl.originalBayonetHitCheck then
                local ok, result = pcall(require, weapons:FindFirstChild("Flintlock"))
                if ok and result and result.BayonetHitCheck then
                    if flag then
                        hookfunction(result.BayonetHitCheck, tbl.originalBayonetHitCheck)
                    else
                        result.BayonetHitCheck = tbl.originalBayonetHitCheck
                    end
                end
            end
            if tbl.originalMeleeHitCheck then
                local ok, result = pcall(require, weapons:FindFirstChild("MeleeBase"))
                if ok and result then
                    if flag then
                        hookfunction(result.MeleeHitCheck, tbl.originalMeleeHitCheck)
                    else
                        result.MeleeHitCheck = tbl.originalMeleeHitCheck
                    end
                end
            end
        end
        tbl.hookInstalled = false
    end
end

tbl.onCharacterAdded(function()
    task.wait(1)
    tbl.updateHitHooks()
end)

-- ============================================
-- 透视（完全照原脚本）
-- ============================================
tbl.ZOMBIE_ESP_RANGE = 200

tbl.lightenColor = function(arg, arg2)
    local n2 = arg2 or 0.5
    return Color3.new(arg.R + (1 - arg.R) * n2, arg.G + (1 - arg.G) * n2, arg.B + (1 - arg.B) * n2)
end

tbl.ZOMBIE_TYPES = {
    Eye = {
        name = "红眼",
        color = color(255, 50, 50),
        highlightColor = tbl.lightenColor(color(255, 50, 50)),
        part = "Eye",
    },
    Sword = {
        name = "胸甲骑兵",
        color = color(255, 0, 255),
        highlightColor = tbl.lightenColor(color(255, 0, 255)),
        part = "Sword",
    },
    Barrel = {
        name = "自爆",
        color = color(250, 250, 0),
        highlightColor = tbl.lightenColor(color(250, 250, 0)),
        part = "Barrel",
    },
    Headless = {
        name = "无头骑士",
        color = color(255, 215, 0),
        highlightColor = color(255, 215, 0),
        matchName = "HeadlessHorseman",
    },
}

tbl.zombieEspEnabled = {
    Eye = false,
    Sword = false,
    Barrel = false,
    Headless = false,
}

tbl.zombieEffects = {}
tbl.playerEffects = {}
tbl.playerESPModels = {}
tbl.playerEspEnabled = false
tbl.playerEspTeamCheck = false

tbl.getZombieTypeKey = function(arg)
    for k, v26 in tbl.ZOMBIE_TYPES, nil, nil do
        if v26.part and arg:FindFirstChild(v26.part) then
            return k
        end
    end
    for k, v26 in tbl.ZOMBIE_TYPES, nil, nil do
        if v26.matchName and arg.Name == v26.matchName then
            return k
        end
    end
    return nil
end

tbl.createZombieESP = function(arg, arg2)
    local v26 = tbl.ZOMBIE_TYPES[arg2]
    if not v26 then
        return nil
    end
    return tbl.addESP({
        Name = v26.name,
        Model = arg,
        Color = v26.highlightColor,
        MaxDistance = tbl.ZOMBIE_ESP_RANGE,
        TextSize = 14,
        ESPType = "Highlight",
        FillColor = v26.highlightColor,
        OutlineColor = v26.highlightColor,
        FillTransparency = 0.5,
        OutlineTransparency = 0,
    })
end

tbl.removeZombieEffects = function(arg)
    local v26 = tbl.zombieEffects[arg]
    if v26 then
        tbl.destroyESP(v26.esp)
        tbl.zombieEffects[arg] = nil
    end
end

tbl.clearAllZombieEffects = function()
    for k in tbl.zombieEffects, nil, nil do
        tbl.removeZombieEffects(k)
    end
end

tbl.updateZombieESP = function()
    local flag = false
    for _, v26 in tbl.zombieEspEnabled, nil, nil do
        if v26 then
            flag = true
            break
        end
    end
    if not flag then
        tbl.clearAllZombieEffects()
        return
    end
    local character = localPlayer.Character
    character = character and character:FindFirstChild("HumanoidRootPart")
    character = character and character.Position
    if not character then
        tbl.clearAllZombieEffects()
        return
    end

    for k, v26 in tbl.zombieEffects, nil, nil do
        if not k.Parent or v26.esp == nil or v26.esp.Deleted then
            tbl.removeZombieEffects(k)
        end
    end

    local tbl7 = {}
    local camera = workspace:FindFirstChild("Camera")
    if camera then
        for _, v26 in camera:GetDescendants() do
            if v26:IsA("Model") and v26.Name:find("Zombie") then
                table.insert(tbl7, v26)
            end
        end
    end
    local zombies = workspace:FindFirstChild("Zombies")
    if zombies then
        for _, v26 in zombies:GetChildren() do
            if v26:IsA("Model") and v26.Name:find("Zombie") then
                table.insert(tbl7, v26)
            end
        end
    end

    for _, v26 in tbl7, nil, nil do
        local humanoidRootPart = v26:FindFirstChild("HumanoidRootPart") or v26:FindFirstChild("Head") or v26:FindFirstChild("Torso")
        if humanoidRootPart then
            local magnitude = (humanoidRootPart.Position - character).Magnitude
            local v27 = tbl.getZombieTypeKey(v26)
            local v28 = v27 and tbl.zombieEspEnabled[v27]
            local v29 = tbl.zombieEffects[v26]

            if v28 and magnitude <= tbl.ZOMBIE_ESP_RANGE then
                local flag2 = v29 ~= nil
                local deleted
                if flag2 then
                    deleted = v29.esp == nil or v29.esp.Deleted or v29.typeKey ~= v27
                else
                    deleted = flag2
                end
                if deleted then
                    tbl.removeZombieEffects(v26)
                    v29 = nil
                end
                local v30
                if v29 == nil then
                    local v31 = tbl.createZombieESP(v26, v27)
                    if v31 == nil then
                        v30 = v29
                    else
                        tbl.zombieEffects[v26] = { esp = v31, typeKey = v27 }
                        v30 = tbl.zombieEffects[v26]
                    end
                else
                    v30 = v29
                end
                if v30 ~= nil then
                    v30.esp.CurrentSettings.Name = tbl.ZOMBIE_TYPES[v27].name
                end
            elseif v29 ~= nil then
                tbl.removeZombieEffects(v26)
            end
        end
    end
end

tbl.getPlayerTeam = function(arg)
    if arg.Team then
        return arg.Team
    end
    local attribute = arg:GetAttribute("Team")
    if attribute then
        return attribute
    end
    return nil
end

tbl.isSameTeam = function(arg)
    if not tbl.playerEspTeamCheck then
        return false
    end
    local v26 = tbl.getPlayerTeam(localPlayer)
    local v27 = tbl.getPlayerTeam(arg)
    if v26 and v27 then
        return v26 == v27
    end
    return false
end

tbl.getColorsForPlayer = function(arg)
    if not tbl.playerEspTeamCheck then
        return { highlight = color(255, 255, 255), dot = color(160, 160, 160), name = color(255, 255, 255) }
    end
    if tbl.isSameTeam(arg) then
        return { highlight = color(100, 150, 255), dot = color(0, 30, 180), name = color(100, 150, 255) }
    end
    return { highlight = color(255, 100, 100), dot = color(180, 0, 0), name = color(255, 100, 100) }
end

tbl.updatePlayerESP = function(arg)
    local v26 = tbl.playerEffects[arg]

    if not tbl.playerEspEnabled then
        if v26 ~= nil then
            tbl.destroyESP(v26.esp)
            tbl.playerEffects[arg] = nil
            tbl.playerESPModels[arg] = nil
        end
        return
    end

    local character = arg.Character
    if not character or character == localPlayer.Character then
        if v26 ~= nil then
            tbl.destroyESP(v26.esp)
            tbl.playerEffects[arg] = nil
            tbl.playerESPModels[arg] = nil
        end
        return
    end

    if not character:FindFirstChild("HumanoidRootPart") then
        return
    end

    if v26 ~= nil and (v26.Deleted or tbl.playerESPModels[arg] ~= character) then
        tbl.destroyESP(v26.esp)
        tbl.playerEffects[arg] = nil
        v26 = nil
    end

    local v27 = tbl.getColorsForPlayer(arg)

    if v26 == nil then
        local v29 = tbl.addESP({
            Name = arg.Name,
            Model = character,
            Color = v27.highlight,
            MaxDistance = 300,
            TextSize = 14,
            ESPType = "Highlight",
            FillColor = v27.highlight,
            OutlineColor = v27.highlight,
            FillTransparency = 0.5,
            OutlineTransparency = 0,
        })
        if v29 == nil then
            return
        end
        tbl.playerEffects[arg] = { esp = v29 }
        tbl.playerESPModels[arg] = character
        return
    end

    local currentSettings = v26.esp.CurrentSettings
    if currentSettings then
        currentSettings.Name = arg.Name
        currentSettings.Color = v27.highlight
        currentSettings.FillColor = v27.highlight
        currentSettings.OutlineColor = v27.highlight
    end
end

-- 每 0.3 秒轮询一次（手机端优化）
task.spawn(function()
    while true do
        pcall(function()
            tbl.updateZombieESP()
            for _, v26 in v4:GetPlayers() do
                if v26 ~= localPlayer then
                    tbl.updatePlayerESP(v26)
                end
            end
        end)
        task.wait(0.3)
    end
end)

v4.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.3)
        if tbl.playerEspEnabled then
            tbl.updatePlayerESP(player)
        end
    end)
end)

v4.PlayerRemoving:Connect(function(player)
    local v26 = tbl.playerEffects[player]
    if v26 then
        tbl.destroyESP(v26.esp)
    end
    tbl.playerEffects[player] = nil
    tbl.playerESPModels[player] = nil
end)

-- ============================================
-- 去雾（完全照原脚本）
-- ============================================
tbl.noFogEnabled = false
tbl.noFogOriginal = {}
tbl.noFogOriginalsSaved = false
tbl.noFogAtmosphereBackup = {}
tbl.noFogConns = {}
tbl.noFogDebounce = false

tbl.saveNoFogOriginal = function()
    if tbl.noFogOriginalsSaved then
        return
    end
    pcall(function()
        tbl.noFogOriginal = { FogEnd = v9.FogEnd, FogStart = v9.FogStart }
        tbl.noFogOriginalsSaved = true
    end)
end

tbl.saveNoFogOriginal()

tbl.applyNoFog = function()
    pcall(function()
        v9.FogEnd = 100000
        v9.FogStart = 0
        tbl.noFogAtmosphereBackup = {}
        for _, v26 in v9:GetDescendants() do
            if v26:IsA("Atmosphere") then
                table.insert(tbl.noFogAtmosphereBackup, { Instance = v26, Parent = v26.Parent })
                v26.Parent = nil
            end
        end
    end)
end

tbl.restoreNoFog = function()
    pcall(function()
        v9.FogEnd = tbl.noFogOriginal.FogEnd or 100000
        v9.FogStart = tbl.noFogOriginal.FogStart or 0
        for _, v26 in tbl.noFogAtmosphereBackup, nil, nil do
            if v26.Instance and v26.Parent then
                v26.Instance.Parent = v26.Parent
            end
        end
        tbl.noFogAtmosphereBackup = {}
    end)
end

local function fn8()
    if not tbl.noFogEnabled or tbl.noFogDebounce then
        return
    end
    tbl.noFogDebounce = true
    task.delay(0.1, function()
        tbl.noFogDebounce = false
        if tbl.noFogEnabled then
            pcall(tbl.applyNoFog)
        end
    end)
end

tbl.startNoFogMonitor = function()
    for _, v26 in tbl.noFogConns, nil, nil do
        pcall(function()
            v26:Disconnect()
        end)
    end
    table.clear(tbl.noFogConns)
    for _, v26 in { "FogEnd", "FogStart" }, nil, nil do
        pcall(function()
            table.insert(tbl.noFogConns, v9:GetPropertyChangedSignal(v26):Connect(fn8))
        end)
    end
    pcall(function()
        table.insert(tbl.noFogConns, v9.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Atmosphere") then
                fn8()
            end
        end))
    end)
end

tbl.stopNoFogMonitor = function()
    for _, v26 in tbl.noFogConns, nil, nil do
        pcall(function()
            v26:Disconnect()
        end)
    end
    table.clear(tbl.noFogConns)
    tbl.noFogDebounce = false
end

-- ============================================
-- 原生 UI（手机端）
-- ============================================
local COLORS = {
    bg      = color(10, 15, 25),
    bg2     = color(18, 26, 40),
    border  = color(45, 90, 140),
    accent  = color(80, 200, 255),
    text    = color(220, 220, 220),
    on      = color(80, 200, 255),
    off     = color(55, 65, 80),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkinHubLiteUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 400)
mainFrame.Position = UDim2.new(0, 20, 0, 100)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COLORS.border
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

local titleBar = Instance.new("Frame")
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
closeBtn.BackgroundColor3 = color(200, 60, 60)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

v6.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

v6.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local content = Instance.new("ScrollingFrame")
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

local order = 0
local function nextOrder()
    order = order + 1
    return order
end

createSection("战斗", nextOrder())
createToggleRow("近战强制爆头", false, function(state)
    tbl.headshotEnabled = state
    tbl.updateHitHooks()
end, nextOrder())
createToggleRow("移除血液粒子", false, function(state)
    tbl.removeBloodEnabled = state
    tbl.updateHitHooks()
end, nextOrder())

createSection("环境", nextOrder())
createToggleRow("去雾", false, function(state)
    tbl.noFogEnabled = state
    if state then
        tbl.applyNoFog()
        tbl.startNoFogMonitor()
    else
        tbl.stopNoFogMonitor()
        tbl.restoreNoFog()
    end
end, nextOrder())

createSection("僵尸透视", nextOrder())
createToggleRow("红眼", false, function(state)
    tbl.zombieEspEnabled.Eye = state
end, nextOrder())
createToggleRow("胸甲骑兵", false, function(state)
    tbl.zombieEspEnabled.Sword = state
end, nextOrder())
createToggleRow("自爆", false, function(state)
    tbl.zombieEspEnabled.Barrel = state
end, nextOrder())
createToggleRow("无头骑士", false, function(state)
    tbl.zombieEspEnabled.Headless = state
end, nextOrder())

createSection("玩家透视", nextOrder())
createToggleRow("高亮玩家", false, function(state)
    tbl.playerEspEnabled = state
    if not state then
        for _, e in tbl.playerEffects do
            tbl.destroyESP(e.esp)
        end
        tbl.playerEffects = {}
        tbl.playerESPModels = {}
    end
end, nextOrder())
createToggleRow("队伍检测", false, function(state)
    tbl.playerEspTeamCheck = state
end, nextOrder())

closeBtn.MouseButton1Click:Connect(function()
    pcall(tbl.clearAllZombieEffects)
    for _, e in tbl.playerEffects do
        tbl.destroyESP(e.esp)
    end
    tbl.playerEffects = {}
    tbl.playerESPModels = {}
    if tbl.noFogEnabled then
        tbl.noFogEnabled = false
        tbl.stopNoFogMonitor()
        tbl.restoreNoFog()
    end
    screenGui:Destroy()
    getgenv().SkinHubLoaded = nil
end)

tbl.notify("SkinHUB Lite 已加载", 3)