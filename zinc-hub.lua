local config = getgenv().zinc
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Utilities
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
                local hitLocConfig = config['Silent Aim']['Hit Location']
                local partName = "Head"
                if hitLocConfig and hitLocConfig.Parts and #hitLocConfig.Parts > 0 then
                    partName = hitLocConfig.Parts[1]
                end
                local part = target.Character:FindFirstChild(partName)
                if part then
                    local predVal = 0
                    if config['Silent Aim'].Prediction and config['Silent Aim'].Prediction.Sets and config['Silent Aim'].Prediction.Sets.X then
                        predVal = config['Silent Aim'].Prediction.Sets.X
                    end
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
    local toggleKey = (config['Camlock'].Keybind or "c"):lower()
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
    local mouseDown = false

    local function isWeaponAllowed()
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not tool then return false end
        for _, w in pairs(config['Trigger bot'].Weapons or {}) do
            if tool.Name == w then
                return true
            end
        end
        return false
    end

    local function checkHitParts(hitPart)
        if not config['Trigger bot']['HitParts'] or config['Trigger bot']['HitParts'].Type == false then
            return true -- ignore parts filtering
        end
        for _, partName in pairs(config['Trigger bot']['HitParts'].Parts or {}) do
            if hitPart.Name == partName then
                return true
            end
        end
        return false
    end

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
        if config['Trigger bot']['Keybind'] and config['Trigger bot']['Keybind']['Keybind Mode'] and config['Trigger bot']['Keybind']['Keybind Mode']:lower() == "hold" and not mouseDown then return end
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
                task.delay(config['Trigger bot'].Delay and config['Trigger bot'].Delay.Value or 0, function()
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
            local toggleKey = (speedwalkConfig.Keybinds and speedwalkConfig.Keybinds.ToggleMovement and speedwalkConfig.Keybinds.ToggleMovement:lower()) or "z"
            local speedUpKey = (speedwalkConfig.Keybinds and speedwalkConfig.Keybinds["Speed +5"] and speedwalkConfig.Keybinds["Speed +5"]:lower()) or "m"
            local speedDownKey = (speedwalkConfig.Keybinds and speedwalkConfig.Keybinds["Speed -5"] and speedwalkConfig.Keybinds["Speed -5"]:lower()) or "n"

            if keyPressed == toggleKey then
                isSpeedwalkOn = not isSpeedwalkOn
                print("[Zinc] Speedwalk " .. (isSpeedwalkOn and "Enabled" or "Disabled"))
            elseif keyPressed == speedUpKey then
                currentSpeed = currentSpeed + 15
                print("[Zinc] Speedwalk Speed increased to " .. currentSpeed)
            elseif keyPressed == speedDownKey then
                currentSpeed = math.max(0, currentSpeed - 15)
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
local espConnections = {}
local espObjects = {}

local function createESP(player)
    if espObjects[player] then return end
    if not player.Character then return end

    local esp = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line")
    }

    -- BoxESP settings
    local boxCfg = config.ESP.BoxESP
    esp.Box.Color = boxCfg.Color
    esp.Box.Thickness = boxCfg.Thickness
    esp.Box.Filled = boxCfg.Filled
    esp.Box.Transparency = boxCfg.Transparency
    esp.Box.Visible = false

    -- NameESP settings
    local nameCfg = config.ESP.NameESP
    esp.Name.Color = nameCfg.Color
    esp.Name.Size = nameCfg.TextSize
    esp.Name.Outline = nameCfg.Outline
    esp.Name.Center = true
    esp.Name.Visible = false

    -- DistanceESP settings
    local distCfg = config.ESP.DistanceESP
    esp.Distance.Color = distCfg.Color
    esp.Distance.Size = distCfg.TextSize
    esp.Distance.Outline = true
    esp.Distance.Center = true
    esp.Distance.Visible = false

    -- Tracer settings
    local tracerCfg = config.ESP.Tracers
    esp.Tracer.Color = tracerCfg.Color
    esp.Tracer.Thickness = tracerCfg.Thickness
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

        local root = char.HumanoidRootPart
        local head = char:FindFirstChild("Head")
        local rootPos, onScreenRoot = Camera:WorldToViewportPoint(root.Position)

        if not onScreenRoot then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        -- BoxESP
        if boxCfg.Enabled then
            local size = root.Size
            local cf = root.CFrame

            local corners3D = {
                cf * Vector3.new(-size.X/2,  size.Y/2, -size.Z/2),
                cf * Vector3.new( size.X/2,  size.Y/2, -size.Z/2),
                cf * Vector3.new(-size.X/2,  size
