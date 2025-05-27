local config = getgenv().zinc
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
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

local function predict(pos, vel, pred)
    return pos + (vel * pred)
end 
-- Silent Aim
if config['Silent Aim'] and config['Silent Aim'].Enabled then
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if method == "FireServer" and tostring(self):lower():find("shoot") then
            local target = getClosestPlayer(config.Range and config.Range['Silent Aim'] or 100)
            if target and target.Character then
                local partName = (config['Silent Aim']['Hit Location'] and config['Silent Aim']['Hit Location'].Parts and config['Silent Aim']['Hit Location'].Parts[1]) or "Head"
                local part = target.Character:FindFirstChild(partName)
                if part then
                    local predVal = (config['Silent Aim'].Prediction and config['Silent Aim'].Prediction.Sets and config['Silent Aim'].Prediction.Sets.X) or 0
                    args[2] = predict(part.Position, part.Velocity, predVal)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- Camlock
if config['Camlock'] and config['Camlock'].Enabled then
    local camlockActive = false
    local camlockTarget = nil
    local camlockPart = nil
    local toggleKey = config['Camlock'].Keybind:lower()
    local camera = workspace.CurrentCamera

    local function getClosestToCrosshair(maxDistance)
        local closestPlayer, closestPart = nil, nil
        local closestDistance = maxDistance or math.huge
        local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, partName in ipairs(config['Camlock']['Hit Location'].Parts or {}) do
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

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode.Name:lower() == toggleKey then
                camlockActive = not camlockActive
                if camlockActive then
                    camlockTarget, camlockPart = getClosestToCrosshair(config.Range and config.Range['Camlock'] or 100)
                else
                    camlockTarget, camlockPart = nil, nil
                end
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if camlockActive and camlockTarget and camlockPart and camlockTarget.Character then
            camera.CFrame = camera.CFrame:Lerp(
                CFrame.new(camera.CFrame.Position, camlockPart.Position),
                config['Camlock'].Value and config['Camlock'].Value.Snappiness or 0.15
            )
        end
    end)
end

-- Trigger Bot
if config['Trigger bot'] and config['Trigger bot'].Enabled then
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    local function isWeaponAllowed()
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not tool then return false end
        for _, w in pairs(config['Trigger bot'].Weapons) do
            if tool.Name == w then
                return true
            end
        end
        return false
    end

    local function checkHitParts(hitPart)
        if config['Trigger bot']['HitParts'].Type == false then
            return true -- ignore parts filtering
        end
        for _, partName in pairs(config['Trigger bot']['HitParts'].Parts) do
            if hitPart.Name == partName then
                return true
            end
        end
        return false
    end

    local mouseDown = false

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
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
        if not config['Trigger bot'].Enabled then return end
        if config['Trigger bot']['Keybind']['Keybind Mode']:lower() == "hold" and not mouseDown then return end
        if not isWeaponAllowed() then return end

        local rayOrigin = Camera.CFrame.Position
        local rayDirection = Camera.CFrame.LookVector * (config.Range and config.Range['Trigger bot'] or 250)

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        if raycastResult and raycastResult.Instance and raycastResult.Instance.Parent then
            local hitHumanoid = raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid")
            if hitHumanoid and hitHumanoid.Health > 0 and checkHitParts(raycastResult.Instance) then
                -- Fire click event after delay
                task.delay(config['Trigger bot'].Delay.Value, function()
                    mouse1click()
                end)
            end
        end
    end)
end

-- Spread Modifications (placeholder for hooking game functions)
if config['Spread Modifications'] and config['Spread Modifications'].Options and config['Spread Modifications'].Options.Enabled then
    -- Your game-specific spread modification code here
end

-- Speedwalk Implementation
local speedwalkConfig = config['Speed Modifications'] and config['Speed Modifications'].Options
if speedwalkConfig and speedwalkConfig.Enabled then
    local isSpeedwalkOn = false
    local currentSpeed = speedwalkConfig.DefaultSpeed or 35

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local keyPressed = input.KeyCode.Name:lower()
            local toggleKey = speedwalkConfig.Keybinds.ToggleMovement and speedwalkConfig.Keybinds.ToggleMovement:lower() or "z"
            local speedUpKey = speedwalkConfig.Keybinds["Speed +5"] and speedwalkConfig.Keybinds["Speed +5"]:lower() or "m"
            local speedDownKey = speedwalkConfig.Keybinds["Speed -5"] and speedwalkConfig.Keybinds["Speed -5"]:lower() or "n"

            if keyPressed == toggleKey then
                isSpeedwalkOn = not isSpeedwalkOn
                print("[Zinc] Speedwalk " .. (isSpeedwalkOn and "Enabled" or "Disabled"))
            elseif keyPressed == speedUpKey then
                currentSpeed = currentSpeed + 5
                print("[Zinc] Speedwalk Speed increased to " .. currentSpeed)
            elseif keyPressed == speedDownKey then
                currentSpeed = math.max(0, currentSpeed - 5)
                print("[Zinc] Speedwalk Speed decreased to " .. currentSpeed)
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") then
            if isSpeedwalkOn then
                character.Humanoid.WalkSpeed = currentSpeed
            else
                character.Humanoid.WalkSpeed = 16
            end
        end
    end)
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

print("[Zinc] Script Loaded Successfully.")
