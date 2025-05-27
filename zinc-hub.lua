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
-- ESP Setup
local ESPFolder = Instance.new("Folder", Camera)
ESPFolder.Name = "ZincESP"

local espObjects = {}

local function createESPForPlayer(player)
    if espObjects[player] then return end

    local esp = {}

    -- Create Box
    local box = Drawing.new("Square")
    box.Color = config.ESP.BoxESP.Color
    box.Thickness = config.ESP.BoxESP.Thickness
    box.Filled = config.ESP.BoxESP.Filled
    box.Transparency = config.ESP.BoxESP.Transparency
    box.Visible = false

    -- Create Tracer
    local tracer = Drawing.new("Line")
    tracer.Color = config.ESP.Tracers.Color
    tracer.Thickness = config.ESP.Tracers.Thickness
    tracer.Visible = false

    -- Create Name Text
    local nameText = Drawing.new("Text")
    nameText.Text = player.Name
    nameText.Color = config.ESP.NameESP.Color
    nameText.Size = config.ESP.NameESP.TextSize
    nameText.Outline = config.ESP.NameESP.Outline
    nameText.Visible = false

    -- Create Distance Text
    local distText = Drawing.new("Text")
    distText.Color = config.ESP.DistanceESP.Color
    distText.Size = config.ESP.DistanceESP.TextSize
    distText.Outline = true
    distText.Visible = false

    esp.Box = box
    esp.Tracer = tracer
    esp.NameText = nameText
    esp.DistanceText = distText

    espObjects[player] = esp
end

local function removeESPForPlayer(player)
    local esp = espObjects[player]
    if esp then
        esp.Box:Remove()
        esp.Tracer:Remove()
        esp.NameText:Remove()
        esp.DistanceText:Remove()
        espObjects[player] = nil
    end
end

-- Determine tracer origin position on screen
local function getTracerOrigin()
    local originType = config.ESP.Tracers.Origin or "Bottom"
    local size = Camera.ViewportSize
    if originType == "Bottom" then
        return Vector2.new(size.X / 2, size.Y)
    elseif originType == "Center" then
        return Vector2.new(size.X / 2, size.Y / 2)
    elseif originType == "Top" then
        return Vector2.new(size.X / 2, 0)
    else
        return Vector2.new(size.X / 2, size.Y)
    end
end

RunService.RenderStepped:Connect(function()
    if not config.ESP.Enabled then
        -- Remove all ESP objects if ESP disabled
        for player, esp in pairs(espObjects) do
            removeESPForPlayer(player)
        end
        return
    end

    local tracerOrigin = getTracerOrigin()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            createESPForPlayer(player)
            local esp = espObjects[player]

            local rootPart = player.Character.HumanoidRootPart
            local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

            if onScreen then
                -- BoxESP
                if config.ESP.BoxESP.Enabled then
                    local sizeFactor = 100 / rootPos.Z
                    local boxSize = Vector2.new(50 * sizeFactor, 80 * sizeFactor)

                    esp.Box.Size = boxSize
                    esp.Box.Position = Vector2.new(rootPos.X - boxSize.X / 2, rootPos.Y - boxSize.Y / 2)
                    esp.Box.Color = config.ESP.BoxESP.Color
                    esp.Box.Transparency = config.ESP.BoxESP.Transparency
                    esp.Box.Filled = config.ESP.BoxESP.Filled
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end

                -- Tracer
                if config.ESP.Tracers.Enabled then
                    esp.Tracer.From = tracerOrigin
                    esp.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                    esp.Tracer.Color = config.ESP.Tracers.Color
                    esp.Tracer.Thickness = config.ESP.Tracers.Thickness
                    esp.Tracer.Visible = true
                else
                    esp.Tracer.Visible = false
                end

                -- NameESP
                if config.ESP.NameESP.Enabled then
                    esp.NameText.Text = player.Name
                    esp.NameText.Position = Vector2.new(rootPos.X, rootPos.Y - 40)
                    esp.NameText.Color = config.ESP.NameESP.Color
                    esp.NameText.Size = config.ESP.NameESP.TextSize
                    esp.NameText.Outline = config.ESP.NameESP.Outline
                    esp.NameText.Visible = true
                else
                    esp.NameText.Visible = false
                end

                -- DistanceESP
                if config.ESP.DistanceESP.Enabled then
                    local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude)
                    esp.DistanceText.Text = tostring(distance) .. "m"
                    esp.DistanceText.Position = Vector2.new(rootPos.X, rootPos.Y + 30)
                    esp.DistanceText.Color = config.ESP.DistanceESP.Color
                    esp.DistanceText.Size = config.ESP.DistanceESP.TextSize
                    esp.DistanceText.Outline = true
                    esp.DistanceText.Visible = true
                else
                    esp.DistanceText.Visible = false
                end
            else
                -- Not on screen: hide all ESP parts
                esp.Box.Visible = false
                esp.Tracer.Visible = false
                esp.NameText.Visible = false
                esp.DistanceText.Visible = false
            end
        else
            -- Player doesn't qualify for ESP (no character or localplayer)
            removeESPForPlayer(player)
        end
    end
end)

print("[Zinc] Script Loaded Successfully.")
