-- Zinc Hub Script (Main Execution Script)
local config = getgenv().zinc
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

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

-- Silent Aim (Example Hook)
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
                LocalPlayer.Character.Humanoid.WalkSpeed = 16 -- default WalkSpeed
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
    -- Replace weapon spread values (example, depends on game)
    local spread = config['Spread modifications'].Options.Multiplier
    -- Hook function here as needed depending on the game
end

print("[Zinc] Script Loaded Successfully.")
