local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local LocalPlayer = Player

local RemoteEvents = {
    rob = ReplicatedStorage:WaitForChild("EJw"):WaitForChild("a3126821-130a-4135-80e1-1d28cece4007"),
    sell = ReplicatedStorage:WaitForChild("EJw"):WaitForChild("eb233e6a-acb9-4169-acb9-129fe8cb06bb"),
    equip = ReplicatedStorage:WaitForChild("EJw"):WaitForChild("b16cb2a5-7735-4e84-a72b-22718da109fc"),
    buy = ReplicatedStorage:WaitForChild("EJw"):WaitForChild("29c2c390-e58d-4512-9180-2da58f0d98d8"),
    bomb = ReplicatedStorage:WaitForChild("EJw"):WaitForChild("66291b15-ebda-4dbd-964e-cc89f86d2c82"),
}

local Codes = {
    money = "yQL",
    items = "Vqe"
}

local Config = {
    range = 200,
    proximityPromptTime = 2.5,
    vehicleSpeed = 175,
    playerSpeed = 28,
    policeCheckRange = 20,
    lowHealthThreshold = 35
}

local State = {
    autorobToggle = true,
    autoSellToggle = true,
    collected = {},
    teleportActive = false,
    isSpecialTeleport = false
}

local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local Locations = {
    start = Vector3.new(-1283.8179931640625, 5.306480884552002, 3186.081787109375),
    club = {
        position = Vector3.new(-1788.8973388671875, 4.259582996368408, 3010.351318359375),
        stand = Vector3.new(-1744.1258544921875, 11.098498344421387, 3015.169677734375),
        safe = Vector3.new(-1744.370361328125, 10.97349739074707, 3038.049072265625)
    },
    bank = Vector3.new(-1283.8179931640625, 5.306480884552002, 3186.081787109375),
    jeweler = Vector3.new(-464.14019775390625, 39.09627151489258, 3556.745849609375),
    rejoin = Vector3.new(-1202.1832275390625, -1000.764266967773438, 3715.006103515625)
}

local function loadOrionLib()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Lynox-dev/OrionLib/refs/heads/main/OrionLib.lua"))()
end

local OrionLib = loadOrionLib()

local function sendNotification(title, content)
    OrionLib:MakeNotification({
        Name = title,
        Content = content,
        Image = "rbxassetid://4483345998",
        Time = 5
    })
end

OrionLib:MakeNotification({
    Name = "Starting: Lynox - AutoRob",
    Content = "discord.gg/EgGH9bjX6Y",
    Image = "rbxassetid://4483345998",
    Time = 5
})

wait(5)

local function isPoliceNearby()
    local policeTeam = game:GetService("Teams"):FindFirstChild("Police")
    if not policeTeam then return false end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Team == policeTeam and plr.Character then
            local policeHRP = plr.Character:FindFirstChild("HumanoidRootPart")
            if policeHRP and HumanoidRootPart and (policeHRP.Position - HumanoidRootPart.Position).Magnitude <= Config.policeCheckRange then
                sendNotification("The police is Nearby!", "Aborting Robbery.")
                return true
            end
        end
    end
    return false
end

local function isPlayerHurt()
    local humanoid = Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health <= Config.lowHealthThreshold
end

local function escape()
    sendNotification("Player is hurt!", "Aborting robbery and hopping Server...")

    ensurePlayerInVehicle()
    task.wait(0.5)

    tweenTo(Locations.rejoin)
    task.wait(1)

    Player:Kick("Lynox AutoRob - Rejoining...")
end


local function lootVisibleMeshParts(folder)
    if not folder then return end
    
    if isPoliceNearby() then
        return
    end

    if isPlayerHurt() then
        escape()
        return
    end
    
    local meshParts = {}
    for _, meshPart in ipairs(folder:GetDescendants()) do
        if meshPart:IsA("MeshPart") and meshPart.Transparency == 0 and not State.collected[meshPart] then
            table.insert(meshParts, meshPart)
        end
    end
    
    table.sort(meshParts, function(a, b)
        local distA = (a.Position - HumanoidRootPart.Position).Magnitude
        local distB = (b.Position - HumanoidRootPart.Position).Magnitude
        return distA < distB
    end)
    
    for _, meshPart in ipairs(meshParts) do
        if not Character or not HumanoidRootPart then break end
        
        if isPoliceNearby() then
            break
        end
        
        if meshPart.Transparency == 0 and (meshPart.Position - HumanoidRootPart.Position).Magnitude <= Config.range then
            State.collected[meshPart] = true
            
            task.spawn(function()
                local code = meshPart.Parent and meshPart.Parent.Name == "Money" and Codes.money or Codes.items
                local args = {meshPart, code, true}
                RemoteEvents.rob:FireServer(unpack(args))
                task.wait(Config.proximityPromptTime)
                args[3] = false
                RemoteEvents.rob:FireServer(unpack(args))
                if meshPart and meshPart.Parent then
                    State.collected[meshPart] = nil
                end
            end)
            
            task.wait(0.05)
        end
    end
