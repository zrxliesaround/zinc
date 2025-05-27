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
    local Drawing = Drawing -- Drawing API assumed available

    local espObjects = {}

    local function createESP(player)
        if espObjects[player] then return end

        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = config.ESP.BoxESP.Color or Color3.new(1,1,1)
        box.Thickness = config.ESP.BoxESP.Thickness or 1
        box.Filled = config.ESP.BoxESP.Filled or false
        box.Transparency = config.ESP.BoxESP.Transparency or 0.5

        local tracer = Drawing.new("Line")
        tracer.Visible = false
        tracer.Color = config.ESP.Tracers.Color or Color3.new(1,1,1)
        tracer.Thickness = config.ESP.Tracers.Thickness or 1

        local nameText = Drawing.new("Text")
        nameText.Visible = false
        nameText.Color = config.ESP.NameESP.Color or Color3.new(1,1,1)
        nameText.Size = config.ESP.NameESP.TextSize or 13
        nameText.Outline = config.ESP.NameESP.Outline or true
        nameText.Center = true
        nameText.Font = 2

        local distanceText = Drawing.new("Text")
        distanceText.Visible = false
        distanceText.Color = config.ESP.DistanceESP.Color or Color3.new(1,1,1)
        distanceText.Size = config.ESP.DistanceESP.TextSize or 13
        distanceText.Outline = true
        distanceText.Center = true
        distanceText.Font = 2

        espObjects[player] = {
            Box = box,
            Tracer = tracer,
            Name = nameText,
            Distance = distanceText,
        }
    end

    -- Create ESP for all current players except local
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
        local esp = espObjects[player]
        if esp then
            esp.Box:Remove()
            esp.Tracer:Remove()
            esp.Name:Remove()
            esp.Distance:Remove()
            espObjects[player] = nil
        end
    end)

    local function getBoundingBox(char)
        -- Attempt to get bounding box based on HumanoidRootPart and size of character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then return nil end

        local size = Vector3.new(2, 5, 1) -- default approximate size if not found

        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            size = Vector3.new(2, 5, 1)
        elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
            size = Vector3.new(2, 5, 1)
        end

        local cf = hrp.CFrame
        local minBound = cf.Position - (size / 2)
        local maxBound = cf.Position + (size / 2)

        return minBound, maxBound
    end

    local function projectBoundingBox(minBound, maxBound, camera)
        -- Convert the 8 corners of the bounding box to screen points
        local corners = {
            Vector3.new(minBound.X, minBound.Y, minBound.Z),
            Vector3.new(minBound.X, minBound.Y, maxBound.Z),
            Vector3.new(minBound.X, maxBound.Y, minBound.Z),
            Vector3.new(minBound.X, maxBound.Y, maxBound.Z),
            Vector3.new(maxBound.X, minBound.Y, minBound.Z),
            Vector3.new(maxBound.X, minBound.Y, maxBound.Z),
            Vector3.new(maxBound.X, maxBound.Y, minBound.Z),
            Vector3.new(maxBound.X, maxBound.Y, maxBound.Z),
        }

        local screenPoints = {}
        local onScreen = false
        for i, corner in ipairs(corners) do
            local point, vis = camera:WorldToViewportPoint(corner)
            if vis then onScreen = true end
            table.insert(screenPoints, Vector2.new(point.X, point.Y))
        end

        if not onScreen then return nil end

        -- Get the 2D bounding box from projected points
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge

        for _, point in pairs(screenPoints) do
            if point.X < minX then minX = point.X end
            if point.Y < minY then minY = point.Y end
            if point.X > maxX then maxX = point.X end
            if point.Y > maxY then maxY = point.Y end
        end

        return Vector2.new(minX, minY), Vector2.new(maxX, maxY)
    end

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

        local camera = workspace.CurrentCamera
        local originY = 0
        local originX = camera.ViewportSize.X / 2
        local originPos = Vector2.new(originX, camera.ViewportSize.Y) -- bottom middle by default

        local tracerOrigin = config.ESP.Tracers.Origin or 'Bottom'
        if tracerOrigin == 'Center' then
            originPos = Vector2.new(originX, camera.ViewportSize.Y / 2)
        elseif tracerOrigin == 'Top' then
            originPos = Vector2.new(originX, 0)
        end

        for player, esp in pairs(espObjects) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
                local hrp = char.HumanoidRootPart
                local minBound, maxBound = getBoundingBox(char)
                if minBound and maxBound then
                    local minScreen, maxScreen = projectBoundingBox(minBound, maxBound, camera)
                    if minScreen and maxScreen then
                        -- BoxESP
                        esp.Box.Visible = config.ESP.BoxESP.Enabled
                        esp.Box.Color = config.ESP.BoxESP.Color or Color3.new(1,1,1)
                        esp.Box.Thickness = config.ESP.BoxESP.Thickness or 1
                        esp.Box.Filled = config.ESP.BoxESP.Filled or false
                        esp.Box.Transparency = config.ESP.BoxESP.Transparency or 0.5
                        esp.Box.Position = minScreen
                        esp.Box.Size = maxScreen - minScreen

                        -- Tracers
                        esp.Tracer.Visible = config.ESP.Tracers.Enabled
                        esp.Tracer.Color = config.ESP.Tracers.Color or Color3.new(1,1,1)
                        esp.Tracer.Thickness = config.ESP.Tracers.Thickness or 1
                        esp.Tracer.From = originPos
                        esp.Tracer.To = Vector2.new((minScreen.X + maxScreen.X)/2, maxScreen.Y) -- tracer goes to bottom-center of box

                        -- NameESP
                        esp.Name.Visible = config.ESP.NameESP.Enabled
                        esp.Name.Color = config.ESP.NameESP.Color or Color3.new(1,1,1)
                        esp.Name.Size = config.ESP.NameESP.TextSize or 13
                        esp.Name.Outline = config.ESP.NameESP.Outline or true
                        esp.Name.Position = Vector2.new((minScreen.X + maxScreen.X)/2, minScreen.Y - 15)
                        esp.Name.Text = player.Name

                        -- DistanceESP
                        esp.Distance.Visible = config.ESP.DistanceESP.Enabled
                        esp.Distance.Color = config.ESP.DistanceESP.Color or Color3.new(1,1,1)
                        esp.Distance.Size = config.ESP.DistanceESP.TextSize or 13
                        esp.Distance.Outline = true
                        local distance = math.floor((hrp.Position - camera.CFrame.Position).Magnitude)
                        esp.Distance.Position = Vector2.new((minScreen.X + maxScreen.X)/2, maxScreen.Y + 3)
                        esp.Distance.Text = distance .. " studs"
                    else
                        -- Not on screen
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
            else
                esp.Box.Visible = false
                esp.Tracer.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
            end
        end
    end)
end
