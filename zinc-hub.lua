-- Zinc Script (Main Execution Script)
local config = getgenv().zinc
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Utilities
local function getClosestPlayer(range)
    local closest, dist = nil, range or math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = player.Character.HumanoidRootPart.Position
            local mag = (LocalPlayer.Character.HumanoidRootPart.Position - pos).Magnitude
            if mag < dist then
                closest, dist = player, mag
            end
        end
    end
    return closest
end

-- Prediction
local function predict(pos, vel, pred)
    return pos + (vel * pred)
end

-- ESP
local function getBoundingBox(parts)
    local min = Vector3.new(math.huge, math.huge, math.huge)
    local max = Vector3.new(-math.huge, -math.huge, -math.huge)

    for _, part in ipairs(parts) do
        local cf = part.CFrame
        local size = part.Size
        for x = -0.5, 0.5, 1 do
            for y = -0.5, 0.5, 1 do
                for z = -0.5, 0.5, 1 do
                    local corner = cf.Position + (cf.RightVector * size.X * x) + (cf.UpVector * size.Y * y) + (cf.LookVector * size.Z * z)
                    min = Vector3.new(math.min(min.X, corner.X), math.min(min.Y, corner.Y), math.min(min.Z, corner.Z))
                    max = Vector3.new(math.max(max.X, corner.X), math.max(max.Y, corner.Y), math.max(max.Z, corner.Z))
                end
            end
        end
    end

    local center = (min + max) / 2
    local size = max - min
    return CFrame.new(center), size
end

-- ESP
if config.ESP and config.ESP.Enabled then
    local Camera = workspace.CurrentCamera
    local espConnections = {}

    local function createESPObject(player)
        local esp = {
            Box = Drawing.new("Square"),
            Name = Drawing.new("Text"),
            Distance = Drawing.new("Text"),
            Tracer = Drawing.new("Line")
        }

        -- Box settings
        esp.Box.Visible = false
        esp.Box.Color = config.ESP.BoxESP.Color
        esp.Box.Thickness = config.ESP.BoxESP.Thickness
        esp.Box.Transparency = config.ESP.BoxESP.Transparency
        esp.Box.Filled = config.ESP.BoxESP.Filled

        -- Name settings
        esp.Name.Visible = false
        esp.Name.Color = config.ESP.NameESP.Color
        esp.Name.Size = config.ESP.NameESP.TextSize
        esp.Name.Outline = config.ESP.NameESP.Outline
        esp.Name.Center = true

        -- Distance settings
        esp.Distance.Visible = false
        esp.Distance.Color = config.ESP.DistanceESP.Color
        esp.Distance.Size = config.ESP.DistanceESP.TextSize
        esp.Distance.Outline = true
        esp.Distance.Center = true

        -- Tracer settings
        esp.Tracer.Visible = false
        esp.Tracer.Color = config.ESP.Tracers.Color
        esp.Tracer.Thickness = config.ESP.Tracers.Thickness

        espConnections[player] = RunService.RenderStepped:Connect(function()
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.Tracer.Visible = false
                return
            end

            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)

            if onScreen then
                -- Accurate BoxESP
                if config.ESP.BoxESP.Enabled then
                    local parts = {}
                    for _, p in ipairs(char:GetChildren()) do
                        if p:IsA("BasePart") then
                            table.insert(parts, p)
                        end
                    end

                    if #parts > 0 then
                        local cframe, size = getBoundingBox(parts)
                        local corners = {}

                        for x = -0.5, 0.5, 1 do
                            for y = -0.5, 0.5, 1 do
                                for z = -0.5, 0.5, 1 do
                                    local worldPos = (cframe * CFrame.new(x * size.X, y * size.Y, z * size.Z)).Position
                                    local screenPos, onScreenCorner = Camera:WorldToViewportPoint(worldPos)
                                    if onScreenCorner then
                                        table.insert(corners, Vector2.new(screenPos.X, screenPos.Y))
                                    end
                                end
                            end
                        end

                        if #corners == 8 then
                            local topLeft = corners[1]
                            local bottomRight = corners[1]
                            for _, corner in ipairs(corners) do
                                topLeft = Vector2.new(math.min(topLeft.X, corner.X), math.min(topLeft.Y, corner.Y))
                                bottomRight = Vector2.new(math.max(bottomRight.X, corner.X), math.max(bottomRight.Y, corner.Y))
                            end

                            esp.Box.Position = topLeft
                            esp.Box.Size = bottomRight - topLeft
                            esp.Box.Visible = true
                        else
                            esp.Box.Visible = false
                        end
                    end
                else
                    esp.Box.Visible = false
                end

                -- NameESP
                if config.ESP.NameESP.Enabled and head then
                    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    esp.Name.Text = player.Name
                    esp.Name.Position = Vector2.new(headPos.X, headPos.Y - 14)
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end

                -- DistanceESP
                if config.ESP.DistanceESP.Enabled then
                    local distance = (LocalPlayer.Character.HumanoidRootPart.Position - root.Position).Magnitude
                    esp.Distance.Text = "[" .. math.floor(distance) .. "m]"
                    esp.Distance.Position = Vector2.new(pos.X, pos.Y + 40)
                    esp.Distance.Visible = true
                else
                    esp.Distance.Visible = false
                end

                -- Tracer
                if config.ESP.Tracers.Enabled then
                    local screenOrigin = Vector2.new(
                        pos.X,
                        config.ESP.Tracers.Origin == "Bottom" and Camera.ViewportSize.Y or
                        config.ESP.Tracers.Origin == "Top" and 0 or
                        Camera.ViewportSize.Y / 2
                    )
                    esp.Tracer.From = screenOrigin
                    esp.Tracer.To = Vector2.new(pos.X, pos.Y)
                    esp.Tracer.Visible = true
                else
                    esp.Tracer.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.Tracer.Visible = false
            end
        end)

        player.CharacterRemoving:Connect(function()
            for _, obj in pairs(esp) do
                if obj.Remove then obj:Remove() end
            end
            if espConnections[player] then
                espConnections[player]:Disconnect()
                espConnections[player] = nil
            end
        end)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createESPObject(player)
        end
    end

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            wait(1)
            createESPObject(player)
        end)
    end)