end

local function interactWithVisibleMeshParts(folder)
    if not folder then return end
    if isPoliceNearby() or isPlayerHurt() then return end

    local meshParts = {}
    for _, meshPart in ipairs(folder:GetChildren()) do
        if meshPart:IsA("MeshPart") and meshPart.Transparency == 0 then
            table.insert(meshParts, meshPart)
        end
    end

    table.sort(meshParts, function(a, b)
        local aDist = (a.Position - HumanoidRootPart.Position).Magnitude
        local bDist = (b.Position - HumanoidRootPart.Position).Magnitude
        return aDist < bDist
    end)

    for _, meshPart in ipairs(meshParts) do
        if isPoliceNearby() or isPlayerHurt() then return end
        if meshPart.Transparency == 1 then continue end

        local code = meshPart.Parent.Name == "Money" and Codes.money or Codes.items
        local args = {meshPart, code, true}
        RemoteEvents.rob:FireServer(unpack(args))
        task.wait(Config.proximityPromptTime)
        args[3] = false
        RemoteEvents.rob:FireServer(unpack(args))
    end
end

game:GetService("CoreGui").DescendantAdded:Connect(function(descendant)
    if descendant.Name == "ErrorPrompt" or descendant.Name == "ErrorTitle" then
        task.wait(0.5)
        local scriptURL = "https://pastebin.com/raw/XXXXXX"
        
        if syn and syn.queue_on_teleport then
            syn.queue_on_teleport('loadstring(game:HttpGet("' .. scriptURL .. '"))()')
        elseif queue_on_teleport then
            queue_on_teleport('loadstring(game:HttpGet("' .. scriptURL .. '"))()')
        elseif queueonteleport then
            queueonteleport('loadstring(game:HttpGet("' .. scriptURL .. '"))()')
        end
        
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        local scriptURL = "https://pastebin.com/raw/XXXXXX"
        
        if syn and syn.queue_on_teleport then
            syn.queue_on_teleport('loadstring(game:HttpGet("' .. scriptURL .. '"))()')
        elseif queue_on_teleport then
            queue_on_teleport('loadstring(game:HttpGet("' .. scriptURL .. '"))()')
        elseif queueonteleport then
            queueonteleport('loadstring(game:HttpGet("' .. scriptURL .. '"))()')
        end
    end
end)

