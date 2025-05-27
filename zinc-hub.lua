local config = getgenv().zinc
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Helper: get closest player in range for Silent Aim or Camlock
local function getClosestPlayer(range)
    local closest, dist = nil, range or math.huge
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local localPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = player.Character.HumanoidRootPart.Position
            local mag = (localPos - pos).Magnitude
            if mag < dist then
                closest, dist = player, mag
            end
        end
    end
    return closest
end

-- Silent Aim Hook
if config['Silent Aim'] and config['Silent Aim'].Enabled then
    print("[Zinc] Silent Aim enabled")
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if method == "FireServer" and tostring(self):lower():find("shoot") then
            local target = getClosestPlayer(config.Range['Silent Aim'])
            if target and target.Character then
                -- Find closest hit part defined in config to target's character
                local partsList = config['Silent Aim']['Hit Location'].Parts
                local closestPart, closestDist = nil, math.huge
                local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                for _, partName in ipairs(partsList) do
                    local part = target.Character:FindFirstChild(partName)
                    if part then
                        local distToHRP = (part.Position - hrp.Position).Magnitude
                        if distToHRP < closestDist then
                            closestPart = part
                            closestDist = distToHRP
                        end
                    end
                end
                if closestPart then
                    local pred = config['Silent Aim'].Prediction.Sets
                    pred = pred or {X=0, Y=0, Z=0}
                    -- Apply prediction vector to position
                    local predictedPos = closestPart.Position + closestPart.Velocity * Vector3.new(pred.X, pred.Y, pred.Z)
                    args[2] = predictedPos
                    -- Debug print to confirm
                    -- print("[Zinc] Silent Aim adjusted shot to", predictedPos)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end

-- Camlock (toggle with keybind even if Disabled initially)
local camlockActive = false
local camlockTarget = nil
local camlockKey = config['Camlock'] and config['Camlock'].Keybind or 'q'

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name:lower() == camlockKey:lower() then
        camlockActive = not camlockActive
        if camlockActive then
            camlockTarget = getClosestPlayer(config.Range and config.Range['Camlock'] or 250)
            print("[Zinc] Camlock activated on", camlockTarget and camlockTarget.Name or "none")
        else
            camlockTarget = nil
            print("[Zinc] Camlock deactivated")
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if camlockActive and camlockTarget and camlockTarget.Character then
        local hrp = camlockTarget.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
        end
    end
end)

-- Speed Modifications
local speedConfig = config['Speed Modifications'] and config['Speed Modifications'].Options
if speedConfig and speedConfig.Enabled then
    local toggled = false
    local speed = speedConfig.DefaultSpeed or 35
    local toggleKey = (speedConfig.Keybinds and speedConfig.Keybinds.ToggleMovement or 'z'):lower()
    local speedUpKey = (speedConfig.Keybinds and speedConfig.Keybinds['Speed +5'] or 'm'):lower()
    local speedDownKey = (speedConfig.Keybinds and speedConfig.Keybinds['Speed -5'] or 'n'):lower()

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode.Name:lower()
            if key == toggleKey then
                toggled = not toggled
                print("[Zinc] Speedwalk toggled:", toggled)
            elseif key == speedUpKey then
                speed = speed + 5
                print("[Zinc] Speed increased to:", speed)
            elseif key == speedDownKey then
                speed = math.max(0, speed - 5)
                print("[Zinc] Speed decreased to:", speed)
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            if toggled then
                LocalPlayer.Character.Humanoid.WalkSpeed = speed
            else
                LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
        end
    end)
end

-- Trigger Bot
if config['Trigger bot'] and config['Trigger bot'].Enabled then
    local mouseDown = false

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseDown = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseDown = false
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not mouseDown then return end

        local rayOrigin = Camera.CFrame.Position
        local rayDir = Camera.CFrame.LookVector * (config.Range and config.Range['Trigger bot'] or 250)

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

        local result = workspace:Raycast(rayOrigin, rayDir, raycastParams)
        if result and result.Instance and result.Instance.Parent then
            local humanoid = result.Instance.Parent:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                -- Try to fire mouse click event (replace if your exploit supports better way)
                pcall(function()
                    mouse1click()
                end)
            end
        end
    end)
