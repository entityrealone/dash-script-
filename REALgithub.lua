-- LocalScript in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dash settings
local DASH_SPEED = 120
local DASH_DISTANCE = 12
local COOLDOWN = 0.1
local STOP_AFTER_DASH = true

local MIN_SPEED, MAX_SPEED = 0, 400
local MIN_DISTANCE, MAX_DISTANCE = 0, 200
local MIN_BUTTON_SIZE, MAX_BUTTON_SIZE = 50, 120

local player = Players.LocalPlayer
local character, humanoid, root
local lastDash = 0
local dashConnection
local connections = {}

local locked = false
local menuOpen = false
local dragging = false
local wasDrag = false
local dragStart, buttonStart
local sliderDragging = false
local triggerKey = nil
local hideKey = nil
local hideAllOnClose = false
local buttonHidden = false
local clickAbility = false
local destroyed = false

local dash

-- Locating the Knit Dash Remote safely
local function fireKnitDash()
    local success, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("Knit")
            :WaitForChild("Packages")
            ["_Index"]
            ["sleitnick_knit@1.5.1"]
            :WaitForChild("knit")
            :WaitForChild("Services")
            :WaitForChild("DashService")
            :WaitForChild("RE")
            :WaitForChild("Dash")
    end)
    
    if success and remote and remote:IsA("RemoteEvent") then
        remote:FireServer()
    else
        warn("[Knit Sync Error]: Could not fire the backend game dash. Check your path names.")
    end
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function setupCharacter(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    root = newCharacter:WaitForChild("HumanoidRootPart")
end

if player.Character then
    task.spawn(setupCharacter, player.Character)
end

connect(player.CharacterAdded, setupCharacter)

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DashGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Forward a click through this Dash GUI to the first underlying Roblox GUI button.
local function isInsideOurGui(obj)
    return obj == gui or obj:IsDescendantOf(gui)
end

local function findUnderlyingButton(objects, startIndex)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    for i = startIndex, #objects do
        local obj = objects[i]
        if not isInsideOurGui(obj) then
            local current = obj
            while current and current ~= playerGui do
                if current:IsA("GuiButton") and not isInsideOurGui(current) then
                    -- Make sure the button and its ancestors are visible.
                    local visible = true
                    local ancestor = current
                    while ancestor and ancestor ~= playerGui do
                        if ancestor:IsA("GuiObject") and not ancestor.Visible then
                            visible = false
                            break
                        end
                        ancestor = ancestor.Parent
                    end
                    if visible then
                        return current
                    end
                    break
                end
                current = current.Parent
            end
        end
    end
    return nil
end

connect(UserInputService.InputEnded, function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local position = input.Position
    task.defer(function()
        if destroyed or not gui.Parent or not gui.Enabled then return end

        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if not playerGui then return end

        local objects = playerGui:GetGuiObjectsAtPosition(position.X, position.Y)
        if #objects == 0 then return end

        if isInsideOurGui(objects[1]) then
            local target = findUnderlyingButton(objects, 2)
            if target then
                target:Activate()
            end
        end
    end)
end)

local button = Instance.new("TextButton")
button.Name = "DashButton"
button.Size = UDim2.fromOffset(70, 70)
button.Position = UDim2.new(0.8, 0, 0.65, 0)
button.BackgroundColor3 = Color3.fromRGB(35, 130, 255)
button.Text = "DASH"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextScaled = true
button.Font = Enum.Font.GothamBold
button.Active = true
button.Parent = gui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = button

local settingsButton = Instance.new("TextButton")
settingsButton.Name = "SettingsButton"
settingsButton.Size = UDim2.fromOffset(38, 38)
settingsButton.Position = UDim2.new(0.8, 78, 0.65, 16)
settingsButton.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
settingsButton.Text = "⚙"
settingsButton.TextColor3 = Color3.new(1, 1, 1)
settingsButton.TextScaled = true
settingsButton.Parent = gui

local settingsCorner = Instance.new("UICorner")
settingsCorner.CornerRadius = UDim.new(1, 0)
settingsCorner.Parent = settingsButton

local menu = Instance.new("ScrollingFrame")
menu.Name = "DashMenu"
menu.Size = UDim2.fromOffset(280, 400)
menu.Position = UDim2.new(0.5, -140, 0.5, -200)
menu.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
menu.BorderSizePixel = 0
menu.ScrollBarThickness = 5
menu.Active = false
menu.CanvasSize = UDim2.fromOffset(0, 620)
menu.Visible = false
menu.Parent = gui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 12)
menuCorner.Parent = menu