while true do
    local team = Player.Team
    local teamName = team and team.Name or "None"

    if teamName == "Prisoner" then
        sendNotification("Arrested", "Waiting to be released")
        wait(5)
    else
        local Window = OrionLib:MakeWindow({
            Name = "Lynox - AutoRob",
            HidePremium = false, 
            SaveConfig = true, 
            ConfigFolder = "Lynox",
            IntroEnabled = false,
            IntroText = "Loading Lynox...",
            IntroIcon = "rbxassetid://140458594132153",
            Icon = "rbxassetid://140458594132153"
        })

        local AutoRobTab = Window:MakeTab({
            Name = "AutoRob",
            Icon = "rbxassetid://10747364031",
            PremiumOnly = false,
        })

        local SettingsTab = Window:MakeTab({
            Name = "Settings",
            Icon = "rbxassetid://10734950309",
            PremiumOnly = false
        })

        AutoRobTab:AddSection({Name = "AutoRob"})   
        AutoRobTab:AddParagraph("How does AutoRob work?","Enable the AutoRob toggle (Auto-Sell is optional)\nand the Script will automatically rob the Club, Bank an Jeweler.")
        AutoRobTab:AddParagraph("Auto-Execute not available for now!","Auto-Execute will be available in a future update.\nFor now you have to put the Script in your autoexec Folder.")

        local configFileName = "LynoxConfigRob.json"

        local function loadConfig()
            if isfile(configFileName) then
                local data = readfile(configFileName)
                local success, config = pcall(function() return HttpService:JSONDecode(data) end)
                if success and config then
                    State.autorobToggle = config.autorobToggle or false
                    State.autoSellToggle = config.autoSellToggle or false
                    Config.vehicleSpeed = config.vehicleSpeed or 175
                    Config.playerSpeed = config.playerSpeed or 28
                end
            end
        end

        local function saveConfig()
            local config = {
                autorobToggle = State.autorobToggle,
                autoSellToggle = State.autoSellToggle,
                vehicleSpeed = Config.vehicleSpeed,
                playerSpeed = Config.playerSpeed
            }
            local json = HttpService:JSONEncode(config)
            writefile(configFileName, json)
        end

        loadConfig()

        SettingsTab:AddSlider({
            Name = "Vehicle Speed",
            Min = 100,
            Max = 175,
            Default = Config.vehicleSpeed,
            Color = Color3.fromRGB(85,170,255),
            Increment = 5,
            ValueName = "speed",
            Callback = function(Value)
                Config.vehicleSpeed = Value
                saveConfig()
            end    
        })

        SettingsTab:AddSlider({
            Name = "Player Speed",
            Min = 20,
            Max = 100,
            Default = Config.playerSpeed,
            Color = Color3.fromRGB(85,170,255),
            Increment = 2,
            ValueName = "speed",
            Callback = function(Value)
                Config.playerSpeed = Value
                saveConfig()
            end    
        })

        SettingsTab:AddSlider({
            Name = "Min. Health",
            Min = 10,
            Max = 100,
            Default = Config.LowHealthThreshold,
            Color = Color3.fromRGB(85,170,255),
            Increment = 1,
            ValueName = "health",
            Callback = function(Value)
                Config.LowHealthThreshold = Value
                saveConfig()
            end
        })

        SettingsTab:AddSlider({
            Name = "Police Detection Range",
            Min = 5,
            Max = 50,
            Default = Config.policeCheckRange,
            Color = Color3.fromRGB(85,170,255),
            Increment = 5,
            ValueName = "range",
            Callback = function(Value)
                Config.policeCheckRange = Value
                saveConfig()
            end
        })

        SettingsTab:AddButton({
            Name = "Reset Configuration",
            Callback = function()
                if isfile(configFileName) then
                    delfile(configFileName)
                end
                State.autorobToggle = false
                State.autoSellToggle = false
                Config.vehicleSpeed = 175
                Config.playerSpeed = 28
                saveConfig()
                sendNotification("Settings Reset!", "All settings have been reset to default.")
            end
        })

        local autorobToggleUI = AutoRobTab:AddToggle({
            Name = "AutoRob",
            Default = true,
            Callback = function(Value)
                State.autorobToggle = Value
                saveConfig()
            end    
        })

        local autoSellToggleUI = AutoRobTab:AddToggle({
            Name = "Auto-Sell",
            Default = true,
            Callback = function(Value)
                State.autoSellToggle = Value
                saveConfig()
            end    
        })

        autorobToggleUI:Set(State.autorobToggle)
        autoSellToggleUI:Set(State.autoSellToggle)

        local args = {"Bomb", "Dealer"}
        RemoteEvents.sell:FireServer(unpack(args))

        local function SpawnBomb()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            task.wait(0.5)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.1)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end

        local function JumpOut()
            local character = Player.Character or Player.CharacterAdded:Wait()
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid and humanoid.SeatPart then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end

        local function ensurePlayerInVehicle()
            local vehicle = workspace:FindFirstChild("Vehicles") and workspace.Vehicles:FindFirstChild(Player.Name)
            local character = Player.Character or Player.CharacterAdded:Wait()

            if vehicle and character then
                local humanoid = character:FindFirstChildWhichIsA("Humanoid")
                local driveSeat = vehicle:FindFirstChild("DriveSeat")

                if humanoid and driveSeat and humanoid.SeatPart ~= driveSeat then
                    driveSeat:Sit(humanoid)
                end
            end
        end

        local function clickAtCoordinates(scaleX, scaleY, duration)
            local camera = Workspace.CurrentCamera
            local screenWidth = camera.ViewportSize.X
            local screenHeight = camera.ViewportSize.Y
            local absoluteX = screenWidth * scaleX
            local absoluteY = screenHeight * scaleY
                    
            VirtualInputManager:SendMouseButtonEvent(absoluteX, absoluteY, 0, true, game, 0)  
                    
            if duration and duration > 0 then
                task.wait(duration)  
            end
                    
            VirtualInputManager:SendMouseButtonEvent(absoluteX, absoluteY, 0, false, game, 0) 
        end

        local function plrTween(destination)
            local char = Player.Character
            if not char or not char.PrimaryPart then return end

            local distance = (char.PrimaryPart.Position - destination).Magnitude
            local tweenDuration = distance / Config.playerSpeed

            local TweenInfoToUse = TweenInfo.new(
                tweenDuration,
                Enum.EasingStyle.Linear,
                Enum.EasingDirection.Out
            )

            local TweenValue = Instance.new("CFrameValue")
            TweenValue.Value = char:GetPivot()

            TweenValue.Changed:Connect(function(newCFrame)
                char:PivotTo(newCFrame)
            end)

            local targetCFrame = CFrame.new(destination)
            local tween = TweenService:Create(TweenValue, TweenInfoToUse, { Value = targetCFrame })
            tween:Play()
            tween.Completed:Wait()
            TweenValue:Destroy()
        end

        local FARMspeed = 160
        local teleportActive = false
        local customCamConnection = nil
        local overlayGuis = {}
        local targetPosition = nil
        local isSpecialTeleport = false
        local seatCheckConnection = nil
        local lastSafeFlyTime = 0  
        local SAFEFLY_COOLDOWN = 5 
        local SAFEFLY_DISTANCE = 700

        local function inCar()
            local v = workspace.Vehicles:FindFirstChild(Player.Name)
            local h = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if v and h and not h.SeatPart then 
                local s = v:FindFirstChild("DriveSeat")
                if s then 
                    s:Sit(h)
                    task.wait(0.3)
                end 
            end
        end

        local function startSeatCheck()
            if seatCheckConnection then seatCheckConnection:Disconnect() end
            seatCheckConnection = RunService.Heartbeat:Connect(function()
                local v = workspace.Vehicles:FindFirstChild(Player.Name)
                local h = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
                if v and h and not h.SeatPart then 
                    local s = v:FindFirstChild("DriveSeat")
                    if s then s:Sit(h) end 
                end
            end)
        end

        local function stopSeatCheck()
            if seatCheckConnection then 
                seatCheckConnection:Disconnect()
                seatCheckConnection = nil 
            end
        end

        local function makeInvisible(character)
            for _, obj in ipairs(character:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Transparency = 1
                    obj.LocalTransparencyModifier = 1
                elseif obj:IsA("MeshPart") then
                    obj.Transparency = 1
                    obj.LocalTransparencyModifier = 1
                elseif obj:IsA("SpecialMesh") then
                    if obj.Parent and obj.Parent:IsA("BasePart") then
                        obj.Parent.Transparency = 1
                        obj.Parent.LocalTransparencyModifier = 1
                    end
                elseif obj:IsA("Accessory") and obj:FindFirstChild("Handle") then
                    obj.Handle.Transparency = 1
                    obj.Handle.LocalTransparencyModifier = 1
                elseif obj:IsA("Decal") then
                    obj.Transparency = 1
                end
            end
        end

        local function makeVisible(character)
            for _, obj in ipairs(character:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                    obj.Transparency = 0
                    obj.LocalTransparencyModifier = 0
                elseif obj:IsA("MeshPart") and obj.Name ~= "HumanoidRootPart" then
                    obj.Transparency = 0
                    obj.LocalTransparencyModifier = 0
                elseif obj:IsA("SpecialMesh") then
                    if obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent.Name ~= "HumanoidRootPart" then
                        obj.Parent.Transparency = 0
                        obj.Parent.LocalTransparencyModifier = 0
                    end
                elseif obj:IsA("Accessory") and obj:FindFirstChild("Handle") then
                    obj.Handle.Transparency = 0
                    obj.Handle.LocalTransparencyModifier = 0
                elseif obj:IsA("Decal") then
                    obj.Transparency = 0
                end
            end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Transparency = 1
                hrp.LocalTransparencyModifier = 1
            end
        end

        local visibilityConnection
        if visibilityConnection then visibilityConnection:Disconnect() end
        visibilityConnection = RunService.RenderStepped:Connect(function()
            local char = Player.Character
            if not char then return end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local inDriveSeat = (hum and hum.SeatPart and hum.SeatPart.Name == "DriveSeat")
            
            if inDriveSeat or State.teleportActive then
                makeInvisible(char)
            else
                makeVisible(char)
            end
        end)

        local function createSingleOverlay(layerIndex)
            local playerGui = Player:WaitForChild("PlayerGui")
            
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "BeanzzOverlay" .. layerIndex
            screenGui.ResetOnSpawn = true
            screenGui.IgnoreGuiInset = true
            screenGui.DisplayOrder = 1000 + layerIndex
            screenGui.Parent = playerGui
            
            local bg = Instance.new("Frame")
            bg.Name = "BlackBackground"
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.Position = UDim2.new(0, 0, 0, 0)
            bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bg.BorderSizePixel = 0
            bg.Parent = screenGui
            
            local title = Instance.new("TextLabel")
            title.Name = "Title"
            title.Size = UDim2.new(1, 0, 0.18, 0)
            title.Position = UDim2.new(0, 0, 0.42, 0)
            title.BackgroundTransparency = 1
            title.Text = "Lynox - AutoRob"
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.Font = Enum.Font.SourceSansBold
            title.TextScaled = true
            title.TextWrapped = true
            title.TextXAlignment = Enum.TextXAlignment.Center
            title.TextYAlignment = Enum.TextYAlignment.Center
            title.Parent = bg
            
            local subtitle = Instance.new("TextLabel")
            subtitle.Name = "Subtitle"
            subtitle.Size = UDim2.new(1, 0, 0.05, 0)
            subtitle.Position = UDim2.new(0, 0, 0.55, 0)
            subtitle.BackgroundTransparency = 1
            subtitle.Text = "discord.gg/EgGH9bjX6Y"
            subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            subtitle.Font = Enum.Font.Gotham
            subtitle.TextScaled = true
            subtitle.TextWrapped = true
            subtitle.TextXAlignment = Enum.TextXAlignment.Center
            subtitle.TextYAlignment = Enum.TextYAlignment.Top
            subtitle.Parent = bg
            
            local watermark = Instance.new("TextLabel")
            watermark.Name = "Watermark"
            watermark.Size = UDim2.new(0.9, 0, 0.08, 0)
            watermark.Position = UDim2.new(0.05, 0, 0.85, 0)
            watermark.BackgroundTransparency = 1
            watermark.Text = "Why are you seeing this?\nYou are seeing this to prevent others from showcasing our script as theirs.\nThis watermark ONLY shows while teleporting or being AFK."
            watermark.TextColor3 = Color3.fromRGB(200, 200, 200)
            watermark.Font = Enum.Font.Gotham
            watermark.TextScaled = true
            watermark.TextWrapped = true
            watermark.TextXAlignment = Enum.TextXAlignment.Center
            watermark.TextYAlignment = Enum.TextYAlignment.Center
            watermark.Parent = bg
            
            screenGui.DescendantRemoving:Connect(function()
                if screenGui and screenGui.Parent then
                    task.wait()
                    if not screenGui.Parent then
                        createSingleOverlay(layerIndex)
                    end
                end
            end)
            
            return screenGui
        end

        local function showOverlay()
            for i = 1, 10 do
                local gui = createSingleOverlay(i)
                table.insert(overlayGuis, gui)
            end
            
            task.spawn(function()
                while #overlayGuis > 0 do
                    task.wait(0.1)
                    for i = #overlayGuis, 1, -1 do
                        local gui = overlayGuis[i]
                        if not gui or not gui.Parent then
                            table.remove(overlayGuis, i)
                            local newGui = createSingleOverlay(i)
                            table.insert(overlayGuis, i, newGui)
                        end
                    end
                end
            end)
        end

        local function hideOverlay()
            for _, gui in pairs(overlayGuis) do
                if gui then gui:Destroy() end
            end
            overlayGuis = {}
        end

        local function startCustomCamera()
            local cam = Workspace.CurrentCamera
            local distance = 12
            local minDistance, maxDistance = 5, 20
            local yaw, pitch = 0, 0
            
            local mouseConnection = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    yaw = yaw - input.Delta.X * 0.2
                    pitch = math.clamp(pitch - input.Delta.Y * 0.2, -80, 80)
                elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                    distance = math.clamp(distance - input.Position.Z, minDistance, maxDistance)
                end
            end)
            
            customCamConnection = RunService.RenderStepped:Connect(function()
                local veh = workspace.Vehicles:FindFirstChild(Player.Name)
                if veh then
                    local driveSeat = veh:FindFirstChild("DriveSeat")
                    if driveSeat then
                        local cf = driveSeat.CFrame
                        local offset = CFrame.new(0, 2, distance)
                        local rotation = CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
                        cam.CFrame = cf * rotation * offset:Inverse()
                        cam.Focus = cf
                    end
                end
            end)
        end

        local function stopCustomCamera()
            if customCamConnection then
                customCamConnection:Disconnect()
                customCamConnection = nil
            end
        end

        local function activateSafeFly()
            local currentTime = tick()
            if currentTime - lastSafeFlyTime < SAFEFLY_COOLDOWN then
                return  
            end
            
            task.wait(3)
            local char = Player.Character
            if char and State.teleportActive then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.SeatPart and hum.SeatPart.Name == "DriveSeat" then
                    lastSafeFlyTime = tick()
                    
                    startCustomCamera()
                    showOverlay()
                    
                    local safeFlyStartTime = tick()
                    
                    hum.Sit = false
                    task.wait(1)
                    inCar()
                    
                    if State.isSpecialTeleport then
                        task.wait(0.3)
                        local checkCount = 0
                        while checkCount < 10 do
                            local newHum = char:FindFirstChildOfClass("Humanoid")
                            if newHum and newHum.SeatPart and newHum.SeatPart.Name == "DriveSeat" then
                                break
                            end
                            task.wait(0.1)
                            checkCount = checkCount + 1
                        end
                        
                        stopCustomCamera()
                        hideOverlay()
                        return
                    end
                    
                    task.wait(0.3)
                    local checkCount = 0
                    while checkCount < 10 do
                        local newHum = char:FindFirstChildOfClass("Humanoid")
                        if newHum and newHum.SeatPart and newHum.SeatPart.Name == "DriveSeat" then
                            break
                        end
                        
                        local elapsed = tick() - safeFlyStartTime
                        if elapsed >= 2 then
                            break
                        end
                        
                        if targetPosition then
                            local veh = workspace.Vehicles:FindFirstChild(Player.Name)
                            if veh and veh.PrimaryPart then
                                local distance = (veh.PrimaryPart.Position - targetPosition).Magnitude
                                if distance < 50 then
                                    break
                                end
                            end
                        end
                        
                        task.wait(0.1)
                        checkCount = checkCount + 1
                    end
                    
                    local elapsed = tick() - safeFlyStartTime
                    if elapsed < 2 then
                        local remainingTime = 2 - elapsed
                        local waitStart = tick()
                        while (tick() - waitStart) < remainingTime do
                            if targetPosition then
                                local veh = workspace.Vehicles:FindFirstChild(Player.Name)
                                if veh and veh.PrimaryPart then
                                    local distance = (veh.PrimaryPart.Position - targetPosition).Magnitude
                                    if distance < 50 then
                                        break
                                    end
                                end
                            end
                            task.wait(0.1)
                        end
                    end
                    
                    stopCustomCamera()
                    hideOverlay()
                end
            end
        end

        local function tweenModel(v, targetCF, dur, onComplete)
            if not v.PrimaryPart then return end
            local cv = Instance.new("CFrameValue")
            cv.Value = v:GetPrimaryPartCFrame()
            
            cv:GetPropertyChangedSignal("Value"):Connect(function()
                if v and v.PrimaryPart then
                    v:SetPrimaryPartCFrame(cv.Value)
                    for _, p in pairs(v:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.AssemblyLinearVelocity = Vector3.zero
                            p.AssemblyAngularVelocity = Vector3.zero
                            p.Velocity = Vector3.zero
                            p.RotVelocity = Vector3.zero
                        end
                    end
                end
            end)
            
            local tw = TweenService:Create(cv, TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Value = targetCF})
            tw:Play()
            tw.Completed:Wait()
            cv:Destroy()
            if onComplete then onComplete() end
        end

local function smoothFlyTo(cf, skipSafeFly)
    local v = workspace.Vehicles:FindFirstChild(Player.Name)
    if not v or not v.PrimaryPart then return end

    local startPos = v.PrimaryPart.Position
    local targetPos = cf.Position
    targetPosition = targetPos

    local totalDist = (targetPos - startPos).Magnitude
    local totalDur = totalDist / FARMspeed

    if not skipSafeFly then
        task.spawn(activateSafeFly)
    end

    local flyHeight = -10


    local upCF = CFrame.new(startPos.X, flyHeight, startPos.Z) * (cf - cf.Position)
    local horCF = CFrame.new(targetPos.X, flyHeight, targetPos.Z) * (cf - cf.Position)
    local downCF = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z) * (cf - cf.Position)

    local upDist = math.abs(startPos.Y - flyHeight)
    local horDist = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z).Magnitude
    local downDist = math.abs(targetPos.Y - flyHeight)
    local totalDistSum = upDist + horDist + downDist

    local upDur = (upDist / totalDistSum) * totalDur
    local horDur = (horDist / totalDistSum) * totalDur
    local downDur = (downDist / totalDistSum) * totalDur

    tweenModel(v, upCF, upDur)
    tweenModel(v, horCF, horDur)
    tweenModel(v, downCF, downDur)

    stopSeatCheck()
    State.teleportActive = false
    targetPosition = nil
