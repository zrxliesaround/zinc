--// ZINC HUB – CONFIG-CORRECT SOURCE
--// Matches getgenv().zinc table exactly
--// Da Hood safe – no slowdown

if _G.ZINC_LOADED then return end
_G.ZINC_LOADED = true

local cfg = getgenv().zinc
if not cfg then return warn("[ZINC] Config not found") end

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Character refs
local Character, Humanoid, HRP
local function onChar(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
end
if LocalPlayer.Character then onChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(onChar)

--// Utility: Closest player + closest part
local function getClosestPlayer(range)
    if not HRP then return end
    local closest, dist = nil, range or math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local mag = (HRP.Position - hrp.Position).Magnitude
                if mag < dist then
                    closest, dist = plr, mag
                end
            end
        end
    end
    return closest
end

local function getClosestPart(char, parts)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local closest, dist = nil, math.huge
    for _, name in ipairs(parts) do
        local part = char:FindFirstChild(name)
        if part then
            local mag = (part.Position - hrp.Position).Magnitude
            if mag < dist then
                closest, dist = part, mag
            end
        end
    end
    return closest
end

--// =========================
--// SILENT AIM
--// =========================
if cfg["Silent Aim"] and cfg["Silent Aim"].Enabled then
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        if getnamecallmethod() == "FireServer"
            and tostring(self):lower():find("shoot") then

            local target = getClosestPlayer(cfg.Range["Silent Aim"])
            if target and target.Character then
                local part = getClosestPart(
                    target.Character,
                    cfg["Silent Aim"]["Hit Location"].Parts
                )
                if part then
                    local pred = cfg["Silent Aim"].Prediction.Sets
                    args[2] = part.Position +
                        (part.Velocity * Vector3.new(pred.X, pred.Y, pred.Z))
                    return old(self, unpack(args))
                end
            end
        end
        return old(self, ...)
    end)

    setreadonly(mt, true)
end

--// =========================
--// CAMLOCK
--// =========================
local camCfg = cfg.Camlock
local camActive = false
local camTarget
local camKey = camCfg.Keybind:lower()
local smooth = math.clamp(camCfg.Value.Snappiness * 0.15, 0.05, 0.25)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if i.KeyCode.Name:lower() == camKey then
        camActive = not camActive
        camTarget = camActive and getClosestPlayer(cfg.Range.Camlock) or nil
    end
end)

RunService.RenderStepped:Connect(function()
    if camActive and camTarget and camTarget.Character then
        local part = getClosestPart(
            camTarget.Character,
            camCfg["Hit Location"].Parts
        )
        if part then
            local pred = camCfg.Prediction
            local pos = part.Position +
                (part.Velocity * Vector3.new(pred.X, pred.Y, pred.Z))
            Camera.CFrame = Camera.CFrame:Lerp(
                CFrame.new(Camera.CFrame.Position, pos),
                smooth
            )
        end
    end
end)

--// =========================
--// SPEED (NO LAG)
--// =========================
local spdCfg = cfg["Speed Modifications"].Options
if spdCfg.Enabled then
    local speed = spdCfg.DefaultSpeed
    local enabled = false

    local function apply()
        if Humanoid then
            Humanoid.WalkSpeed = enabled and speed or 16
        end
    end

    UserInputService.InputBegan:Connect(function(i, gp)
        if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local k = i.KeyCode.Name
        if k == spdCfg.Keybinds.ToggleMovement then
            enabled = not enabled
            apply()
        elseif k == spdCfg.Keybinds["Speed +5"] then
            speed += 5
            if enabled then apply() end
        elseif k == spdCfg.Keybinds["Speed -5"] then
            speed = math.max(16, speed - 5)
            if enabled then apply() end
        end
    end)
end

--// =========================
--// TRIGGER BOT
--// =========================
if cfg["Trigger bot"] and cfg["Trigger bot"].Enabled then
    local mouseDown = false

    UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseDown = true
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseDown = false
        end
    end)

    task.spawn(function()
        while task.wait(cfg["Trigger bot"].Delay.Value) do
            if not mouseDown or not Character then continue end

            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {Character}
            rayParams.FilterType = Enum.RaycastFilterType.Blacklist

            local res = workspace:Raycast(
                Camera.CFrame.Position,
                Camera.CFrame.LookVector * cfg.Range["Trigger bot"],
                rayParams
            )

            if res and res.Instance then
                local hum = res.Instance.Parent:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    pcall(mouse1click)
                end
            end
        end
    end)
end

--// =========================
--// ESP – CLEAN NAME + DISTANCE (HEAD ANCHORED)
--// =========================
if cfg.ESP and cfg.ESP.Enabled then
    local esp = {}
    local distanceCache = {}

    local SMOOTHNESS = 0.25
    local HEAD_OFFSET = Vector3.new(0, 0.6, 0)

    local function createESP(plr)
        if plr == LocalPlayer or esp[plr] then return end

        local shadow = Drawing.new("Text")
        shadow.Center = true
        shadow.Font = 2
        shadow.Size = cfg.ESP.NameESP.TextSize + 3
        shadow.Color = Color3.new(0, 0, 0)
        shadow.Transparency = 0.6
        shadow.Visible = false

        local text = Drawing.new("Text")
        text.Center = true
        text.Font = 2
        text.Size = cfg.ESP.NameESP.TextSize + 3
        text.Color = cfg.ESP.NameESP.Color
        text.Visible = false

        esp[plr] = {
            Text = text,
            Shadow = shadow,
            ScreenPos = Vector2.zero
        }
    end

    local function removeESP(plr)
        if esp[plr] then
            esp[plr].Text:Remove()
            esp[plr].Shadow:Remove()
            esp[plr] = nil
            distanceCache[plr] = nil
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    Players.PlayerAdded:Connect(createESP)
    Players.PlayerRemoving:Connect(removeESP)

    task.spawn(function()
        while task.wait(0.25) do
            for plr in pairs(esp) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    distanceCache[plr] =
                        math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
                end
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        for plr, data in pairs(esp) do
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if head and hum and hum.Health > 0 then
                local worldPos = head.Position + HEAD_OFFSET
                local pos, onScreen = Camera:WorldToViewportPoint(worldPos)

                if onScreen then
                    local target = Vector2.new(pos.X, pos.Y)
                    data.ScreenPos = data.ScreenPos:Lerp(target, SMOOTHNESS)

                    local dist = distanceCache[plr] or 0
                    local label = plr.Name .. " [" .. dist .. "]"

                    data.Text.Text = label
                    data.Shadow.Text = label

                    data.Text.Position = data.ScreenPos
                    data.Shadow.Position = data.ScreenPos + Vector2.new(1, 1)

                    data.Text.Visible = true
                    data.Shadow.Visible = true
                else
                    data.Text.Visible = false
                    data.Shadow.Visible = false
                end
            else
                data.Text.Visible = false
                data.Shadow.Visible = false
            end
        end
    end)
end