local function makeLabel(name, text, y, height)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = UDim2.new(1, -24, 0, height or 25)
    label.Position = UDim2.fromOffset(12, y)
    label.BackgroundTransparency = 1
    label.Active = false
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = menu
    return label
end

local function makeButton(name, text, y, height)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(1, -24, 0, height or 36)
    b.Position = UDim2.fromOffset(12, y)
    b.BackgroundColor3 = Color3.fromRGB(55, 100, 170)
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 15
    b.Font = Enum.Font.GothamBold
    b.Parent = menu

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = b
    return b
end

makeLabel("Title", "Dash Settings", 8, 30)

local function makeSlider(name, labelText, y, minValue, maxValue, initialValue, callback)
    local label = makeLabel(name .. "Label", "", y, 24)

    local track = Instance.new("Frame")
    track.Name = name .. "Track"
    track.Size = UDim2.new(1, -36, 0, 10)
    track.Position = UDim2.fromOffset(18, y + 31)
    track.BackgroundColor3 = Color3.fromRGB(75, 75, 90)
    track.Active = false
    track.Parent = menu

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(35, 130, 255)
    fill.Active = false
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = track

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Text = ""
    knob.Parent = track

    for _, obj in ipairs({track, fill, knob}) do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = obj
    end

    local value = initialValue
    local function update(x)
        local width = track.AbsoluteSize.X
        if width <= 0 then return end
        local percent = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        value = math.floor(minValue + percent * (maxValue - minValue) + 0.5)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        knob.Position = UDim2.new(percent, 0, 0.5, 0)
        label.Text = labelText .. ": " .. value
        callback(value)
    end

    local function begin(input)
        sliderDragging = true
        update(input.Position.X)
    end

    connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            begin(input)
        end
    end)

    connect(knob.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            begin(input)
        end
    end)

    task.defer(function()
        if track.AbsoluteSize.X > 0 then
            update(track.AbsolutePosition.X + ((initialValue - minValue) / (maxValue - minValue)) * track.AbsoluteSize.X)
        end
    end)

    return {Update = update, Track = track}
end

local speedSlider = makeSlider("Speed", "Dash Speed", 48, MIN_SPEED, MAX_SPEED, DASH_SPEED, function(value)
    DASH_SPEED = value
end)

local distanceSlider = makeSlider("Distance", "Dash Distance (studs)", 108, MIN_DISTANCE, MAX_DISTANCE, DASH_DISTANCE, function(value)
    DASH_DISTANCE = value
end)

local sizeSlider = makeSlider("Size", "Button Size", 168, MIN_BUTTON_SIZE, MAX_BUTTON_SIZE, 70, function(value)
    button.Size = UDim2.fromOffset(value, value)
end)

makeLabel("TriggerLabel", "Dash Trigger Key (blank = click)", 228, 24)

local triggerBox = Instance.new("TextBox")
triggerBox.Size = UDim2.new(1, -24, 0, 34)
triggerBox.Position = UDim2.fromOffset(12, 254)
triggerBox.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
triggerBox.TextColor3 = Color3.new(1, 1, 1)
triggerBox.PlaceholderText = "Example: F"
triggerBox.ClearTextOnFocus = false
triggerBox.Text = ""
triggerBox.TextSize = 16
triggerBox.Parent = menu

local triggerStatus = makeLabel("TriggerStatus", "Trigger: button only", 290, 24)