end

        local function tweenTo(destination)
            local targetCF
            if typeof(destination) == "CFrame" then
                targetCF = destination
            elseif typeof(destination) == "Vector3" then
                targetCF = CFrame.new(destination)
            else
                return
            end

            local v = workspace.Vehicles:FindFirstChild(Player.Name)
            if not v or not v.PrimaryPart then 
                return 
            end
            
            local skipSafeFly = false

            local currentPos = v.PrimaryPart.Position
            local targetPos = targetCF.Position
            local distance = (targetPos - currentPos).Magnitude

            if distance < SAFEFLY_DISTANCE then
                skipSafeFly = true
            end

            State.teleportActive = true
            State.isSpecialTeleport = false
            
            inCar()
            task.wait(1)
            
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum or not hum.SeatPart or hum.SeatPart.Name ~= "DriveSeat" then
                    return
                end
            end
            
            startSeatCheck()

            smoothFlyTo(targetCF, skipSafeFly)
        end

        local function MoveToDealer()
            local vehicle = workspace.Vehicles:FindFirstChild(Player.Name)
            if not vehicle then
                sendNotification("Error", "No vehicle found.")
                return
            end

            local dealers = workspace:FindFirstChild("Dealers")
            if not dealers then
                sendNotification("Error!", "Dealers not found.")
                tweenTo(Locations.rejoin)
                Player:Kick("Lynox - AutoRob | Rejoining...")
                return
            end

            local closest, shortest = nil, math.huge
            for _, dealer in pairs(dealers:GetChildren()) do
                if dealer:FindFirstChild("Head") then
                    local dist = (Character.HumanoidRootPart.Position - dealer.Head.Position).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = dealer.Head
                    end
                end
            end

            if not closest then
                sendNotification("Error!", "Dealers not found.")
                tweenTo(Locations.rejoin)
                Player:Kick("Lynox - AutoRob | Rejoining...")
                return
            end

            local destination1 = closest.Position + Vector3.new(0, 5, 0)
            tweenTo(destination1)
        end

        local function hasBomb()
            local function checkContainer(container)
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") and item.Name == "Bomb" then
                        return true
                    end
                end
                return false
            end
            return checkContainer(Player.Backpack) or checkContainer(Player.Character)
        end

        local function checkSafeRobStatus()
            local robberiesFolder = Workspace:FindFirstChild("Robberies")
            if not robberiesFolder then return false end

            local jewelerSafeFolder = robberiesFolder:FindFirstChild("Jeweler Safe Robbery")
            if not jewelerSafeFolder then return false end

            local jewelerFolder = jewelerSafeFolder:FindFirstChild("Jeweler")
            if not jewelerFolder then return false end

            local doorFolder = jewelerFolder:FindFirstChild("Door")
            if not doorFolder then return false end

            local targetPart
            for _, v in ipairs(doorFolder:GetDescendants()) do
                if v:IsA("BasePart") then
                    targetPart = v
                    break
                end
            end

            if not targetPart then return false end

            local _, y, _ = targetPart.CFrame:ToEulerAnglesYXZ()
            y = math.deg(y) % 360

            return math.abs(y - 90) < 10 or math.abs(y - 270) < 10
        end

        while task.wait() do
            if State.autorobToggle == true then
                local character = Player.Character or Player.CharacterAdded:Wait()
                local humanoid = character:WaitForChild("Humanoid")
                local camera = Workspace.CurrentCamera

                local function lockCamera()
                    local rootPart = character.HumanoidRootPart
                    local backOffset = rootPart.CFrame.LookVector * -6
                    local cameraPosition = rootPart.Position + backOffset + Vector3.new(0, 5, 0) 
                    local lookAtPosition = rootPart.Position + Vector3.new(0, 2, 0) 
                    camera.CFrame = CFrame.new(cameraPosition, lookAtPosition)
                end

                RunService.Heartbeat:Connect(lockCamera)
                
                ensurePlayerInVehicle()
                task.wait(.5)
                clickAtCoordinates(0.5, 0.9)
                task.wait(.5)
                tweenTo(Locations.start)
                
                local musikPart = Workspace.Robberies["Club Robbery"].Club.Door.Accessory.Black
                local bankPart = Workspace.Robberies.BankRobbery.VaultDoor["Meshes/Tresor_Plane (2)"]
                local bankLight = Workspace.Robberies.BankRobbery.LightGreen.Light
                local bankLight2 = Workspace.Robberies.BankRobbery.LightRed.Light
                
                if musikPart.Rotation == Vector3.new(180, 0, 180) then
                    clickAtCoordinates(0.5, 0.9)
                    sendNotification("Club Safe is robbable!", "Starting...")
                    
                    if not hasBomb() then
                        ensurePlayerInVehicle()
                        MoveToDealer()
                        task.wait(0.5)
                        local args = {"Bomb", "Dealer"}
                        RemoteEvents.buy:FireServer(unpack(args))
                        task.wait(0.5)
                    end

                    ensurePlayerInVehicle()
                    task.wait(0.5)
                    tweenTo(Locations.club.position)
                    task.wait(0.5)
                    JumpOut()
                    task.wait(0.5)

                    local args = {"Bomb"}
                    RemoteEvents.equip:FireServer(unpack(args))
                    task.wait(0.5)

                    plrTween(Locations.club.stand)
                    task.wait(0.5)
                    local tool = Player.Character:FindFirstChild("Bomb")
                    if tool then
                        SpawnBomb()
                    end
                    task.wait(0.5)
                    RemoteEvents.bomb:FireServer()
                    plrTween(Locations.club.safe)
                    task.wait(2)
                    plrTween(Locations.club.stand)

                    local safeFolder = Workspace.Robberies["Club Robbery"].Club
                    local itemsFolder = safeFolder:FindFirstChild("Items")
                    local moneyFolder = safeFolder:FindFirstChild("Money")
                    
                    for i = 1, 25 do
                        if isPoliceNearby() then 
                            ensurePlayerInVehicle()
                            break 
                        end
                        lootVisibleMeshParts(itemsFolder)
                        lootVisibleMeshParts(moneyFolder)
                        task.wait(0.5)
                    end

                    ensurePlayerInVehicle()

                    if State.autoSellToggle == true then
                        ensurePlayerInVehicle()
                        MoveToDealer()
                        task.wait(0.5)

                        local sellItems = {"MP5", "Glock 17", "Machete", "Gold"}
                        for _, item in ipairs(sellItems) do
                            local args = {item, "Dealer"}
                            RemoteEvents.sell:FireServer(unpack(args))
                        end

                        tweenTo(Locations.start)
                    end

                    ensurePlayerInVehicle()
                    tweenTo(Locations.start)

                else
                    sendNotification("Club Safe is not robbable!", "Going to check bank...")
                end

                if bankLight2.Enabled == false and bankLight.Enabled == true then
                    clickAtCoordinates(0.5, 0.9)
                    sendNotification("Bank vault is robbable!", "Starting...")
                    
                    ensurePlayerInVehicle()
                    if not hasBomb() then
                        ensurePlayerInVehicle()
                        MoveToDealer()
                        task.wait(0.5)
                        local args = {"Bomb", "Dealer"}
                        RemoteEvents.buy:FireServer(unpack(args))
                        task.wait(0.5)
                    end
                    
                    tweenTo(Locations.bank)
                    tweenTo(Locations.bank)
                    JumpOut()
                    task.wait(1.5)
                    plrTween(Vector3.new(-1242.367919921875, 7.749999046325684, 3144.705322265625))
                    task.wait(.5)
                    local args = {"Bomb"}
                    RemoteEvents.equip:FireServer(unpack(args))
                    task.wait(.5)
                    local tool = Player.Character:FindFirstChild("Bomb")
                    if tool then
                        SpawnBomb()
                    end
                    RemoteEvents.bomb:FireServer()
                    plrTween(Vector3.new(-1246.291015625, 7.749999046325684, 3120.8505859375))
                    task.wait(2.9)
                    local bankCollectPositions = {
                        Vector3.new(-1250.5350341796875, 7.677606105804443, 3123.22705078125),
                        Vector3.new(-1231.3558349609375, 7.677606105804443, 3123.976806640625),
                        Vector3.new(-1246.909423828125, 7.677606105804443, 3102.69921875),
                        Vector3.new(-1234.87255859375, 7.677606105804443, 3103.3466796875)
                    }
                    
                    local bankRobberyFolder = Workspace.Robberies.BankRobbery
                    
                    for _, position in ipairs(bankCollectPositions) do
                        if isPoliceNearby() then 
                            ensurePlayerInVehicle()
                            break 
                        end
                        if Character and Character.PrimaryPart then
                            Character:SetPrimaryPartCFrame(CFrame.new(position))
                        end
                        
                        local collectStartTime = tick()
                        while tick() - collectStartTime < 10 do
                            if isPoliceNearby() then 
                                ensurePlayerInVehicle()
                                break 
                            end
                            lootVisibleMeshParts(bankRobberyFolder)
                            task.wait(0.5)
                        end
                    end
                    ensurePlayerInVehicle() 
                    if State.autoSellToggle == true then
                        task.wait(.5)
                        MoveToDealer()
                        task.wait(.5)
                        MoveToDealer()
                        task.wait(.5)
                        local args = {"Gold", "Dealer"}
                        RemoteEvents.sell:FireServer(unpack(args))
                        RemoteEvents.sell:FireServer(unpack(args))
                        RemoteEvents.sell:FireServer(unpack(args))
                        task.wait(.5)
                    end
                else
                    sendNotification("Bank vault is not robbable!", "Going to check Jeweler...")
                end
                tweenTo(Locations.jeweler)
                task.wait(0.5)

                if checkSafeRobStatus() then
                    sendNotification("Jeweler Safe is robbable!", "Starting...")
                    ensurePlayerInVehicle()
                    task.wait(0.5)
                    MoveToDealer()
                    task.wait(0.5)
                    local args = {"Bomb", "Dealer"}
                    RemoteEvents.buy:FireServer(unpack(args))
                    task.wait(0.5)
                    tweenTo(Vector3.new(-464.14019775390625, 39.09627151489258, 3556.745849609375))
                    task.wait(0.5)
                    JumpOut()
                    task.wait(0.5)
                    plrTween(Vector3.new(-432.54534912109375, 21.248910903930664, 3553.118896484375))
                    task.wait(0.5)
                    local args = {"Bomb"}
                    RemoteEvents.equip:FireServer(unpack(args))
                    task.wait(0.5)
                    local character = Player.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        local hrp = character.HumanoidRootPart
                        local currentCFrame = hrp.CFrame
                        local rotation = CFrame.Angles(0, math.rad(90), 0)
                        hrp.CFrame = currentCFrame * rotation
                    end
                    task.wait(0.5)
                    local tool = Player.Character:FindFirstChild("Bomb")
                    if tool then
                        SpawnBomb()
                        task.wait(0.5)
                        RemoteEvents.bomb:FireServer()
                    end

                    task.wait(0.5)
                    plrTween(Vector3.new(-414.9098205566406, 21.223400115966797, 3555.1474609375))
                    task.wait(2.1)
                    plrTween(Vector3.new(-438.992919921875, 21.223411560058594, 3553.45166015625))         
                    
                    local jewelerSafeFolder = Workspace.Robberies:FindFirstChild("Jeweler Safe Robbery")
                    if jewelerSafeFolder then
                        local jewelerFolder = jewelerSafeFolder:FindFirstChild("Jeweler")
                        if jewelerFolder then
                            local itemsFolder = jewelerFolder:FindFirstChild("Items")
                            local moneyFolder = jewelerFolder:FindFirstChild("Money")
                            for i = 1, 25 do
                                if isPoliceNearby() then 
                                    ensurePlayerInVehicle()
                                    break 
                                end
                                lootVisibleMeshParts(itemsFolder)
                                lootVisibleMeshParts(moneyFolder)
                                task.wait(0.5)
                            end
                        end
                    end
                    
                    if State.autoSellToggle == true then
                        ensurePlayerInVehicle()
                        task.wait(0.5)
                        MoveToDealer()
                        task.wait(0.5)
                        local args = {"Gold", "Dealer"}
                        RemoteEvents.sell:FireServer(unpack(args))
                        RemoteEvents.sell:FireServer(unpack(args))
                        RemoteEvents.sell:FireServer(unpack(args))
                    end
                else
                    sendNotification("Jeweler Safe is not robbable!", "No more locations to rob left. Changing Server...")
                end
                
                ensurePlayerInVehicle()
                tweenTo(Locations.rejoin)
                Player:Kick("Lynox AutoRob - Rejoining...")
            end
        end

        OrionLib:Init()
    end
    wait(1)
end
