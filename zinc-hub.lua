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
                -- BoxESP (dynamic size)
                if config.ESP.BoxESP.Enabled then
                    local minVec = Vector3.new(math.huge, math.huge, math.huge)
                    local maxVec = Vector3.new(-math.huge, -math.huge, -math.huge)

                    for _, part in ipairs(char:GetChildren()) do
                        if part:IsA("BasePart") then
                            local pos = part.Position
                            minVec = Vector3.new(
                                math.min(minVec.X, pos.X),
                                math.min(minVec.Y, pos.Y),
                                math.min(minVec.Z, pos.Z)
                            )
                            maxVec = Vector3.new(
                                math.max(maxVec.X, pos.X),
                                math.max(maxVec.Y, pos.Y),
                                math.max(maxVec.Z, pos.Z)
                            )
                        end
                    end

                    local topLeft3D = Vector3.new(minVec.X, maxVec.Y, minVec.Z)
                    local bottomRight3D = Vector3.new(maxVec.X, minVec.Y, maxVec.Z)
                    local topLeft2D, onScreen1 = Camera:WorldToViewportPoint(topLeft3D)
                    local bottomRight2D, onScreen2 = Camera:WorldToViewportPoint(bottomRight3D)

                    if onScreen1 and onScreen2 then
                        esp.Box.Position = Vector2.new(topLeft2D.X, topLeft2D.Y)
                        esp.Box.Size = Vector2.new(bottomRight2D.X - topLeft2D.X, bottomRight2D.Y - topLeft2D.Y)
                        esp.Box.Visible = true
                    else
                        esp.Box.Visible = false
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
    local camlockKey = config['Camlock'].Keybind:lower()
    local camlockTarget = nil
    Mouse.KeyDown:Connect(function(key)
        if key == camlockKey then
            camlockTarget = getClosestPlayer(config.Range['Camlock'])
        end
    end)

    RunService.RenderStepped:Connect(function()
        if camlockTarget and camlockTarget.Character and config['Camlock'].Enabled then
            local cam = workspace.CurrentCamera
            local part = camlockTarget.Character[config['Camlock']['Hit Location'].Parts[1]]
            if part then
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, part.Position), config['Camlock'].Value.Snappiness)
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
                speed = speed + 5
            elseif key == speedDownKey then
                speed = math.max(0, speed - 5)
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
