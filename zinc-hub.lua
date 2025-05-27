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
        box.Color = Color3.fromRGB(220, 220, 220)
        box.Thickness = 2
        box.Filled = false
        box.Transparency = 0.6

        local tracer = Drawing.new("Line")
        tracer.Visible = false
        tracer.Color = Color3.fromRGB(200, 200, 200)
        tracer.Thickness = 1

        local name = Drawing.new("Text")
        name.Visible = false
        name.Color = Color3.fromRGB(230, 230, 230)
        name.Outline = true
        name.Size = 14
        name.Center = true
        name.Font = 2

        local distance = Drawing.new("Text")
        distance.Visible = false
        distance.Color = Color3.fromRGB(230, 230, 230)
        distance.Outline = true
        distance.Size = 14
        distance.Center = true
        distance.Font = 2

        espObjects[player] = {
            Box = box,
            Tracer = tracer,
            Name = name,
            Distance = distance
        }
    end

    for _, player in ipairs(Players:GetPlayers()) do
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
                esp.Box.Visible = false
                esp.Tracer.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
            end
            return
        end

        local origin
        if config.ESP.Tracers.Origin == "Bottom" then
            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        elseif config.ESP.Tracers.Origin == "Center" then
            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        elseif config.ESP.Tracers.Origin == "Top" then
            origin = Vector2.new(Camera.ViewportSize.X / 2, 0)
        else
            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        end

        for player, esp in pairs(espObjects) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and head and humanoid and humanoid.Health > 0 then
                local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
                local rootPos, rootOnScreen = Camera:WorldToViewportPoint(hrp.Position)

                if headOnScreen and rootOnScreen then
                    local boxHeight = math.abs(headPos.Y - rootPos.Y) * 2
                    local boxWidth = boxHeight / 2
                    local boxX = rootPos.X - boxWidth / 2
                    local boxY = headPos.Y - (boxHeight / 2)

                    -- Box
                    esp.Box.Visible = config.ESP.BoxESP.Enabled
                    esp.Box.Color = config.ESP.BoxESP.Color or Color3.fromRGB(220, 220, 220)
                    esp.Box.Thickness = config.ESP.BoxESP.Thickness or 2
                    esp.Box.Filled = config.ESP.BoxESP.Filled or false
                    esp.Box.Transparency = config.ESP.BoxESP.Transparency or 0.6
                    esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                    esp.Box.Position = Vector2.new(boxX, boxY)

                    -- Tracer
                    esp.Tracer.Visible = config.ESP.Tracers.Enabled
                    esp.Tracer.Color = config.ESP.Tracers.Color or Color3.fromRGB(200, 200, 200)
                    esp.Tracer.Thickness = config.ESP.Tracers.Thickness or 1
                    esp.Tracer.From = origin
                    esp.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)

                    -- Name
                    esp.Name.Visible = config.ESP.NameESP.Enabled
                    esp.Name.Text = player.Name
                    esp.Name.Color = config.ESP.NameESP.Color or Color3.fromRGB(230, 230, 230)
                    esp.Name.Position = Vector2.new(rootPos.X, boxY - 15)

                    -- Distance
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    esp.Distance.Visible = config.ESP.DistanceESP.Enabled
                    esp.Distance.Text = string.format("%.0f", dist)
                    esp.Distance.Color = config.ESP.DistanceESP.Color or Color3.fromRGB(230, 230, 230)
                    esp.Distance.Position = Vector2.new(rootPos.X, boxY + boxHeight + 2)
                else
                    esp.Box.Visible = false
                    esp.Tracer.Visible = false
                    esp.Name.Visible = false
                    esp.Distance.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Tracer.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
            end
        end
    end)
end