connect(triggerBox.FocusLost, function()
    local value = string.upper(string.gsub(triggerBox.Text, "%s+", ""))
    if value == "" then
        triggerKey = nil
        triggerStatus.Text = "Trigger: button only"
        return
    end
    local key = Enum.KeyCode[value]
    if key and key ~= Enum.KeyCode.Unknown then
        triggerKey = key
        triggerBox.Text = value
        triggerStatus.Text = "Trigger: " .. value
    else
        triggerKey = nil
        triggerStatus.Text = "Invalid key name"
    end
end)

makeLabel("HideTitle", "Hide Settings", 330, 26)

local hideKeyBox = Instance.new("TextBox")
hideKeyBox.Name = "HideKey"
hideKeyBox.Size = UDim2.new(1, -24, 0, 34)
hideKeyBox.Position = UDim2.fromOffset(12, 360)
hideKeyBox.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
hideKeyBox.TextColor3 = Color3.new(1, 1, 1)
hideKeyBox.PlaceholderText = "Hide key (example: H)"
hideKeyBox.Text = ""
hideKeyBox.ClearTextOnFocus = false
hideKeyBox.TextSize = 16
hideKeyBox.Parent = menu

local clickAbilityButton = makeButton("ClickAbilityButton", "Click Ability: OFF", 405)
local lockButton = makeButton("LockButton", "Lock Button", 447)
local closeButton = makeButton("CloseButton", "Close Menu", 489)
local breakButton = makeButton("BreakButton", "Break - Destroy GUI", 531)
breakButton.BackgroundColor3 = Color3.fromRGB(170, 55, 55)

local function updateHiddenButton()
    button.BackgroundTransparency = buttonHidden and 1 or 0
    button.TextTransparency = buttonHidden and 1 or 0
    button.Active = not buttonHidden or clickAbility
    button.Selectable = not buttonHidden or clickAbility

    if not buttonHidden then
        button.BackgroundColor3 = locked and Color3.fromRGB(35, 180, 110) or Color3.fromRGB(35, 130, 255)
    end
end

connect(hideKeyBox.FocusLost, function()
    local value = string.upper(string.gsub(hideKeyBox.Text, "%s+", ""))

    if value == "" then
        hideKey = nil
        hideAllOnClose = false
        buttonHidden = false
        hideKeyBox.Text = ""
        updateHiddenButton()
        return
    end

    if value == "0" then
        hideKey = Enum.KeyCode.Zero
        hideAllOnClose = true
        hideKeyBox.Text = "0 (hide all on close)"
        updateHiddenButton()
        return
    end

    local key = Enum.KeyCode[value]
    if key and key ~= Enum.KeyCode.Unknown then
        hideKey = key
        hideAllOnClose = false
        hideKeyBox.Text = value
    else
        hideKey = nil
        hideAllOnClose = false
        hideKeyBox.Text = ""
    end

    updateHiddenButton()
end)

connect(clickAbilityButton.Activated, function()
    clickAbility = not clickAbility
    clickAbilityButton.Text = clickAbility and "Click Ability: ON" or "Click Ability: OFF"
    updateHiddenButton()
end)

local function updateLock()
    lockButton.Text = locked and "Unlock Button" or "Lock Button"
    updateHiddenButton()
end

connect(lockButton.Activated, function()
    locked = not locked
    updateLock()
end)

connect(closeButton.Activated, function()
    menuOpen = false
    menu.Visible = false

    if hideAllOnClose then
        gui.Enabled = false
    end
end)

connect(settingsButton.Activated, function()
    menuOpen = not menuOpen
    menu.Visible = menuOpen
end)

