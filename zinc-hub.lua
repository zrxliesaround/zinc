-- Zinc Script (Main Execution Script)
local config = getgenv().zinc
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
-- ... (Your ESP code unchanged, omitted here for brevity) ...

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
    local toggleKey = "v"
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

    Mouse.KeyDown:Connect(function(key)
        if key:lower() == toggleKey then
            camlockActive = not camlockActive
            if camlockActive then
                camlockTarget, camlockPart = getClosestToCrosshair(config.Range and config.Range['Camlock'] or 100)
            else
                camlockTarget, camlockPart = nil, nil
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
-- ... (Your trigger bot code unchanged, omitted here for brevity) ...

-- Spread Modifications
if config['Spread modifications'] and config['Spread modifications'].Options and config['Spread modifications'].Options.Enabled then
    local spread = config['Spread modifications'].Options.Multiplier
    -- Hook function here as needed depending on the game
end

-- NoClip
local noclipEnabled = false
local noclipKey = config.NoClip and config.NoClip.Keybind and config.NoClip.Keybind:lower() or "n"

local function setCanCollide(character, value)
    if character then
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = value
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode[noclipKey:upper()] then
        noclipEnabled = not noclipEnabled
        print("[Zinc] NoClip " .. (noclipEnabled and "Enabled" or "Disabled"))

        local character = LocalPlayer.Character
        if character then
            setCanCollide(character, not noclipEnabled)
        end
    end
end)

RunService.Stepped:Connect(function()
    if noclipEnabled then
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            setCanCollide(character, false)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    wait(1)
    if noclipEnabled then
        setCanCollide(char, false)
    end
end)

-- Speedwalk Implementation
local speedwalkConfig = config['Speed Modifications'] and config['Speed Modifications'].Options
if speedwalkConfig and speedwalkConfig.Enabled then
    local isSpeedwalkOn = false
    local currentSpeed = speedwalkConfig.DefaultSpeed or 35

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        local keyPressed = tostring(input.KeyCode):gsub("Enum.KeyCode.", ""):lower()

        -- Normalize config keys for comparison
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
    end)

    RunService.RenderStepped:Connect(function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("Humanoid") then
            if isSpeedwalkOn then
                character.Humanoid.WalkSpeed = currentSpeed
            else
                character.Humanoid.WalkSpeed = 16 -- Roblox default speed
            end
        end
    end)
end

print("[Zinc] Script Loaded Successfully.")
