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
--// SILENT AIM (ZINC v1)
--// =========================
if cfg["Silent Aim"] and cfg["Silent Aim"].Enabled then
    local ZA = cfg["Silent Aim"]
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    -- Closest player helper (FOV + checks)
    local function passesChecks(plr)
        if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then return false end
        if plr.Team == LocalPlayer.Team then return false end
        for _, check in ipairs(ZA.Checks or {}) do
            if check == "Knocked" and plr:FindFirstChild("Knocked") then return false end
            if check == "Grabbed" and plr:FindFirstChild("Grabbed") then return false end
            if check == "Vehicle" then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.SeatPart then return false end
            end
        end
        return true
    end

    local function getClosestPlayerFOV(range)
        local bestAngle = math.huge
        local bestPlayer = nil
        local camPos = Camera.CFrame.Position
        local lookVec = Camera.CFrame.LookVector
        local maxFov = (ZA.Fov and ZA.Fov.Enabled and ZA.Fov.Value) or math.huge

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and passesChecks(plr) then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dir = (hrp.Position - camPos).Unit
                    local angle = math.deg(math.acos(lookVec:Dot(dir)))
                    if angle < bestAngle and angle <= maxFov then
                        bestAngle = angle
                        bestPlayer = plr
                    end
                end
            end
        end
        return bestPlayer
    end

    -- Predict part position
    local function predictPos(plr)
        local parts = ZA["Hit Location"] and ZA["Hit Location"].Parts or {}
        local bestPart, bestDist, bestPos = nil, math.huge, nil
        local mousePos2d = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)

        for _, name in ipairs(parts) do
            local part = plr.Character:FindFirstChild(name)
            if part then
                local sp, onScreen = Camera:WorldToScreenPoint(part.Position)
                if onScreen then
                    local part2d = Vector2.new(sp.X, sp.Y)
                    local dist = (part2d - mousePos2d).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestPart = part
                        bestPos = part.Position
                    end
                end
            end
        end

        if bestPart then
            local vel = bestPart.Velocity or Vector3.zero
            local pred = ZA.Prediction.Sets or {X=0, Y=0, Z=0}
            return bestPos + Vector3.new(vel.X * pred.X, vel.Y * pred.Y, vel.Z * pred.Z)
        end
        return bestPos
    end

    -- Hook FireServer for shooting
    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if method == "FireServer" and tostring(self):lower():find("shoot") then
            local target = getClosestPlayerFOV(cfg.Range["Silent Aim"])
            if target and target.Character then
                local partPos = predictPos(target)
                if partPos then
                    args[2] = partPos -- Replace bullet target
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
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
--// TRIGGER BOT (ZINC v1 FIXED)
--// =========================
if cfg["Trigger bot"] and cfg["Trigger bot"].Enabled then
    local TB = cfg["Trigger bot"]
    local mouseDown = false

    -- Track mouse input
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and TB.Keybind.Bind:lower() == "m1" then
            if TB.Keybind["Keybind Mode"]:lower() == "hold" then
                mouseDown = true
            else
                mouseDown = not mouseDown -- toggle mode
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and TB.Keybind.Bind:lower() == "m1" then
            if TB.Keybind["Keybind Mode"]:lower() == "hold" then
                mouseDown = false
            end
        end
    end)

    -- Trigger Bot loop
    task.spawn(function()
        while task.wait(TB.Delay.Value) do
            if not mouseDown or not Character then continue end

            -- Make sure player has the correct weapon
            local weapon = Character:FindFirstChildOfClass("Tool")
            if not weapon or not table.find(TB.Weapons, weapon.Name) then continue end

            -- Raycast in front of camera
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
                    pcall(mouse1click) -- Fire left click
                end
            end
        end
    end)
end

--// =========================
--// ESP – CLEAN NAME + DISTANCE (ABOVE HEAD)
--// =========================
if cfg.ESP and cfg.ESP.Enabled then
    local esp = {}
    local distanceCache = {}

    local SMOOTHNESS = 0.35
    local HEAD_OFFSET = Vector3.new(0, 2.3, 0) -- ABOVE head

    local TEXT_SIZE = cfg.ESP.NameESP.TextSize + 9 -- bigger & readable

    local function createESP(plr)
        if plr == LocalPlayer or esp[plr] then return end

        -- Shadow (for clarity)
        local shadow = Drawing.new("Text")
        shadow.Center = true
        shadow.Font = 0 -- CLEANEST FONT
        shadow.Size = TEXT_SIZE
        shadow.Color = Color3.new(0, 0, 0)
        shadow.Transparency = 0.7
        shadow.Visible = false

        -- Main text
        local text = Drawing.new("Text")
        text.Center = true
        text.Font = 0 -- CLEANEST FONT
        text.Size = TEXT_SIZE
        text.Color = Color3.fromRGB(255, 255, 255) -- PURE WHITE
        text.Transparency = 1
        text.Visible = false

        esp[plr] = {
            Text = text,
            Shadow = shadow,
            Pos = Vector2.zero
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

    -- Distance updater (low frequency = no lag)
    task.spawn(function()
        while task.wait(0.3) do
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

    -- Smooth render
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
                    data.Pos = data.Pos:Lerp(target, SMOOTHNESS)

                    local dist = distanceCache[plr] or 0
                    local label = plr.Name .. " [" .. dist .. "]"

                    data.Text.Text = label
                    data.Shadow.Text = label

                    data.Text.Position = data.Pos
                    data.Shadow.Position = data.Pos + Vector2.new(1, 1)

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

