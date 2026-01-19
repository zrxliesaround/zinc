--// ZINC – Da Hood Optimized Rewrite
--// Safe • Smooth • No Slowdown

if _G.ZINC_LOADED then return end
_G.ZINC_LOADED = true

local config = getgenv().zinc or {}

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Character Handling
local Character, Humanoid, HRP

local function onCharacter(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
end

if LocalPlayer.Character then
    onCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacter)

--// Utility: Closest Player
local function getClosestPlayer(range)
    if not HRP then return nil end
    local closest, dist = nil, range or math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local mag = (HRP.Position - hrp.Position).Magnitude
                if mag < dist then
                    closest, dist = plr, mag
                end
            end
        end
    end
    return closest
end

--// =========================
--// SILENT AIM (SAFE)
--// =========================
if config["Silent Aim"] and config["Silent Aim"].Enabled then
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        if getnamecallmethod() == "FireServer" and tostring(self):lower():find("shoot") then
            local target = getClosestPlayer(config.Range and config.Range["Silent Aim"] or 250)
            if target and target.Character then
                local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    args[2] = hrp.Position
                    return old(self, unpack(args))
                end
            end
        end
        return old(self, ...)
    end)

    setreadonly(mt, true)
end

--// =========================
--// CAMLOCK (SMOOTH)
--// =========================
local camlockActive = false
local camlockTarget
local camlockKey = (config.Camlock and config.Camlock.Keybind or "q"):lower()
local camlockSmooth = 0.15

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode.Name:lower() == camlockKey then
        camlockActive = not camlockActive
        camlockTarget = camlockActive and getClosestPlayer(config.Range and config.Range.Camlock or 250) or nil
    end
end)

RunService.RenderStepped:Connect(function()
    if camlockActive and camlockTarget and camlockTarget.Character then
        local hrp = camlockTarget.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local cf = CFrame.new(Camera.CFrame.Position, hrp.Position)
            Camera.CFrame = Camera.CFrame:Lerp(cf, camlockSmooth)
        end
    end
end)

--// =========================
--// SPEED (NO SLOWDOWN)
--// =========================
local speedCfg = config["Speed Modifications"] and config["Speed Modifications"].Options
if speedCfg and speedCfg.Enabled then
    local toggled = false
    local speed = math.clamp(speedCfg.DefaultSpeed or 20, 16, 22)

    local toggleKey = (speedCfg.Keybinds.ToggleMovement or "z"):lower()
    local upKey = (speedCfg.Keybinds["Speed +5"] or "m"):lower()
    local downKey = (speedCfg.Keybinds["Speed -5"] or "n"):lower()

    local function applySpeed()
        if Humanoid then
            Humanoid.WalkSpeed = toggled and speed or 16
        end
    end

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode.Name:lower()

        if key == toggleKey then
            toggled = not toggled
            applySpeed()
        elseif key == upKey then
            speed = math.min(speed + 1, 22)
            if toggled then applySpeed() end
        elseif key == downKey then
            speed = math.max(speed - 1, 16)
            if toggled then applySpeed() end
        end
    end)

    if Humanoid then applySpeed() end
end

--// =========================
--// TRIGGER BOT (THROTTLED)
--// =========================
if config["Trigger bot"] and config["Trigger bot"].Enabled then
    local mouseDown = false

    UserInputService.InputBegan:Connect(function(i, gp)
        if not gp and i.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseDown = true
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseDown = false
        end
    end)

    task.spawn(function()
        while task.wait(0.05) do
            if not mouseDown or not Character then continue end

            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {Character}
            rayParams.FilterType = Enum.RaycastFilterType.Blacklist

            local result = workspace:Raycast(
                Camera.CFrame.Position,
                Camera.CFrame.LookVector * (config.Range and config.Range["Trigger bot"] or 250),
                rayParams
            )

            if result and result.Instance then
                local hum = result.Instance.Parent:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    pcall(mouse1click)
                end
            end
        end
    end)
end

--// =========================
--// ESP (OPTIMIZED)
--// =========================
if config.ESP and config.ESP.Enabled then
    local esp = {}

    local function addESP(plr)
        if esp[plr] or plr == LocalPlayer then return end
        esp[plr] = Drawing.new("Text")
        esp[plr].Size = 13
        esp[plr].Center = true
        esp[plr].Outline = true
        esp[plr].Color = Color3.new(1,1,1)
    end

    for _, p in ipairs(Players:GetPlayers()) do addESP(p) end
    Players.PlayerAdded:Connect(addESP)

    Players.PlayerRemoving:Connect(function(p)
        if esp[p] then
            esp[p]:Remove()
            esp[p] = nil
        end
    end)

    task.spawn(function()
        while task.wait(0.1) do
            for plr, text in pairs(esp) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")

                if hrp and hum and hum.Health > 0 then
                    local pos, onscreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onscreen then
                        text.Text = plr.Name
                        text.Position = Vector2.new(pos.X, pos.Y)
                        text.Visible = true
                    else
                        text.Visible = false
                    end
                else
                    text.Visible = false
                end
            end
        end
    end)
end
