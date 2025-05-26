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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Config reference
local config = getgenv().zinc
if not config or not config.ESP then return end

-- Bounding box function
local function getBoundingBox(parts)
    local min = Vector3.new(math.huge, math.huge, math.huge)
    local max = Vector3.new(-math.huge, -math.huge, -math.huge)

    for _, part in pairs(parts) do
        local cf = part.CFrame
        local size = part.Size
        local corners = {
            cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
            cf * Vector3.new( size.X/2,  size.Y/2,  size.Z/2)
        }

        for _, v in pairs(corners) do
            min = Vector3.new(math.min(min.X, v.X), math.min(min.Y, v.Y), math.min(min.Z, v.Z))
            max = Vector3.new(math.max(max.X, v.X), math.max(max.Y, v.Y), math.max(max.Z, v.Z))
        end
    end

    local center = (min + max) / 2
    local size = max - min
    return CFrame.new(center), size
end

-- ESP store
local espConnections = {}
local espObjects = {}

-- ESP creation
local function createESP(player)
    if espObjects[player] then return end

    local esp = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line")
    }

    -- Box
    esp.Box.Color = config.ESP.BoxESP.Color
    esp.Box.Thickness = config.ESP.BoxESP.Thickness
    esp.Box.Filled = config.ESP.BoxESP.Filled
    esp.Box.Transparency = config.ESP.BoxESP.Transparency
    esp.Box.Visible = false

    -- Name
    esp.Name.Color = config.ESP.NameESP.Color
    esp.Name.Size = config.ESP.NameESP.TextSize
    esp.Name.Outline = config.ESP.NameESP.Outline
    esp.Name.Center = true
    esp.Name.Visible = false

    -- Distance
    esp.Distance.Color = config.ESP.DistanceESP.Color
    esp.Distance.Size = config.ESP.DistanceESP.TextSize
    esp.Distance.Outline = true
    esp.Distance.Center = true
    esp.Distance.Visible = false

    -- Tracer
    esp.Tracer.Color = config.ESP.Tracers.Color
    esp.Tracer.Thickness = config.ESP.Tracers.Thickness
    esp.Tracer.Visible = false

    espObjects[player] = esp

    espConnections[player] = RunService.RenderStepped:Connect(function()
        if not config.ESP.Enabled then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        -- BoxESP
        if config.ESP.BoxESP.Enabled then
            local parts = {}
            for _, p in ipairs(char:GetChildren()) do
                if p:IsA("BasePart") then table.insert(parts, p) end
            end
            if #parts > 0 then
                local cf, size = getBoundingBox(parts)
                local screenPos, visible = Camera:WorldToViewportPoint(cf.Position)
                local scaleFactor = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, size.Y/2, 0))
                local height = math.abs(screenPos.Y - scaleFactor.Y) * 2
                local width = height / 2

                esp.Box.Position = Vector2.new(screenPos.X - width/2, screenPos.Y - height/2)
                esp.Box.Size = Vector2.new(width, height)
                esp.Box.Visible = true
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
            esp.Distance.Position = Vector2.new(pos.X, pos.Y + 20)
            esp.Distance.Visible = true
        else
            esp.Distance.Visible = false
        end

        -- Tracer
        if config.ESP.Tracers.Enabled then
            local originY = config.ESP.Tracers.Origin == "Bottom" and Camera.ViewportSize.Y
                or config.ESP.Tracers.Origin == "Top" and 0
                or Camera.ViewportSize.Y / 2
            esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, originY)
            esp.Tracer.To = Vector2.new(pos.X, pos.Y)
            esp.Tracer.Visible = true
        else
            esp.Tracer.Visible = false
        end
    end)

    player.CharacterRemoving:Connect(function()
        for _, obj in pairs(esp) do if obj.Remove then obj:Remove() end end
        if espConnections[player] then
            espConnections[player]:Disconnect()
            espConnections[player] = nil
        end
        espObjects[player] = nil
    end)
end

-- Handle current players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if player.Character then
            createESP(player)
        end
        player.CharacterAdded:Connect(function()
            wait(1)
            createESP(player)
        end)
    end
end

-- Handle new players
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        wait(1)
        createESP(player)
    end)
end)

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
    local camlockPart = nil
    local toggleKey = "v"
    local camera = workspace.CurrentCamera

    -- Get the closest player part to the crosshair
    local function getClosestToCrosshair(maxDistance)
        local closestPlayer, closestPart = nil, nil
        local closestDistance = maxDistance or math.huge
        local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, partName in ipairs(config['Camlock']['Hit Location'].Parts) do
                    local part = player.Character:FindFirstChild(partName)
                    if part then
                        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                            if distance < closestDistance then
                                closestDistance = distance
                                closestPlayer = player
                                closestPart = part
                            end
                        end
                    end
                end
            end
        end

        return closestPlayer, closestPart
    end

    -- Toggle Camlock with V key
    Mouse.KeyDown:Connect(function(key)
        if key:lower() == toggleKey then
            camlockActive = not camlockActive
            if camlockActive then
                camlockTarget, camlockPart = getClosestToCrosshair(config.Range['Camlock'])
            else
                camlockTarget, camlockPart = nil, nil
            end
        end
    end)

    -- Lock camera onto part
    RunService.RenderStepped:Connect(function()
        if camlockActive and camlockTarget and camlockPart and camlockTarget.Character then
            camera.CFrame = camera.CFrame:Lerp(
                CFrame.new(camera.CFrame.Position, camlockPart.Position),
                config['Camlock'].Value.Snappiness
            )
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