end

-- ESP (simple)
if config.ESP and config.ESP.Enabled then
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Camera = workspace.CurrentCamera
    local LocalPlayer = Players.LocalPlayer

    local espObjects = {}

    local function createESP(player)
        if espObjects[player] then return end

        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = config.ESP.BoxESP.Color or Color3.fromRGB(255, 255, 255)
        box.Thickness = config.ESP.BoxESP.Thickness or 1
        box.Filled = config.ESP.BoxESP.Filled or false
        box.Transparency = config.ESP.BoxESP.Transparency or 0.5

        local healthBar = Drawing.new("Square")
        healthBar.Visible = false
        healthBar.Thickness = 1
        healthBar.Filled = true
        healthBar.Color = Color3.fromRGB(0, 255, 0)

        local tracer = Drawing.new("Line")
        tracer.Visible = false
        tracer.Thickness = config.ESP.Tracers.Thickness or 1
        tracer.Color = config.ESP.Tracers.Color or Color3.fromRGB(255, 255, 255)

        local name = Drawing.new("Text")
        name.Visible = false
        name.Center = true
        name.Outline = config.ESP.NameESP.Outline or true
        name.Size = config.ESP.NameESP.TextSize or 13
        name.Color = config.ESP.NameESP.Color or Color3.fromRGB(255, 255, 255)
        name.Font = 2

        local distance = Drawing.new("Text")
        distance.Visible = false
        distance.Center = true
        distance.Outline = true
        distance.Size = config.ESP.DistanceESP.TextSize or 13
        distance.Color = config.ESP.DistanceESP.Color or Color3.fromRGB(255, 255, 255)
        distance.Font = 2

        espObjects[player] = {
            Box = box,
            Health = healthBar,
            Tracer = tracer,
            Name = name,
            Distance = distance
        }
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createESP(player)
        end
    end

    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            createESP(player)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        if espObjects[player] then
            for _, obj in pairs(espObjects[player]) do
                obj:Remove()
            end
            espObjects[player] = nil
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not config.ESP.Enabled then
            for _, esp in pairs(espObjects) do
                for _, obj in pairs(esp) do
                    obj.Visible = false
                end
            end
            return
        end

        local originMap = {
            Bottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y),
            Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
            Top = Vector2.new(Camera.ViewportSize.X / 2, 0)
        }
        local origin = originMap[config.ESP.Tracers.Origin] or originMap.Bottom

        for player, esp in pairs(espObjects) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and humanoid and humanoid.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local height = 90
                    local width = 40
                    local boxPos = Vector2.new(pos.X - width / 2, pos.Y - height / 2)

                    -- Box ESP
                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = boxPos
                    esp.Box.Visible = config.ESP.BoxESP.Enabled

                    -- Health Bar
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    local barHeight = height * healthPercent
                    esp.Health.Size = Vector2.new(3, barHeight)
                    esp.Health.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (height - barHeight))
                    esp.Health.Color = Color3.fromRGB(255 - (healthPercent * 255), healthPercent * 255, 0)
                    esp.Health.Visible = config.ESP.BoxESP.Enabled

                    -- Tracers
                    esp.Tracer.From = origin
                    esp.Tracer.To = Vector2.new(pos.X, pos.Y + height / 2)
                    esp.Tracer.Visible = config.ESP.Tracers.Enabled

                    -- Name
                    esp.Name.Text = player.Name
                    esp.Name.Position = Vector2.new(pos.X, boxPos.Y - 16)
                    esp.Name.Visible = config.ESP.NameESP.Enabled

                    -- Distance
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    esp.Distance.Text = tostring(math.floor(dist))
                    esp.Distance.Position = Vector2.new(pos.X, boxPos.Y + height + 2)
                    esp.Distance.Visible = config.ESP.DistanceESP.Enabled
                else
                    for _, obj in pairs(esp) do
                        obj.Visible = false
                    end
                end
            else
                for _, obj in pairs(esp) do
                    obj.Visible = false
                end
            end
        end
    end)
end

