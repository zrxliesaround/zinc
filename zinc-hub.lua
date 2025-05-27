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
    local Drawing = Drawing -- check if Drawing API is available
    if not Drawing then
        warn("[Zinc] Drawing library not found. ESP will not work.")
        return
    end

    local espObjects = {}

    local function createESP(player)
        if espObjects[player] then return end
        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = config.ESP.BoxESP.Color or Color3.new(1,1,1)
        box.Thickness = config.ESP.BoxESP.Thickness or 1
        box.Filled = config.ESP.BoxESP.Filled or false
        box.Transparency = config.ESP.BoxESP.Transparency or 0.5
        espObjects[player] = box
    end

    Players.PlayerAdded:Connect(createESP)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            createESP(plr)
        end
    end

    RunService.RenderStepped:Connect(function()
        if not config.ESP.Enabled then
            for _, box in pairs(espObjects) do
                box.Visible = false
            end
            return
        end

        local cam = workspace.CurrentCamera
        for player, box in pairs(espObjects) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local pos, onScreen = cam:WorldToViewportPoint(char.HumanoidRootPart.Position)
                if onScreen then
                    box.Visible = true
                    local dist = (Camera.CFrame.Position - char.HumanoidRootPart.Position).Magnitude
                    local size = math.clamp(3000 / dist, 20, 60)
                    box.Size = Vector2.new(size, size)
                    box.Position = Vector2.new(pos.X - box.Size.X / 2, pos.Y - box.Size.Y / 2)
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        end
    end)
end
