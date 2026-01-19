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
--// AIM ASSIST (FULL TABLE-DRIVEN)
--// =========================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local aimCfg = getgenv().zinc['Aim Assist']
local aimActive = false
local aimTarget = nil

local Mouse = LocalPlayer:GetMouse()

-- Helper: find closest part from a list
local function getClosestPart(char, parts)
    for _, name in ipairs(parts) do
        local p = char:FindFirstChild(name)
        if p then return p end
    end
    return nil
end

-- Helper: check if target passes table checks
local function passesChecks(target)
    local char = target.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    for _, check in ipairs(aimCfg.Checks) do
        if check == 'Knocked' and hum:FindFirstChild('Knocked') then
            return false
        elseif check == 'Grabbed' and hum:FindFirstChild('Grabbed') then
            return false
        elseif check == 'Vehicle' and char:FindFirstChildOfClass('VehicleSeat') then
            return false
        elseif check == 'Wall' then
            local root = char:FindFirstChild('HumanoidRootPart')
            if root then
                local ray = Ray.new(Camera.CFrame.Position, (root.Position - Camera.CFrame.Position).Unit * 500)
                local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
                if hit and not hit:IsDescendantOf(char) then
                    return false
                end
            end
        end
    end

    return true
end

-- Get closest target within FOV
local function getClosestTarget()
    local closest, dist = nil, aimCfg.Fov and aimCfg.Fov.Enabled and aimCfg.Fov.Value or math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and passesChecks(plr) then
            local char = plr.Character
            if char then
                local part = getClosestPart(char, aimCfg['Hit Location'].Parts)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                        local delta = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if delta < dist then
                            dist = delta
                            closest = plr
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- Toggle Aim Assist
UserInputService.InputBegan:Connect(function(i, gp)
    if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if not aimCfg.Enabled then return end
    if i.KeyCode.Name:lower() == aimCfg.Keybind:lower() then
        aimActive = not aimActive
        if aimActive then
            aimTarget = getClosestTarget()
            if not aimTarget then aimActive = false end
        else
            aimTarget = nil
        end
        print("Aim Assist Active:", aimActive)
    end
end)

-- Aim Assist Render Loop
RunService.RenderStepped:Connect(function()
    if not aimActive or not aimTarget then return end

    local char = aimTarget.Character
    if not char then
        aimActive = false
        aimTarget = nil
        return
    end

    local part = getClosestPart(char, aimCfg['Hit Location'].Parts)
    if not part then return end

    -- Prediction
    local pred = aimCfg.Prediction
    local predictedPos = part.Position + (part.Velocity * Vector3.new(pred.X, pred.Y, pred.Z))

    -- Camera type check
    local camType = Camera.CameraType
    if (camType == Enum.CameraType.Custom and not aimCfg.Value.ThirdPerson) or
       (camType == Enum.CameraType.Attach and not aimCfg.Value.FirstPerson) then
        return
    end

    -- Smooth aim
    local smooth = math.clamp(aimCfg.Value.Smoothness or 0.1, 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.new(Camera.CFrame.Position, predictedPos),
        smooth
    )

    -- Optional FOV drawing (if you implement it)
    if aimCfg.ShowFov then
        -- Drawing code goes here
    end
end)


--// =========================
--// SPEED MODIFICATIONS
--// =========================

local spdCfg = getgenv().zinc["Speed Modifications"].Options
if spdCfg.Enabled then
    local Humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
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
            print("Speed Mod:", enabled and speed or 16)
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
--// TRIGGER BOT (ZINC – NO PREDICTION)
--// =========================
local TriggerBot = cfg["Trigger bot"]
local mouseHeld = false

-- Input tracking (M1 hold)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if TriggerBot.Keybind.Bind:lower() == "m1" then
            mouseHeld = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseHeld = false
    end
end)

-- Raycast params
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist

-- Trigger Bot loop
task.spawn(function()
    while task.wait(TriggerBot.Delay.Value) do
        if not TriggerBot.Enabled then continue end
        if not mouseHeld then continue end
        if not Character then continue end

        -- Weapon check
        local tool = Character:FindFirstChildOfClass("Tool")
        if not tool or not table.find(TriggerBot.Weapons, tool.Name) then
            continue
        end

        rayParams.FilterDescendantsInstances = {Character}

        -- Raycast from camera
        local result = workspace:Raycast(
            Camera.CFrame.Position,
            Camera.CFrame.LookVector * cfg.Range["Trigger bot"],
            rayParams
        )

        if result and result.Instance then
            local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
            local hum = hitModel and hitModel:FindFirstChildOfClass("Humanoid")

            if hum and hum.Health > 0 then
                -- THIS is the important part:
                -- Trigger the SAME shot Silent Aim already modifies
                mouse1press()
                task.wait()
                mouse1release()
            end
        end
    end
end)


--// =========================
--// ESP – CLEAN, SHARP, BOTTOM (TABLE DRIVEN)
--// =========================
if cfg.ESP and cfg.ESP.Enabled then
    local ESPcfg = cfg.ESP
    local NameCfg = ESPcfg.NameESP
    local DistCfg = ESPcfg.DistanceESP

    local esp = {}
    local distanceCache = {}

    local SMOOTHNESS = 0.35
    local FOOT_OFFSET = Vector3.new(0, -3.1, 0)

    local function createESP(plr)
        if plr == LocalPlayer or esp[plr] then return end

        local text = Drawing.new("Text")
        text.Center = true
        text.Font = 2 -- SHARPEST
        text.Size = NameCfg.TextSize
        text.Color = NameCfg.Color
        text.Transparency = 1
        text.Visible = false

        local outline
        if NameCfg.Outline then
            outline = Drawing.new("Text")
            outline.Center = true
            outline.Font = 2
            outline.Size = NameCfg.TextSize
            outline.Color = Color3.new(0, 0, 0)
            outline.Transparency = 0.7
            outline.Visible = false
        end

        esp[plr] = {
            Text = text,
            Outline = outline,
            Pos = Vector2.zero
        }
    end

    local function removeESP(plr)
        local obj = esp[plr]
        if obj then
            obj.Text:Remove()
            if obj.Outline then obj.Outline:Remove() end
            esp[plr] = nil
            distanceCache[plr] = nil
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    Players.PlayerAdded:Connect(createESP)
    Players.PlayerRemoving:Connect(removeESP)

    -- Distance updater (low frequency)
    task.spawn(function()
        while task.wait(0.25) do
            for plr in pairs(esp) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    distanceCache[plr] =
                        (Camera.CFrame.Position - hrp.Position).Magnitude
                end
            end
        end
    end)

    -- Render loop
    RunService.RenderStepped:Connect(function()
        for plr, data in pairs(esp) do
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local worldPos = hrp.Position + FOOT_OFFSET
                local pos, onScreen = Camera:WorldToViewportPoint(worldPos)

                if onScreen then
                    local target = Vector2.new(pos.X, pos.Y)
                    data.Pos = data.Pos:Lerp(target, SMOOTHNESS)

                    local dist = distanceCache[plr] or 0

                    -- Distance-based size scaling (NO PIXELS)
                    local baseSize = NameCfg.TextSize
                    local scaledSize = math.clamp(
                        baseSize * (1 - (dist / 600)),
                        baseSize * 0.7,
                        baseSize
                    )
                    scaledSize = math.floor(scaledSize)

                    local label = ""

                    if NameCfg.Enabled then
                        label = plr.Name
                    end

                    if DistCfg.Enabled then
                        label = label ~= "" and
                            (label .. " [" .. math.floor(dist) .. "]") or
                            ("[" .. math.floor(dist) .. "]")
                    end

                    data.Text.Text = label
                    data.Text.Size = scaledSize
                    data.Text.Color = NameCfg.Color
                    data.Text.Position = data.Pos
                    data.Text.Visible = true

                    if data.Outline then
                        data.Outline.Text = label
                        data.Outline.Size = scaledSize
                        data.Outline.Position = data.Pos + Vector2.new(1, 1)
                        data.Outline.Visible = true
                    end
                else
                    data.Text.Visible = false
                    if data.Outline then data.Outline.Visible = false end
                end
            else
                data.Text.Visible = false
                if data.Outline then data.Outline.Visible = false end
            end
        end
    end)
end