end

-- Silent Aim
if config['Silent Aim'].Enabled then
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if method == "FireServer" and tostring(self):lower():find("shoot") then
            local target = getClosestPlayer(config.Range['Silent Aim'])
            if target and target.Character then
                local part = target.Character[config['Silent Aim']['Hit Location'].Parts[1]]
                if part then
                    args[2] = predict(part.Position, part.Velocity, config['Silent Aim'].Prediction.Sets.X)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- Camlock
if config['Camlock'].Enabled then
    local camlockActive = false
    local camlockTarget = nil
    local toggleKey = "v"
    local camera = workspace.CurrentCamera

    -- Get the closest player to crosshair
    local function getClosestToCrosshair(maxDistance)
        local closestPlayer = nil
        local closestDistance = maxDistance or math.huge
        local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local part = player.Character:FindFirstChild(config['Camlock']['Hit Location'].Parts[1])
                if part then
                    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end

        return closestPlayer
    end

    -- Toggle camlock with the V key
    Mouse.KeyDown:Connect(function(key)
        if key:lower() == toggleKey then
            camlockActive = not camlockActive
            if camlockActive then
                camlockTarget = getClosestToCrosshair(config.Range['Camlock'])
            else
                camlockTarget = nil
            end
        end
    end)

    -- Camlock aim adjustment
    RunService.RenderStepped:Connect(function()
        if camlockActive and camlockTarget and camlockTarget.Character then
            local part = camlockTarget.Character:FindFirstChild(config['Camlock']['Hit Location'].Parts[1])
            if part then
                camera.CFrame = camera.CFrame:Lerp(
                    CFrame.new(camera.CFrame.Position, part.Position),
                    config['Camlock'].Value.Snappiness
                )
            end
        end
    end)
end

-- Trigger Bot
if config['Trigger bot'].Enabled then
    RunService.RenderStepped:Connect(function()
        local target = getClosestPlayer(config.Range['Trigger bot'])
        if target and target.Character then
            local part = target.Character[config['Trigger bot'].HitParts.Parts[1]]
            if part then
                local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
                if onScreen then
                    mouse1press()
                    wait(config['Trigger bot'].Delay.Value)
                    mouse1release()
                end
            end
        end
    end)
end

-- Speed Modifications
if config['Speed Modifications'].Options.Enabled then
    local speedEnabled = true
    local speed = config['Speed Modifications'].Options.DefaultSpeed
    local toggleKey = config['Speed Modifications'].Options.Keybinds.ToggleMovement:lower()
    local speedUpKey = config['Speed Modifications'].Options.Keybinds['Speed +5']:lower()
    local speedDownKey = config['Speed Modifications'].Options.Keybinds['Speed -5']:lower()

    RunService.RenderStepped:Connect(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            if speedEnabled then
                LocalPlayer.Character.Humanoid.WalkSpeed = speed
            else
                LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
        end
    end)

    Mouse.KeyDown:Connect(function(key)
        key = key:lower()
        if key == toggleKey then
            speedEnabled = not speedEnabled
        end
        if speedEnabled then
            if key == speedUpKey then
                speed = speed + 15
            elseif key == speedDownKey then
                speed = math.max(0, speed - 15)
            end
        end
    end)
end

-- Spread Modifications
if config['Spread modifications'].Options.Enabled then
    local spread = config['Spread modifications'].Options.Multiplier
    -- Hook function here as needed depending on the game
end

print("[Zinc] Script Loaded Successfully.")