-- Combined Dash Execution
dash = function()
    if destroyed then return end
    local now = os.clock()
    if now - lastDash < COOLDOWN then return end
    if not character or not humanoid or not root then return end
    if not root.Parent or humanoid.Health <= 0 or humanoid.Sit then return end

    lastDash = now
    
    ---------------------------------------------------------
    -- COMBINED ACTION: Firing the Game's Remote Knit Framework
    ---------------------------------------------------------
    task.spawn(fireKnitDash)
    
    ---------------------------------------------------------
    -- CUSTOM LOCAL DASH ACTION (Your file's movement physics)
    ---------------------------------------------------------
    local direction = humanoid.MoveDirection
    direction = Vector3.new(direction.X, 0, direction.Z)

    if direction.Magnitude == 0 then
        local look = root.CFrame.LookVector
        direction = Vector3.new(look.X, 0, look.Z)
    end
    if direction.Magnitude == 0 then return end
    direction = direction.Unit

    if dashConnection then
        dashConnection:Disconnect()
        dashConnection = nil
    end

    local dashRoot = root
    local dashHumanoid = humanoid
    local dashSpeed = DASH_SPEED
    local endTime = now + DASH_DISTANCE / dashSpeed

    dashConnection = RunService.PreSimulation:Connect(function()
        if destroyed or os.clock() >= endTime or not dashRoot.Parent or dashHumanoid.Health <= 0 then
            if dashConnection then
                dashConnection:Disconnect()
                dashConnection = nil
            end

            if STOP_AFTER_DASH and dashRoot.Parent and not destroyed then
                local velocity = dashRoot.AssemblyLinearVelocity
                local walk = dashHumanoid.MoveDirection * dashHumanoid.WalkSpeed
                dashRoot.AssemblyLinearVelocity = Vector3.new(walk.X, velocity.Y, walk.Z)
            end
            return
        end

        local velocity = dashRoot.AssemblyLinearVelocity
        dashRoot.AssemblyLinearVelocity = Vector3.new(direction.X * dashSpeed, velocity.Y, direction.Z * dashSpeed)
    end)
end

connect(button.Activated, function()
    if wasDrag then
        wasDrag = false
        return
    end

    if buttonHidden then
        if clickAbility then dash() end
        return
    end

    if locked then
        dash()
    else
        menuOpen = not menuOpen
        menu.Visible = menuOpen
    end
end)

connect(button.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        wasDrag = false
        if not locked then
            dragging = true
            dragStart = input.Position
            buttonStart = button.Position
        end
    end
end)

connect(UserInputService.InputChanged, function(input)
    if sliderDragging then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position
            local sliders = {speedSlider, distanceSlider, sizeSlider}
            for _, slider in ipairs(sliders) do
                local track = slider.Track
                local p = track.AbsolutePosition
                local s = track.AbsoluteSize
                if pos.X >= p.X - 15 and pos.X <= p.X + s.X + 15 and pos.Y >= p.Y - 25 and pos.Y <= p.Y + s.Y + 25 then
                    slider.Update(pos.X)
                    break
                end
            end
        end
    elseif dragging and not locked then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                wasDrag = true
            end
            button.Position = UDim2.new(buttonStart.X.Scale, buttonStart.X.Offset + delta.X, buttonStart.Y.Scale, buttonStart.Y.Offset + delta.Y)
            settingsButton.Position = UDim2.new(button.Position.X.Scale, button.Position.X.Offset + button.AbsoluteSize.X + 8, button.Position.Y.Scale, button.Position.Y.Offset + 16)
        end
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = false
        dragging = false
    end
end)

connect(UserInputService.InputBegan, function(input, gameProcessed)
    if destroyed or gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end

    if hideKey and input.KeyCode == hideKey then
        if hideAllOnClose then
            gui.Enabled = not gui.Enabled
        else
            buttonHidden = not buttonHidden
            updateHiddenButton()
        end
        return
    end

    if triggerKey and input.KeyCode == triggerKey then
        dash()
    end
end)

connect(breakButton.Activated, function()
    if destroyed then return end
    destroyed = true

    if dashConnection then
        dashConnection:Disconnect()
        dashConnection = nil
    end

    for _, connection in ipairs(connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end

    gui:Destroy()
end)

updateLock()
updateHiddenButton()
