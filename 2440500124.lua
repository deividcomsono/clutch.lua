if game.GameId ~= 2440500124 then return end

local cloneref = cloneref or function(o) return o end
local Lighting = cloneref(game:GetService("Lighting"))
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))
local SoundService = cloneref(game:GetService("SoundService"))
local TextChatService = cloneref(game:GetService("TextChatService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local Midnight, Flags = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Midnight/main/Source.lua"))()

local Console = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/MSDOORS/main/Utils/Console/Utility.lua"))() -- Made by Upio
local message = Console.custom_console_progressbar({
    msg = "[clutch.lua]: Loading...",
    img = "",
    clr = Color3.fromRGB(255, 255, 255),
    length = 5
})

if not game:IsLoaded() then
    game.Loaded:Wait(1)
end

if Players.LocalPlayer.PlayerGui:FindFirstChild("LoadingUI") and Players.LocalPlayer.PlayerGui.LoadingUI.Enabled then
    Midnight:Notify("Waiting for the game to load...", 3)

    repeat 
        task.wait()
    until not Players.LocalPlayer.PlayerGui.LoadingUI.Enabled
end

message.update_message_with_progress("[clutch.lua]: Creating variables...", 1)
-- #region Variables --
local RBXGeneral: TextChannel = TextChatService.TextChannels.RBXGeneral

local originalHook

local connections = {}
local espTable = {
    ["Door"] = {},
    ["Entity"] = {},
    ["Objective"] = {},
    ["Item"] = {},
    ["Gold"] = {},
    ["Player"] = {},
    ["NoType"] = {},
}

local entitiesTable = {
    ["Entities"] = {
        "BackdoorRush", "BackdoorLookman", "RushMoving", "AmbushMoving", "Eyes", "Screech", "JeffTheKiller", "A60", "A120"
    },

    ["Names"] = {
        ["BackdoorRush"] = "Blitz",
        ["BackdoorLookman"] = "Lookman",
        ["RushMoving"] = "Rush",
        ["AmbushMoving"] = "Ambush",
        ["JeffTheKiller"] = "Jeff The Killer"
    }
}
local itemsTable = {
    ["Names"] = {
        ["CrucifixOnWall"] = "Crucifix"
    }
}

local promptTable = {
    ["Clip"] = {
        "HerbPrompt",
        "HidePrompt",
        "LootPrompt",
        "ModulePrompt",
        "UnlockPrompt",
        "Prompt"
    },

    ["ClipObjects"] = {
        "LeverForGate",
        "LiveHintBook",
        "LiveBreakerPolePickup"
    },

    ["Excluded"] = {
        "HintPrompt",
        "InteractPrompt"
    }
}


local exitKeycodes = {
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D
}

local holdAnim = Instance.new("Animation"); holdAnim.AnimationId = "rbxassetid://10479585177"
local throwAnim = Instance.new("Animation"); throwAnim.AnimationId = "rbxassetid://10482563149"
local twerkAnim = Instance.new("Animation"); twerkAnim.AnimationId = "rbxassetid://12874447851"

local holdingObjTrack
local throwObjTrack
local twerkTrack

local holdingObj
local holdingJeff

local throwingObj = false

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local alive = localPlayer:GetAttribute("Alive")

local character = localPlayer.Character
local humanoid
local rootPart
local collision
local collisionClone

local playerGui = localPlayer.PlayerGui

local mainUI = playerGui:WaitForChild("MainUI")
local rawMainGame = mainUI:WaitForChild("Initiator"):WaitForChild("Main_Game")
local mainGame = require(rawMainGame)

local permUI = playerGui:WaitForChild("PermUI")
local hints = permUI:WaitForChild("Hints")

local mainSoundGroup = SoundService:WaitForChild("Main")
local jamSoundEffect = mainSoundGroup:WaitForChild("Jamming")

local entityModules = ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("EntityModules")

local gameData = ReplicatedStorage:WaitForChild("GameData")
local floor = gameData:WaitForChild("Floor")
local latestRoom = gameData:WaitForChild("LatestRoom")

local isBackdoor = floor.Value == "Backdoor"
local isHotel = floor.Value == "Hotel"
local isFools = floor.Value == "Fools"
local isRooms = floor.Value == "Rooms"

local liveModifiers = ReplicatedStorage:WaitForChild("LiveModifiers")

local remotesFolder = isFools and ReplicatedStorage:WaitForChild("EntityInfo") or ReplicatedStorage:WaitForChild("RemotesFolder")

local haltModule
local oldHaltStuff

local glitchModule
local oldGlitchStuff

local eyes

type ESP = {
    Object: Instance,
    Text: string,
    Color: Color3,
    Offset: Vector3,
    IsEntity: boolean
}
-- #endregion --

message.update_message_with_progress("[clutch.lua]: Creating functions...", 2)
-- #region Functions --
function distanceFromCharacter(position)
    if typeof(position) == "Instance" then
        position = position:GetPivot().Position
    end

    if alive then
        return (rootPart.Position - position).Magnitude
    else
        return (workspace.CurrentCamera.CFrame.Position - position).Magnitude
    end

    return 9e9
end

function enableBreaker(breaker, value)
    breaker:SetAttribute("Enabled", value)

    if value then
        breaker:FindFirstChild("PrismaticConstraint", true).TargetPosition = -0.2
        breaker.Light.Material = Enum.Material.Neon
        breaker.Light.Attachment.Spark:Emit(1)
        breaker.Sound.Pitch = 1.3
    else
        breaker:FindFirstChild("PrismaticConstraint", true).TargetPosition = 0.2
        breaker.Light.Material = Enum.Material.Glass
        breaker.Sound.Pitch = 1.2
    end

    breaker.Sound:Play()
end

function esp(params: ESP)
    local EspManager = {
        Type = params.Type or "NoType",
        Object = params.Object,
        Text = params.Text or "No Text",
        TextParent = params.TextParent or nil,
        Color = params.Color or Color3.new(0, 0, 0),

        Offset = params.Offset or Vector3.zero,
        IsEntity = params.IsEntity or false,

        rsConnection = nil
    }

    local tableIndex = #espTable[EspManager.Type] + 1

    local traceDrawing = Drawing.new("Line") do
        traceDrawing.Visible = false
        traceDrawing.Color = EspManager.Color
        traceDrawing.Thickness = 1
    end

    if EspManager.Object and EspManager.IsEntity then
        EspManager.Object:SetAttribute("OldTransparency", EspManager.Object.PrimaryPart.Transparency)
        Instance.new("Humanoid", EspManager.Object)
        EspManager.Object.PrimaryPart.Transparency = 0.99
    end

    local highlight = Instance.new("Highlight") do
        highlight.Adornee = EspManager.Object
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = EspManager.Color
        highlight.FillTransparency = Flags["ESPFillTransparency"].Value
        highlight.OutlineColor = EspManager.Color
        highlight.OutlineTransparency = Flags["ESPOutlineTransparency"].Value
        highlight.Parent = EspManager.Object
    end

    local billboardGui = Instance.new("BillboardGui") do
        billboardGui.Adornee = EspManager.TextParent or EspManager.Object
		billboardGui.AlwaysOnTop = true
		billboardGui.ClipsDescendants = false
		billboardGui.Size = UDim2.new(0, 1, 0, 1)
		billboardGui.StudsOffset = EspManager.Offset
        billboardGui.Parent = EspManager.TextParent or EspManager.Object
	end

    local textLabel = Instance.new("TextLabel") do
		textLabel.BackgroundTransparency = 1
		textLabel.Font = Enum.Font.Oswald
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.Text = EspManager.Text
		textLabel.TextColor3 = EspManager.Color
		textLabel.TextSize = Flags["ESPTextSize"].Value
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextStrokeTransparency = 0.75
        textLabel.Parent = billboardGui
	end

    function EspManager:SetColor(newColor: Color3)
        EspManager.Color = newColor

        highlight.FillColor = newColor
        highlight.OutlineColor = newColor

        textLabel.TextColor3 = newColor

        if traceDrawing then
            traceDrawing.Color = newColor
        end
    end

    function EspManager.Delete()
        if EspManager.rsConnection then
            EspManager.rsConnection:Disconnect()
        end

        if EspManager.IsEntity and EspManager.Object and (EspManager.Object:IsA("Model") and EspManager.Object.PrimaryPart) then
            EspManager.Object.PrimaryPart.Transparency = EspManager.Object:GetAttribute("OldTransparency")
        end

        traceDrawing:Destroy()
        highlight:Destroy()
        billboardGui:Destroy()

        if espTable[EspManager.Type][tableIndex] then
            espTable[EspManager.Type][tableIndex] = nil
        end
    end

    EspManager.rsConnection = RunService.RenderStepped:Connect(function()
        if not EspManager.Object or not EspManager.Object:IsDescendantOf(workspace) or not (EspManager.Object:IsA("Model") and EspManager.Object:GetPivot().Position or EspManager.Object:IsA("BasePart") and EspManager.Object.Position) then
            EspManager.Delete()
            return
        end

        highlight.FillTransparency = Flags["ESPFillTransparency"].Value
        highlight.OutlineTransparency = Flags["ESPOutlineTransparency"].Value
        textLabel.TextSize = Flags["ESPTextSize"].Value
        
        if rawMainGame and rawMainGame:FindFirstChild("PromptService") then 
            local promptHighlight = rawMainGame.PromptService.Highlight

            if promptHighlight and promptHighlight.Adornee and (promptHighlight.Adornee == EspManager.Object or promptHighlight.Adornee.Parent == EspManager.Object.Parent) then
                promptHighlight.Adornee = nil
            end
        end

        if Flags["ESPShowDistance"].Value then
            textLabel.Text = string.format("%s\n[%s]", EspManager.Text, math.ceil(distanceFromCharacter(EspManager.Object:IsA("Model") and EspManager.Object:GetPivot().Position or EspManager.Object:IsA("BasePart") and EspManager.Object.Position)))
        else
            textLabel.Text = EspManager.Text
        end
        
        if Flags["ESPShowTracers"].Value then
            local vector, onScreen = workspace.CurrentCamera:WorldToViewportPoint(EspManager.Object:IsA("Model") and EspManager.Object:GetPivot().Position or EspManager.Object:IsA("BasePart") and EspManager.Object.Position)

            if onScreen then
                traceDrawing.From = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 1)
                traceDrawing.To = Vector2.new(vector.X, vector.Y)
                traceDrawing.Visible = true
            else
                traceDrawing.Visible = false
            end
        else
            traceDrawing.Visible = false
        end
    end)

    espTable[EspManager.Type][tableIndex] = EspManager
    return EspManager
end

function addDoorEsp(room)
    local door = room:WaitForChild("Door")
    local locked = room:GetAttribute("RequiresKey")

    local isLibrary = room.Name == "49" or room.Name == "50"

    if door and door:GetAttribute("Opened") ~= true then
        local doorEsp = esp({
            Type = "Door",
            Object = (isHotel and isLibrary) and door or door:WaitForChild("Door"),
            Text = locked and string.format("Door %s [Locked]", room.Name + 1) or string.format("Door %s", room.Name + 1),
            Color = Flags["DoorESPColor"].Color
        })

        door:GetAttributeChangedSignal("Opened"):Connect(function()
            local value = door:GetAttribute("Opened")
            if doorEsp and value then doorEsp.Delete() end
        end)
    end
end

function addEntityEsp(entity)
    local entityName = getEntityName(entity)
            
    local entityEsp = esp({
        Type = "Entity",
        Object = entity,
        Text = entityName,
        Color = Flags["EntityESPColor"].Color,
        Offset = Vector3.new(0, 4, 0),
        IsEntity = entity.Name ~= "JeffTheKiller" and true or false
    })

    if entityName == "Eyes" then
        entity.PrimaryPart:WaitForChild("Ambience"):GetPropertyChangedSignal("Playing"):Connect(function()
            if not entity.PrimaryPart.Ambience.Playing then
                entityEsp.Delete()
            end
        end)

        task.delay(3, function()
            if not entity.PrimaryPart.Ambience.Playing then
                entityEsp.Delete()
            end
        end)
    end
end

function addObjectiveEsp(room)
    task.spawn(function()
        if not room:WaitForChild("Assets", 3) then return end

        if room:GetAttribute("RequiresKey") then
            local key = room:FindFirstChild("KeyObtain", true)

            if key then
                esp({
                    Type = "Objective",
                    Object = key,
                    Text = "Key",
                    Color = Flags["ObjectiveESPColor"].Color
                })
            end
        end

        if room.Assets:FindFirstChild("LeverForGate") then
            local lever = room.Assets.LeverForGate

            local esp = esp({
                Type = "Objective",
                Object = lever,
                Text = "Lever",
                Color = Flags["ObjectiveESPColor"].Color
            })

            lever.PrimaryPart:WaitForChild("SoundToPlay").Played:Connect(function()
                esp.Delete()
            end)
        elseif room.Name == "100" then
            local key = room.Assets:WaitForChild("ElectricalKeyObtain", 5)
            if key then
                esp({
                    Type = "Objective",
                    Object = key,
                    Text = "Key",
                    Color = Flags["ObjectiveESPColor"].Color
                })
            end
        end
    end)
end

function addItemEsp(item)
    local itemName = itemsTable.Names[item.Name] or item.Name

    esp({
        Type = "Item",
        Object = item,
        Text = itemName,
        Color = Flags["ItemESPColor"].Color
    })
end

function addGoldEsp(gold)
    esp({
        Type = "Gold",
        Object = gold,
        Text = string.format("Gold Pile [%s]", gold:GetAttribute("GoldValue")),
        Color = Flags["GoldESPColor"].Color
    })
end

function addPlayerEsp(player)
    if player.Character.Humanoid.Health == 0 then return end

    local playerEsp = esp({
        Type = "Player",
        Object = player.Character,
        Text = string.format("%s [%s]", player.DisplayName, player.Character.Humanoid.Health),
        TextParent = player.Character:FindFirstChild("HumanoidRootPart"),
        Color = Flags["PlayerESPColor"].Color,
    })

    player.Character.Humanoid.HealthChanged:Connect(function(newHealth)
        if newHealth > 0 then
            playerEsp.Text = string.format("%s [%s]", player.DisplayName, newHealth)
        else
            playerEsp.Delete()
        end
    end)
end

function addRoomEsp(room)
    task.spawn(function()
        if Flags["ESPWhat"].Value.Door then
            addDoorEsp(room)
        end

        if Flags["ESPWhat"].Value.Objective then
            task.delay(room.Name == "50" and 3 or 1, addObjectiveEsp, room)
        end
    end)
end

function addRoomConnection(room)
    room.DescendantAdded:Connect(function(child)
        if rootPart and child:IsA("BasePart") and child.Name == "Collision" then
            if Flags["FEAntiSeek"].Value then
                local currentRoom = latestRoom.Value + 1

                task.spawn(function()
                    repeat
                        firetouchtransmitter(child, rootPart, 1)
                        task.wait()
                        firetouchtransmitter(child, rootPart, 0)
                    until not child or latestRoom.Value > currentRoom
                end)
            elseif Flags["AntiSeek"].Value then
                child.CanTouch = false
            end
        end

        task.delay(0.1, function()
            if child:IsDescendantOf(workspace) and child:IsA("ProximityPrompt") and not table.find(promptTable.Excluded, child.Name) then
                if not child:GetAttribute("OriginalDistance") then
                    child:SetAttribute("OriginalDistance", child.MaxActivationDistance)
                end
                if not child:GetAttribute("OriginalEnabled") then
                    child:SetAttribute("OriginalEnabled", child.Enabled)
                end
                if not child:GetAttribute("OriginalClip") then
                    child:SetAttribute("OriginalClip", child.RequiresLineOfSight)
                end
                
                child.MaxActivationDistance = child:GetAttribute("OriginalDistance") * Flags["PromptRangeBoost"].Value
                
                if isFools and Flags["InstaInteract"].Value then
                    if not child:GetAttribute("OriginalDuration") then
                        child:SetAttribute("OriginalDuration", child.HoldDuration)
                    end

                    child.HoldDuration = 0
                end

                if child:IsDescendantOf(workspace) and Flags["PromptClip"].Value and (table.find(promptTable.Clip, child.Name) or table.find(promptTable.ClipObjects, child.Parent.Name)) then
                    child.Enabled = true
                    child.RequiresLineOfSight = false
    
                    if child.Name == "ModulePrompt" then
                        child:GetPropertyChangedSignal("Enabled"):Connect(function()
                            if Flags["PromptClip"].Value then
                                child.Enabled = true
                            end
                        end) 
                    end
                end
            end
    
            if mainGame.stopcam and child.Name == "ElevatorBreaker" and Flags["AutoBreakerBox"].Value then
                local autoConnections = {}
                local using = false
    
                if not child:GetAttribute("DreadReaction") then
                    child:SetAttribute("DreadReaction", true)
                    using = true
    
                    if not (child:WaitForChild("SurfaceGui", 5) and child.SurfaceGui:WaitForChild("Frame", 5)) then return warn("Could not find elevator breaker gui") end
                    local code = child.SurfaceGui.Frame:WaitForChild("Code", 5)
    
                    local breakers = {}
                    for _, breaker in pairs(child:GetChildren()) do
                        if breaker.Name == "BreakerSwitch" then
                            local id = string.format("%02d", breaker:GetAttribute("ID"))
                            breakers[id] = breaker
                        end
                    end
    
                    if code and code:FindFirstChild("Frame") then   
                        local correct = child.Box.Correct
                        local used = {}
                        
                        autoConnections["Reset"] = correct:GetPropertyChangedSignal("Playing"):Connect(function()
                            if correct.Playing then
                                table.clear(used)
                            end
                        end)
    
                        autoConnections["Code"] = code:GetPropertyChangedSignal("Text"):Connect(function()
                            task.wait(0.1)
                            local newCode = code.Text
                            local isEnabled = code.Frame.BackgroundTransparency == 0
    
                            local breaker = breakers[newCode]
    
                            if newCode == "??" and #used == 9 then
                                for i = 1, 10 do
                                    local id = string.format("%02d", i)
    
                                    if not table.find(used, id) then
                                        breaker = breakers[id]
                                    end
                                end
                            end
    
                            if breaker then
                                table.insert(used, newCode)
                                if breaker:GetAttribute("Enabled") ~= isEnabled then
                                    enableBreaker(breaker, isEnabled)
                                end
                            end
                        end)
                    end
    
                    repeat
                        task.wait()
                    until not child or not mainGame.stopcam or not Flags["AutoBreakerBox"].Value or not using
    
                    if child then child:SetAttribute("DreadReaction", nil) end
                end
    
                for _, connection in pairs(autoConnections) do
                    connection:Disconnect()
                end
            end
    
            if Flags["ESPWhat"].Value.Entity then
                if child.Name == "FigureRagdoll" then
                    esp({
                        Type = "Entity",
                        Object = child,
                        Text = "Figure",
                        Color = Flags["EntityESPColor"].Color
                    })
                elseif child.Name == "Snare" then
                    esp({
                        Type = "Entity",
                        Object = child,
                        Text = "Snare",
                        Color = Flags["EntityESPColor"].Color
                    })
                end
            end
            if Flags["ESPWhat"].Value.Objective then
                if child.Name == "LiveHintBook" then
                    esp({
                        Type = "Objective",
                        Object = child,
                        Text = "Book",
                        Color = Flags["ObjectiveESPColor"].Color
                    })
                elseif child.Name == "LiveBreakerPolePickup" then               
                    esp({
                        Type = "Objective",
                        Object = child,
                        Text = "Breaker",
                        Color = Flags["ObjectiveESPColor"].Color
                    })
                end
            end
            if Flags["ESPWhat"].Value.Gold then
                if child.Name == "GoldPile" then
                    addGoldEsp(child)
                end  
            end

            if child:IsA("Model") and (child:GetAttribute("Pickup") or child:GetAttribute("PropType")) and not child:GetAttribute("JeffShop") then
                if child.Parent.Name == "Assets" and child.Parent.Parent:FindFirstChild("Green_Herb") then return end
                local itemName = itemsTable.Names[child.Name] or child.Name

                if Flags["ESPWhat"].Value.Item then
                    addItemEsp(child)
                end

                if Flags["NotifyItems"].Value then
                    Midnight:Notify(Flags["ItemChatMessage"].Text:gsub("{item}", itemName), 5)

                    if Flags["ChatNotify"].Value then
                        RBXGeneral:SendAsync(Flags["ItemChatMessage"].Text:gsub("{item}", itemName))
                    end
                end    
            end

            if isFools and Flags["AntiGreed"].Value and child.Name == "GoldPile" then
                local greedLevel = localPlayer:GetAttribute("Greed")

                if greedLevel and child:FindFirstChild("LootPrompt") then
                    if greedLevel >= 6 then
                        child.LootPrompt.Enabled = false
                    else
                        child.LootPrompt.Enabled = true
                    end
                end 
            end
            if Flags["AntiObstructions"].Value then
                if child.Name == "HurtPart" then
                    child.CanTouch = false
                elseif child.Name == "AnimatorPart" then
                    child.CanTouch = false
                end
            end
            if Flags["AntiDupe"].Value and child.Name == "DoorFake" and child.Parent.Name:match("Closet") then
                disableDupe(child.Parent, true)
            end
            if Flags["AntiSnare"].Value and child.Name == "Snare" then
                child:WaitForChild("Hitbox", 5).CanTouch = false
            end
        end)
    end)

    task.delay(0.1, function()
        if room.Name == "50" and Flags["DeleteFigure"].Value then
            local figureSetup = room:WaitForChild("FigureSetup", 5)

            if figureSetup then
                local figure = figureSetup:WaitForChild("FigureRagdoll", 5)

                if figure and figure:WaitForChild("Root", 1) then
                    Midnight:Notify("Trying to delete figure...")

                    for _, part in pairs(figure:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end

                    repeat
                        task.wait()
                        figure:PivotTo(figure.PrimaryPart.CFrame * CFrame.new(0, -1000, 0))
                    until not figure or latestRoom.Value > 49

                    if not figure then
                        Midnight:Notify("Figure has been deleted")
                    end
                end
            end
        end
    end)
end

function disableDupe(closet, value)
    local doorFake = closet:WaitForChild("DoorFake", 5)

    if doorFake then
        doorFake:WaitForChild("Hidden", 5).CanTouch = not value
        local lock = doorFake:WaitForChild("LockPart", 5)

        if lock and lock:FindFirstChild("UnlockPrompt") then
            lock.UnlockPrompt.Enabled = not value
        end
    end
end

function setupCharacterConnection(newCharacter)
    if not newCharacter then return warn("Invalid character") end

    
    character = newCharacter
    connections["CharacterChildAdded"] = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name:match("LibraryHintPaper") then
            task.wait()
            local code = table.concat(getPadlockCode(child))
            local output, count = code:gsub("_", "x")

            if Flags["AutoPadlock"].Value and tonumber(code) then
                remotesFolder.PL:FireServer(code)
            end

            if count < 5 then
                if Flags["NotifyPadlockCode"].Value then
                    Midnight:Notify(string.format("The padlock code is: %s", output))
                end
            end
        end
    end)

    humanoid = character:WaitForChild("Humanoid")
    if humanoid then
        if humanoid.Health > 0 then
            holdingObjTrack = humanoid:LoadAnimation(holdAnim)
            throwObjTrack = humanoid:LoadAnimation(throwAnim)
            twerkTrack = humanoid:LoadAnimation(twerkAnim)

            if Flags["Twerk"].Value then
                twerkTrack:Play()
            end
        end

        connections["HumanoidDied"] = humanoid.Died:Connect(function()
            if collisionClone then
                collisionClone:Destroy()
            end
        end)
    end

    rootPart = character:WaitForChild("HumanoidRootPart")
    if rootPart then
        if Flags["NoAcceleration"].Value then
            rootPart.CustomPhysicalProperties = PhysicalProperties.new(100, 0, 0, 0, 0)
        end
    end

    collision = character:WaitForChild("Collision")

    collisionClone = collision:Clone()
    collisionClone.CanCollide = false
    collisionClone.Massless = true
    collisionClone.Name = "CollisionClone"
    if collisionClone:FindFirstChild("CollisionCrouch") then
        collisionClone.CollisionCrouch:Destroy()
    end
    collisionClone.Parent = character
end

function getEntityName(entity)
    local entityName = entitiesTable.Names[entity.Name] or entity.Name

    if isFools and entityName == "Rush" then
        entityName = entity.PrimaryPart.Name:gsub("New", "")
    end

    return entityName
end

function getEntitiesName()
    local names = {}

    for _, entity in pairs(entitiesTable.Entities) do
        local entityName = entitiesTable.Names[entity] or entity

        table.insert(names, entityName)
    end    

    return names
end

function getPadlockCode(paper)
    if paper and paper:FindFirstChild("UI") then
        local code = {}

        for _, image: ImageLabel in pairs(paper.UI:GetChildren()) do
            if image:IsA("ImageLabel") and tonumber(image.Name) then
                code[image.ImageRectOffset.X .. " " .. image.ImageRectOffset.Y] = {tonumber(image.Name), "_"}
            end
        end

        for _, image in pairs(hints:GetChildren()) do
            if image.Name == "Icon" then
                if code[image.ImageRectOffset.X .. " " .. image.ImageRectOffset.Y] then
                    code[image.ImageRectOffset.X .. " " .. image.ImageRectOffset.Y][2] = image.TextLabel.Text
                end
            end
        end

        local normalizedCode = {}
        for _, num in pairs(code) do
            normalizedCode[num[1]] = num[2]
        end

        return normalizedCode
    end

    return {}
end
-- #endregion --

message.update_message_with_progress("[clutch.lua]: Creating library...", 3)
-- #region Library --

local Window = Midnight:CreateWindow({
    Title = "clutch.lua",
    SaveFolder = "clutch.lua"
})


local SpeedSlider
local NoclipToggle

local PlayerTab = Window:AddTab("Player") do
    local Speed = PlayerTab:AddElementToggle({
        Name = "Speed",
        Flag = "Speed"
    })

    SpeedSlider = Speed:AddSlider({
        Name = "Speed Boost",
        Flag = "SpeedBoost",
        Increment = 0.5,
        Min = 0,
        Max = isFools and 50 or 7,
    })

    Speed:AddDropdown({
        Name = "Mode",
        Flag = "SpeedMethod",
        AllowNull = false,
        Values = {"Boost", "WalkSpeed"},
        Value = "Boost",
        Callback = function()
            if humanoid then
                humanoid.WalkSpeed = 15
                humanoid:SetAttribute("SpeedBoostBehind", 0)
            end
        end
    })

    PlayerTab:AddElementToggle({
        Name = "Noclip",
        Flag = "Noclip"
    })

    PlayerTab:AddElementToggle({
        Name = "No Acceleration",
        Flag = "NoAcceleration",
        Callback = function(value)
            if rootPart then
                rootPart.CustomPhysicalProperties = value and PhysicalProperties.new(100, 0, 0, 0, 0) or PhysicalProperties.new(0.7, 0.7, 0, 1, 1)
            end
        end
    })

    local Reach = PlayerTab:AddElementSection("Reach") do
        Reach:AddToggle({
            Name = "Door Reach",
            Flag = "DoorReach"
        })

        Reach:AddToggle({
            Name = "Prompt Clip",
            Flag = "PromptClip",
            Callback = function(value)
                for _, prompt: ProximityPrompt in pairs(workspace.CurrentRooms:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and (table.find(promptTable.Clip, prompt.Name) or table.find(promptTable.ClipObjects, prompt.Parent.Name)) then
                        if value then
                            if not prompt:GetAttribute("OriginalEnabled") then
                                prompt:SetAttribute("OriginalEnabled", prompt.Enabled)
                            end
                            if not prompt:GetAttribute("OriginalClip") then
                                prompt:SetAttribute("OriginalClip", prompt.RequiresLineOfSight)
                            end

                            prompt.Enabled = true
                            prompt.RequiresLineOfSight = false
                        else
                            prompt.Enabled = prompt:GetAttribute("OriginalEnabled") or true
                            prompt.RequiresLineOfSight = prompt:GetAttribute("OriginalClip") or true
                        end
                    end
                end
            end
        })

        Reach:AddSlider({
            Name = "Prompt Range Boost",
            Flag = "PromptRangeBoost",
            Increment = 0.05,
            Min = 1,
            Max = 2,
            Callback = function(value)
                for _, prompt: ProximityPrompt in pairs(workspace.CurrentRooms:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and not table.find(promptTable.Excluded, prompt.Name) then
                        if not prompt:GetAttribute("OriginalDistance") then
                            prompt:SetAttribute("OriginalDistance", prompt.MaxActivationDistance)
                        end

                        prompt.MaxActivationDistance = prompt:GetAttribute("OriginalDistance") * value
                    end
                end
            end
        })
    end

    PlayerTab:AddElementToggle({
        Name = "Fix Exit Delay",
        Flag = "FixExitDelay"
    })

    PlayerTab:AddElementToggle({
        Name = "Twerk",
        Flag = "Twerk",
        Callback = function(value)
            if not humanoid then return end

            if value then                
                twerkTrack:Play()
            else
                twerkTrack:Stop()
            end
        end
    })

    local MiscSection = PlayerTab:AddElementSection("Misc") do
        MiscSection:AddButton({
            Name = "Die",
            DoubleClick = true,
            Callback = function()
                if not humanoid then return end
                humanoid.Health = 0
            end
        })

        MiscSection:AddButton({
            Name = "Revive",
            DoubleClick = true,
            Callback = function()
                remotesFolder.Revive:FireServer()
            end
        })

        MiscSection:AddButton({
            Name = "Play Again",
            DoubleClick = true,
            Callback = function()
                remotesFolder.PlayAgain:FireServer()

                local queueing = not localPlayer:GetAttribute("Ready")
                if queueing then
                    Midnight:Notify("Teleporting, click again to cancel")
                else
                    Midnight:Notify("Teleport cancelled")
                end
            end
        })

        MiscSection:AddButton({
            Name = "Lobby",
            DoubleClick = true,
            Callback = function()
                remotesFolder.Lobby:FireServer()
            end
        })
    end
end

local ExploitTab = Window:AddTab("Exploits") do
    ExploitTab:AddElementToggle({
        Name = "Speed Bypass",
        Flag = "SpeedBypass",
        Callback = function(value)
            if isFools then return Midnight:Notify("Speed Bypass is not supported on Hard Mode") end

            if value then
                SpeedSlider:SetMax(50)
                while task.wait(0.215) and Flags["SpeedBypass"].Value do
                    if collisionClone then
                        collisionClone.Massless = false
                        task.wait(0.215)
                        collisionClone.Massless = true
                    end
                end
            else
                SpeedSlider:SetMax(7)
            end
        end
    })

    local oldNoclip = Flags["Noclip"].Value
    local NoclipBypassToggle = ExploitTab:AddElementToggle({
        Name = "Noclip Bypass",
        Flag = "NoclipBypass",
        Callback = function(value)
            if value then
                oldNoclip = Flags["Noclip"].Value

                Flags["Noclip"]:SetLocked(true)
                Flags["Noclip"]:Set(true)

                task.wait()
                
                if collision then
                    collision.Weld.C0 = CFrame.new(-Flags["NoclipBypassOffset"].Value, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
                end
            else
                if collision then
                    collision.Weld.C0 = CFrame.new() * CFrame.Angles(0, 0, math.rad(90))
                end

                task.wait()

                Flags["Noclip"]:Set(oldNoclip)
                Flags["Noclip"]:SetLocked(false)
            end
        end
    }) do
        NoclipBypassToggle:AddSlider({
            Name = "Offset",
            Flag = "NoclipBypassOffset",
            Min = 7,
            Max = 10,
            Value = 8,
            Callback = function(value)
                if Flags["NoclipBypass"].Value and collision then
                    collision.Weld.C0 = CFrame.new(-value, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
                end
            end
        })
    end

    local EntitiesSection = ExploitTab:AddElementSection("Bypass Entities") do
        EntitiesSection:AddToggle({
            Name = "Anti Dupe",
            Flag = "AntiDupe",
            Callback = function(value)
                for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
                    for _, closet in pairs(room:GetChildren()) do
                        if closet.Name:match("Closet") and closet:FindFirstChild("DoorFake") then
                            disableDupe(closet, value)
                        end
                    end
                end
            end
        })

        EntitiesSection:AddToggle({
            Name = "Anti Snare",
            Flag = "AntiSnare",
            Callback = function(value)
                for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
                    if not room:FindFirstChild("Assets") then return end
                    for _, snare in pairs(room.Assets:GetChildren()) do
                        if snare.Name == "Snare" then
                            snare:WaitForChild("Hitbox", 5).CanTouch = not value
                        end
                    end
                end
            end
        })

        EntitiesSection:AddToggle({
            Name = "Anti Seek",
            Flag = "AntiSeek",
            Callback = function(value)
                for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
                    if room:FindFirstChild("TriggerEventCollision") then
                        for _, part in pairs(room.TriggerEventCollision:GetChildren()) do
                            part.CanTouch = not value
                        end
                    end
                end
            end
        })

        EntitiesSection:AddToggle({
            Name = "Anti Seek [FE]",
            Flag = "FEAntiSeek"
        })

        EntitiesSection:AddToggle({
            Name = "Anti Obstructions",
            Flag = "AntiObstructions",
            Callback = function(value)
                for _, obstruction in pairs(workspace.CurrentRooms:GetDescendants()) do
                    if obstruction.Name == "HurtPart" then
                        obstruction.CanTouch = not value
                    elseif obstruction.Name == "AnimatorPart" then
                        obstruction.CanTouch = not value
                    end
                end
            end
        })

        EntitiesSection:AddToggle({
            Name = "Delete Figure",
            Flag = "DeleteFigure",
            Callback = function(value)
                if value and latestRoom.Value == 49 then
                    local figure = workspace.CurrentRooms:FindFirstChild("FigureRagdoll", true)

                    if figure then
                        Midnight:Notify("Trying to delete figure...")

                        for _, part in pairs(figure:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end

                        repeat
                            task.wait()
                            figure:PivotTo(figure.PrimaryPart.CFrame * CFrame.new(0, -1000, 0))
                        until not figure or latestRoom.Value > 49

                        if not figure then
                            Midnight:Notify("Figure has been deleted")
                        end
                    end
                end
            end
        })

        EntitiesSection:AddToggle({
            Name = "No Eyes Damage",
            Flag = "NoEyesDamage"
        })
    
        EntitiesSection:AddToggle({
            Name = "No Glitch",
            Flag = "NoGlitch",
            Callback = function(value)
                if not glitchModule then return end

                if value then
                    glitchModule.stuff = function(...) print("Glich Module called") end
                else 
                    glitchModule.stuff = oldGlitchStuff
                end
            end
        })

        EntitiesSection:AddToggle({
            Name = "No Halt",
            Flag = "NoHalt",
            Callback = function(value)
                if not haltModule then return end

                if value then
                    haltModule.stuff = function(...) print("Halt Module called") end
                else 
                    haltModule.stuff = oldHaltStuff
                end
            end
        })
    
        EntitiesSection:AddToggle({
            Name = "No Screech",
            Flag = "NoScreech",
            Callback = function(value)
                for _, connection in pairs(getconnections(remotesFolder.Screech.OnClientEvent)) do
                    if value then
                        connection:Disable()
                    else 
                        connection:Enable()
                    end
                end
            end
        })

        EntitiesSection:AddToggle({
            Name = "No A-90",
            Flag = "NoA90",
            Callback = function(value)
                for _, connection in pairs(getconnections(remotesFolder.A90.OnClientEvent)) do
                    if value then
                        connection:Disable()
                    else 
                        connection:Enable()
                    end
                end
            end
        })
    end
end

local VisualsTab = Window:AddTab("Visuals") do
    local AmbientSection = VisualsTab:AddElementSection("Ambient") do
        AmbientSection:AddToggle({
            Name = "Fullbright",
            Flag = "Fullbright",
            Callback = function(value)
                if value then
                    Lighting.Ambient = Color3.new(1, 1, 1)
                else
                    if character then
                        Lighting.Ambient = workspace.CurrentRooms[localPlayer:GetAttribute("CurrentRoom")]:GetAttribute("Ambient")
                    else
                        Lighting.Ambient = Color3.fromRGB(67, 51, 56)
                    end
                end
            end
        })

        if liveModifiers:FindFirstChild("Fog") then
            AmbientSection:AddToggle({
                Name = "No Fog",
                Flag = "NoFog",
                Callback = function(value)
                    if value then
                        Lighting.Fog.Density = 0
                    else
                        Lighting.Fog.Density = 0.938
                    end
                end
            })
        end
    end

    local CamManipulation = VisualsTab:AddElementSection("Camera Manipulation") do
        CamManipulation:AddToggle({
            Name = "No Camera Bob",
            Flag = "NoCamBob"
        })
    
        CamManipulation:AddToggle({
            Name = "No Camera Shake",
            Flag = "NoCamShake"
        })
    
        CamManipulation:AddSlider({
            Name = "Field Of View",
            Flag = "FOV",
            Value = 70,
            Min = 70,
            Max = 120
        })
    end

    local Esp = VisualsTab:AddElementSection("ESP") do
        Esp:AddDropdown({
            Name = "What",
            Flag = "ESPWhat",
            Multi = true,
            Values = {"Door", "Entity", "Objective", "Item", "Gold", "Player"},
            Callback = function(value, oldValue)
                if value.Door ~= oldValue.Door then
                    if value.Door then
                        for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
                            addDoorEsp(room)
                        end
                    else
                        for _, esp in pairs(espTable.Door) do
                            esp.Delete()
                        end
                    end
                end

                if value.Entity ~= oldValue.Entity then
                    if value.Entity then
                        for _, child in pairs(workspace:GetChildren()) do
                            if child:IsA("Model") and table.find(entitiesTable.Entities, child.Name) and distanceFromCharacter(child:GetPivot().Position) < 2000 then
                                addEntityEsp(child)
                            end
                        end

                        for _, child in pairs(workspace.CurrentRooms:GetDescendants()) do
                            if child.Name == "FigureRagdoll" then
                                esp({
                                    Type = "Entity",
                                    Object = child,
                                    Text = "Figure",
                                    Color = Flags["EntityESPColor"].Color
                                })
                            elseif child.Name == "Snare" then
                                esp({
                                    Type = "Entity",
                                    Object = child,
                                    Text = "Snare",
                                    Color = Flags["EntityESPColor"].Color
                                })
                            end
                        end
                    else
                        for _, esp in pairs(espTable.Entity) do
                            esp.Delete()
                        end
                    end
                end

                if value.Objective ~= oldValue.Objective then
                    if value.Objective then
                        for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
                            addObjectiveEsp(room)
                        end
                    else
                        for _, esp in pairs(espTable.Objective) do
                            esp.Delete()
                        end
                    end
                end

                if value.Item ~= oldValue.Item then
                    if value.Item then
                        for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
                            if not room:FindFirstChild("Assets") then return end

                            for _, item in pairs(room.Assets:GetDescendants()) do
                                if item:IsA("Model") and (item:GetAttribute("Pickup") or item:GetAttribute("PropType")) and not item:GetAttribute("JeffShop") then
                                    addItemEsp(item)
                                end
                            end
                        end
                    else
                        for _, esp in pairs(espTable.Item) do
                            esp.Delete()
                        end
                    end
                end

                if value.Gold ~= oldValue.Gold then
                    if value.Gold then
                        for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
                            if not room:FindFirstChild("Assets") then return end

                            for _, gold in pairs(room.Assets:GetDescendants()) do
                                if gold.Name == "GoldPile" then
                                    addGoldEsp(gold)
                                end
                            end
                        end
                    else
                        for _, esp in pairs(espTable.Gold) do
                            esp.Delete()
                        end
                    end
                end

                if value.Player ~= oldValue.Player then
                    if value.Player then
                        for _, player in pairs(Players:GetPlayers()) do
                            if player == localPlayer or not player.Character then continue end
                            addPlayerEsp(player)
                        end
                    else
                        for _, esp in pairs(espTable.Player) do
                            esp.Delete()
                        end
                    end
                end
            end
        })

        Esp:AddDivider()

        Esp:AddColorPicker({
            Name = "Door ESP Color",
            Flag = "DoorESPColor",
            Color = Color3.new(0, 1, 1),
            Callback = function(color)
                for _, esp in pairs(espTable.Door) do
                    esp:SetColor(color)
                end
            end
        })

        Esp:AddColorPicker({
            Name = "Entity ESP Color",
            Flag = "EntityESPColor",
            Color = Color3.new(1, 0, 0),
            Callback = function(color)
                for _, esp in pairs(espTable.Entity) do
                    esp:SetColor(color)
                end
            end
        })

        Esp:AddColorPicker({
            Name = "Objective ESP Color",
            Flag = "ObjectiveESPColor",
            Color = Color3.new(0, 1, 0),
            Callback = function(color)
                for _, esp in pairs(espTable.Objective) do
                    esp:SetColor(color)
                end
            end
        })

        Esp:AddColorPicker({
            Name = "Item ESP Color",
            Flag = "ItemESPColor",
            Color = Color3.new(1, 0, 1),
            Callback = function(color)
                for _, esp in pairs(espTable.Item) do
                    esp:SetColor(color)
                end
            end
        })

        Esp:AddColorPicker({
            Name = "Gold ESP Color",
            Flag = "GoldESPColor",
            Color = Color3.new(1, 1, 0),
            Callback = function(color)
                for _, esp in pairs(espTable.Gold) do
                    esp:SetColor(color)
                end
            end
        })

        Esp:AddColorPicker({
            Name = "Player ESP Color",
            Flag = "PlayerESPColor",
            Color = Color3.new(1, 1, 1),
            Callback = function(color)
                for _, esp in pairs(espTable.Player) do
                    esp:SetColor(color)
                end
            end
        })

        Esp:AddDivider()

        Esp:AddToggle({
            Name = "Show Tracers",
            Flag = "ESPShowTracers",
            Value = false
        })

        Esp:AddToggle({
            Name = "Show Distance",
            Flag = "ESPShowDistance",
            Value = false
        })

        Esp:AddSlider({
            Name = "Text Size",
            Flag = "ESPTextSize",
            Min = 16,
            Max = 26,
            Value = 22,
        })

        Esp:AddSlider({
            Name = "Fill Transparency",
            Flag = "ESPFillTransparency",
            Increment = 0.05,
            Min = 0,
            Max = 1,
            Value = 0.5
        })

        Esp:AddSlider({
            Name = "Outline Transparency",
            Flag = "ESPOutlineTransparency",
            Increment = 0.05,
            Min = 0,
            Max = 1,
            Value = 0
        })
    end

    local Notifier = VisualsTab:AddElementSection("Notifier") do
        Notifier:AddToggle({
            Name = "Notify in Chat",
            Flag = "ChatNotify"
        })

        Notifier:AddToggle({
            Name = "Notify Padlock Code",
            Flag = "NotifyPadlockCode"
        })

        Notifier:AddDivider()

        Notifier:AddTextbox({
            Name = "Message",
            Flag = "EntityChatMessage",
            Text = "Entity '{entity}' has spawned!"
        })

        Notifier:AddDropdown({
            Name = "Entities",
            Flag = "NotifyEntities",
            Multi = true,
            Values = getEntitiesName(),
            Value = {}
        })

        Notifier:AddDivider()

        Notifier:AddTextbox({
            Name = "Message",
            Flag = "ItemChatMessage",
            Text = "Item '{item}' has spawned!"
        })

        Notifier:AddToggle({
            Name = "Notify Items",
            Flag = "NotifyItems"
        })

        Notifier:AddToggle({
            Name = "Notify Items Drop",
            Flag = "NotifyItemsDrop"
        })
    end

    local HideTimer = VisualsTab:AddElementToggle({
        Name = "Hide Timer",
        Flag = "HideTimer"
    }) do
        HideTimer:AddSlider({
            Name = "Minimum",
            Flag = "HideTimerMin",
            Increment = 1,
            Min = 1,
            Max = 10,
            Value = 5
        })
    end
end

local AutomationTab = Window:AddTab("Automation") do
    AutomationTab:AddElementToggle({
        Name = "Auto Padlock",
        Flag = "AutoPadlock",
        Callback = function(value)
            if character then
                local tool = character:FindFirstChildOfClass("Tool")

                if tool and tool.Name:match("LibraryHintPaper") then
                    local code = table.concat(getPadlockCode(tool))
                    local output, count = code:gsub("_", "x")

                    if value and tonumber(code) then
                        remotesFolder.PL:FireServer(code)
                    end

                    if count < 5 then
                        if Flags["NotifyPadlockCode"].Value then
                            Midnight:Notify(string.format("The padlock code is: %s", output))
                        end
                    end
                end
            end
        end
    })

    AutomationTab:AddElementToggle({
        Name = "Auto Breaker Box",
        Flag = "AutoBreakerBox",
        Callback = function(value)
            if value then
                local autoConnections = {}
                local using = false

                if mainGame.stopcam and workspace.CurrentRooms:FindFirstChild("100") then
                    local elevatorBreaker = workspace.CurrentRooms["100"]:FindFirstChild("ElevatorBreaker")

                    if elevatorBreaker and not elevatorBreaker:GetAttribute("DreadReaction") then
                        elevatorBreaker:SetAttribute("DreadReaction", true)
                        using = true 

                        local code = elevatorBreaker:FindFirstChild("Code", true)

                        local breakers = {}
                        for _, breaker in pairs(elevatorBreaker:GetChildren()) do
                            if breaker.Name == "BreakerSwitch" then
                                local id = string.format("%02d", breaker:GetAttribute("ID"))
                                breakers[id] = breaker
                            end
                        end

                        if code and code:FindFirstChild("Frame") then
                            local correct = elevatorBreaker.Box.Correct
                            local used = {}
                            
                            autoConnections["Reset"] = correct:GetPropertyChangedSignal("Playing"):Connect(function()
                                if correct.Playing then
                                    table.clear(used)
                                end
                            end)

                            autoConnections["Code"] = code:GetPropertyChangedSignal("Text"):Connect(function()
                                task.wait(0.1)
                                local newCode = code.Text
                                local isEnabled = code.Frame.BackgroundTransparency == 0

                                local breaker = breakers[newCode]

                                if newCode == "??" and #used == 9 then
                                    for i = 1, 10 do
                                        local id = string.format("%02d", i)

                                        if not table.find(used, id) then
                                            breaker = breakers[id]
                                        end
                                    end
                                end

                                if breaker then
                                    table.insert(used, newCode)
                                    if breaker:GetAttribute("Enabled") ~= isEnabled then
                                        enableBreaker(breaker, isEnabled)
                                    end
                                end
                            end)
                        end
                    end

                    repeat
                        task.wait()
                    until not elevatorBreaker or not mainGame.stopcam or not Flags["AutoBreakerBox"].Value or not using

                    if elevatorBreaker then elevatorBreaker:SetAttribute("DreadReaction", nil) end
                end

                for _, connection in pairs(autoConnections) do
                    connection:Disconnect()
                end
            end
        end
    })

    local oldHalt = false
    local oldScreech = false
    local oldSpeedBypass = false
    local AutoDoorsToggle = AutomationTab:AddElementToggle({
        Name = "Auto Doors",
        Callback = function(value)
            if value then
                oldHalt = Flags["NoHalt"].Value
                Flags["NoHalt"]:SetLocked(true)
                Flags["NoHalt"]:Set(true)

                oldScreech = Flags["NoScreech"].Value
                Flags["NoScreech"]:SetLocked(true)
                Flags["NoScreech"]:Set(true)

                if Flags["AutoDoorsSpeed"].Value > 22 then
                    oldSpeedBypass = Flags["SpeedBypass"].Value
                    Flags["SpeedBypass"]:SetLocked(true)
                    Flags["SpeedBypass"]:Set(true)
                end
            else
                Flags["NoHalt"]:SetLocked(false)
                Flags["NoHalt"]:Set(oldHalt)

                Flags["NoScreech"]:SetLocked(false)
                Flags["NoScreech"]:Set(oldScreech)
            end
        end
    }) do
        AutoDoorsToggle:AddSlider({
            Name = "Speed",
            Flag = "AutoDoorsSpeed",
            Increment = 1,
            Min = 15,
            Max = 60,
            Callback = function(value)
                if AutoDoorsToggle.Value then
                    if value > 22 then
                        Flags["SpeedBypass"]:SetLocked(true)
                        Flags["SpeedBypass"]:Set(true)
                    else
                        oldSpeedBypass = Flags["SpeedBypass"].Value
                    end
                else
                    Flags["SpeedBypass"]:SetLocked(false)
                    Flags["SpeedBypass"]:Set(oldSpeedBypass)
                end
            end
        })

        AutoDoorsToggle:AddToggle({
            Name = "Get Herb",
            Flag = "AutoDoorsHerb"
        })

        AutoDoorsToggle:AddSlider({
            Name = "Max Room",
            Flag = "AutoDoorsMaxRoom",
            Increment = 1,
            Min = 1,
            Max = 100,
            Value = 100
        })
    end
end

if #liveModifiers:GetChildren() > 0 then
    local ModifiersTab = Window:AddTab("Modifiers") do
        if liveModifiers:FindFirstChild("Jammin") then
            ModifiersTab:AddElementToggle({
                Name = "No Jammin",
                Flag = "NoJammin",
                Callback = function(value)
                    if value then
                        rawMainGame.Health.Jam.Volume = 0
                        jamSoundEffect.Enabled = false
                    else
                        jamSoundEffect.Enabled = true
                        rawMainGame.Health.Jam.Volume = 0.45
                    end
                end
            })
        end
    end
end

if not isHotel then
    local FloorTab = Window:AddTab("Floor") do
        if isBackdoor then

        elseif isFools then
            FloorTab:AddElementToggle({
                Name = "Insta Interact",
                Flag = "InstaInteract",
                Callback = function(value)
                    for _, prompt in pairs(workspace.CurrentRooms:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") then
                            if value then
                                if not prompt:GetAttribute("OriginalDuration") then
                                    prompt:SetAttribute("OriginalDuration", prompt.HoldDuration)
                                end

                                prompt.HoldDuration = 0
                            else
                                prompt.HoldDuration = prompt:GetAttribute("OriginalDuration") or 0
                            end
                        end
                    end
                end
            })

            FloorTab:AddElementToggle({
                Name = "Auto Revive",
                Flag = "AutoRevive",
                Callback = function(value)
                    if value then
                        while Flags["AutoRevive"].Value do
                            if not alive then remotesFolder.Revive:FireServer() end
                            task.wait(0.75)
                        end
                    end
                end
            })

            local GrabBananaToggle = FloorTab:AddElementToggle({
                Name = "Grab Banana",
                Flag = "GrabBanana",
                Callback = function(value)
                    if not value and holdingObj and holdingObj.Name == "BananaPeel" then
                        holdingObj = nil
                    end
                end
            }) do
                GrabBananaToggle:AddSlider({
                    Name = "Throw Power",
                    Flag = "BananaThrowPower",
                    Min = 5,
                    Max = 20,
                    Value = 6,
                })
            end

            local GrabJeffToggle =  FloorTab:AddElementToggle({
                Name = "Grab Jeff",
                Flag = "GrabJeff",
                Callback = function(value)
                    if not value and holdingJeff then
                        holdingObj = nil
                        holdingJeff = nil
                    end
                end
            }) do
                GrabJeffToggle:AddSlider({
                    Name = "Throw Power",
                    Flag = "JeffThrowPower",
                    Min = 5,
                    Max = 20,
                    Value = 10,
                })
            end

            local EntitiesSection = FloorTab:AddElementSection("Bypass Entities") do
                EntitiesSection:AddToggle({
                    Name = "Anti Banana",
                    Flag = "AntiBanana",
                    Callback = function(value)
                        for _, banana in pairs(workspace:GetChildren()) do
                            if banana.Name == "BananaPeel" then
                                print("hey", not value)
                                banana.CanTouch = not value
                            end
                        end
                    end
                })

                EntitiesSection:AddToggle({
                    Name = "Anti Jeff",
                    Flag = "AntiJeff",
                    Callback = function(value)
                        for _, jeff in pairs(workspace:GetChildren()) do
                            if jeff.Name == "JeffTheKiller" then
                                for _, part in pairs(jeff:GetChildren()) do
                                    if part:IsA("BasePart") then
                                        part.CanTouch = not value
                                    end
                                end
                            end
                        end
                    end
                })

                EntitiesSection:AddToggle({
                    Name = "Anti Greed",
                    Flag = "AntiGreed",
                    Callback = function(value)
                        local greedLevel = localPlayer:GetAttribute("Greed")
                        if not greedLevel then return end

                        for _, gold in pairs(workspace.CurrentRooms:GetDescendants()) do
                            if gold.Name == "GoldPile" and gold:FindFirstChild("LootPrompt") then
                                gold.LootPrompt.Enabled = value and (greedLevel >= 6 and false or true) or true
                            end 
                        end
                    end
                })
            end
        elseif isRooms then

        else
            FloorTab:AddLabel("Floor not supported")
        end
    end
end

local SettingsTab = Window:AddTab("Settings") do
    Window:BuildSettingsElement(SettingsTab)

    local CreditsSection = SettingsTab:AddElementSection("Credits") do
        CreditsSection:AddLabel("mstudio45 - Twerk Emote")
        CreditsSection:AddLabel("upio - ESP and FE Anti Seek")
    end
end

Midnight.OnUnload = function()
    if originalHook then
        hookmetamethod(game, "__namecall", originalHook)
    end

    for _, prompt: ProximityPrompt in pairs(workspace.CurrentRooms:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and not table.find(promptTable.Excluded, prompt.Name) then
            prompt.MaxActivationDistance = prompt:GetAttribute("OriginalDistance") or 8
            prompt.Enabled = prompt:GetAttribute("OriginalEnabled") or true
            prompt.RequiresLineOfSight = prompt:GetAttribute("OriginalClip") or true
        end
    end

    if mainGame then
        mainGame.fovtarget = 70
    end

    if character then
        Lighting.Ambient = workspace.CurrentRooms[localPlayer:GetAttribute("CurrentRoom")]:GetAttribute("Ambient")
    else
        Lighting.Ambient = Color3.fromRGB(67, 51, 56)
    end

    if humanoid then
        humanoid:SetAttribute("SpeedBoostBehind", 0)
        humanoid.WalkSpeed = 15
    end

    if rootPart then
        rootPart.CanCollide = true
    end

    if collision then
        collision.CanCollide = not mainGame.crouching
        if collision:FindFirstChild("CollisionCrouch") then
            collision.CollisionCrouch.CanCollide = mainGame.crouching
        end
    end

    collisionClone:Destroy()

    for _, espType in pairs(espTable) do
        for _, esp in pairs(espType) do
            esp.Delete()
        end
    end

    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
end

-- #endregion -

message.update_message_with_progress("[clutch.lua]: Adding Connections...", 4)
-- #region Connections --
task.spawn(function()
    setupCharacterConnection(character)

    setsimulationradius(math.huge, math.huge)

    local success, error = pcall(function()
        glitchModule = require(entityModules.Glitch)
        haltModule = require(entityModules.Shade)
    end)

    if success then
        oldGlitchStuff = glitchModule.stuff
        oldHaltStuff = haltModule.stuff
    else
        Flags["NoGlitch"]:SetLocked(true)
        Flags["NoGlitch"]:Set(false)

        Flags["NoHalt"]:SetLocked(true)
        Flags["NoHalt"]:Set(false)
    end
end)

connections["HideTimer"] = remotesFolder:WaitForChild("HideMonster").OnClientEvent:Connect(function(countdown)
    if Flags["HideTimer"].Value then
        local final = tick() + countdown

        while character:GetAttribute("Hiding") and task.wait() do
            local current = final - tick()

            if current <= 0 then
                mainGame.caption("0", true, 0.1)
                break
            end

            if current <= Flags["HideTimerMin"].Value then
                mainGame.caption(string.format("%.2f", current), true, 0.1)
            end
        end
    end
end)

local mtHook; mtHook = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    
    if getnamecallmethod() == "FireServer" and self.Name == "MotorReplication" and Flags["NoEyesDamage"].Value and eyes then
        args[2] = -85

        return mtHook(self, table.unpack(args))
    end

    return mtHook(self, ...)
end)
originalHook = originalHook or function(...)
    return mtHook(...)
end

for _, room in pairs(workspace.CurrentRooms:GetChildren()) do
    task.spawn(addRoomConnection, room)
end
Midnight:AddConnection(workspace.CurrentRooms.ChildAdded:Connect(function(room)
    addRoomConnection(room)
    addRoomEsp(room)
end))

for _, item in pairs(workspace.Drops:GetChildren()) do
    if Flags["ESPWhat"].Value.Item then
        task.spawn(addItemEsp, item)
    end
end
Midnight:AddConnection(workspace.Drops.ChildAdded:Connect(function(child)
    local itemName = itemsTable.Names[child.Name] or child.Name

    if Flags["ESPWhat"].Value.Item then
        addItemEsp(child)
    end

    if Flags["NotifyItemsDrop"].Value then
        Midnight:Notify(Flags["ItemChatMessage"].Text:gsub("{item}", itemName), 5)

        if Flags["ChatNotify"].Value then
            RBXGeneral:SendAsync(Flags["ItemChatMessage"].Text:gsub("{item}", itemName))
        end
    end
end))

Midnight:AddConnection(workspace.ChildAdded:Connect(function(child)
    task.delay(0.1, function()
        if child.Name == "Eyes" or child.Name == "Lookman" then
            eyes = child
        end

        if isFools then
            if Flags["AntiBanana"].Value and child.Name == "BananaPeel" then
                child.CanTouch = false
            end
            if Flags["AntiJeff"].Value and child.Parent and child.Parent.Name == "JeffTheKiller" then
                child.CanTouch = false
            end
        end
    
        if table.find(entitiesTable.Entities, child.Name) then
            task.spawn(function()
                repeat
                    task.wait()
                until distanceFromCharacter(child:GetPivot().Position) < 2000 or not child:IsDescendantOf(workspace)
    
                if child:IsDescendantOf(workspace) then 
                    local rawEntityName = entitiesTable.Names[child.Name] or child.Name
                    local entityName = getEntityName(child)
    
                    if Flags["ESPWhat"].Value.Entity then
                        addEntityEsp(child)
                    end  
    
                    if Flags["NotifyEntities"].Value[rawEntityName] then
                        Midnight:Notify(Flags["EntityChatMessage"].Text:gsub("{entity}", entityName), 5)
    
                        if Flags["ChatNotify"].Value then
                            RBXGeneral:SendAsync(Flags["EntityChatMessage"].Text:gsub("{entity}", entityName))
                        end
                    end
                end
            end)
        end
    end)
end))

Midnight:AddConnection(workspace.CurrentCamera.ChildAdded:Connect(function(child)
    if table.find(entitiesTable.Entities, child.Name) then
        local rawEntityName = entitiesTable.Names[child.Name] or child.Name
        local entityName = getEntityName(child)

        if Flags["NotifyEntities"].Value[rawEntityName] then
            Midnight:Notify(Flags["EntityChatMessage"].Text:gsub("{entity}", entityName), 5)
        end
    end
end))

for _, player in pairs(Players:GetPlayers()) do
    if player == localPlayer then continue end

    player.CharacterAdded:Connect(function()
        task.delay(0.1, function()
            if Flags["ESPWhat"].Value.Player then
                addPlayerEsp(player)
            end
        end)  
    end)
end
Midnight:AddConnection(Players.PlayerAdded:Connect(function(player: Player)
    player.CharacterAdded:Connect(function()
        task.delay(0.1, function()
            if Flags["ESPWhat"].Value.Player then
                addPlayerEsp(player)
            end
        end)        
    end)
end))

Midnight:AddConnection(localPlayer:GetAttributeChangedSignal("Alive"):Connect(function()
    alive = localPlayer:GetAttribute("Alive")
end))

Midnight:AddConnection(localPlayer:GetAttributeChangedSignal("Greed"):Connect(function()
    local greedLevel = localPlayer:GetAttribute("Greed")

    for _, gold in pairs(workspace.CurrentRooms:GetDescendants()) do
        if gold.Name == "GoldPile" and gold:FindFirstChild("LootPrompt") then
            if greedLevel and greedLevel >= 6 and Flags["AntiGreed"].Value then
                gold.LootPrompt.Enabled = false
            else
                gold.LootPrompt.Enabled = true
            end
        end 
    end
end))

Midnight:AddConnection(localPlayer.CharacterAdded:Connect(function(newCharacter)
    task.delay(1, setupCharacterConnection, newCharacter)
end))

Midnight:AddConnection(playerGui.ChildAdded:Connect(function(child)
    if child.Name == "MainUI" then
        task.wait()
        mainUI = child
        task.delay(1, function()
            if mainUI then
                rawMainGame = mainUI:WaitForChild("Initiator", 1):WaitForChild("Main_Game", 1)
                mainGame = require(rawMainGame)
            end
        end)
    end
end))

Midnight:AddConnection(Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
    if Flags["Fullbright"].Value then
        Lighting.Ambient = Color3.new(1, 1, 1)
    end
end))

Midnight:AddConnection(mouse.Button1Down:Connect(function()
    if not holdingObj and mouse.Target and (Flags["GrabBanana"].Value and mouse.Target.Name == "BananaPeel" or Flags["GrabJeff"].Value and mouse.Target:FindFirstAncestorWhichIsA("Model").Name == "JeffTheKiller") and isnetworkowner(mouse.Target) then
        holdingObj = mouse.Target
        holdingObj.CanTouch = false

        if holdingObj:FindFirstAncestorWhichIsA("Model").Name == "JeffTheKiller" then
            holdingJeff = holdingObj:FindFirstAncestorWhichIsA("Model")

            for _, part in pairs(holdingJeff:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanTouch = false
                end
            end
        end
        
        holdingObjTrack:Play()
    elseif holdingObj and not throwingObj then
        throwingObj = true

        holdingObjTrack:Stop()
        throwObjTrack:Play()

        task.wait(0.5)

        local startPos = (rootPart.CFrame * CFrame.new(0, 0, 1)).Position
        local direction = (mouse.Hit.Position - startPos).Unit
        local upwardVelocity = holdingJeff and Vector3.zero or Vector3.new(0, 0.25, 0)
        local velocity = (direction + upwardVelocity).Unit * ((holdingJeff and Flags["JeffThrowPower"].Value or Flags["BananaThrowPower"].Value) * 10)

        local savedJeff = holdingJeff
        local savedObj = holdingObj

        holdingObj.Velocity = velocity
        holdingObj = nil
        holdingJeff = nil

        throwingObj = false

        task.delay(task.wait(), function()
            if savedJeff then
                for _, part in pairs(savedJeff:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanTouch = not Flags["AntiJeff"].Value
                    end
                end
            else
                savedObj.CanTouch = not Flags["AntiBanana"].Value
            end
        end)
    end
end))

Midnight:AddConnection(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent)
    if alive then
        if Flags["FixExitDelay"].Value and character:GetAttribute("Hiding") and table.find(exitKeycodes, input.KeyCode) and not gameProcessedEvent then
            remotesFolder.CamLock:FireServer()
            character:SetAttribute("Hiding", false)
        end
    end
end))

Midnight:AddConnection(RunService.RenderStepped:Connect(function(deltaTime)
    if mainGame then
        if Flags["NoCamBob"] then
            mainGame.bobspring.Position = Vector3.new()
            mainGame.spring.Position = Vector3.new()
        end
        
        if Flags["NoCamShake"].Value then
            mainGame.csgo = CFrame.new()
        end

        mainGame.fovtarget = Flags["FOV"].Value
    end

    if character then
        if holdingObj and isnetworkowner(holdingObj) then
            holdingObj.CFrame = character.RightHand.RightGripAttachment.WorldCFrame * (holdingJeff and CFrame.new(0, 0, -1.5) or CFrame.new())
        else
            if holdingObjTrack.IsPlaying then
                holdingObjTrack:Stop()
            end
        end

        if humanoid then
            if Flags["Speed"].Value then
                if Flags["SpeedMethod"].Value == "Boost" then
                    humanoid:SetAttribute("SpeedBoostBehind", Flags["SpeedBoost"].Value)
                else
                    humanoid.WalkSpeed = 15 + Flags["SpeedBoost"].Value
                end
            end
        end

        if rootPart then
            rootPart.CanCollide = not Flags["Noclip"].Value
        end

        if collision then
            collision.CanCollide = not Flags["Noclip"].Value
            if collision:FindFirstChild("CollisionCrouch") then
                collision.CollisionCrouch.CanCollide = not Flags["Noclip"].Value
            end
        end

        if character:FindFirstChild("UpperTorso") then
            character.UpperTorso.CanCollide = not Flags["Noclip"].Value
        end
        if character:FindFirstChild("LowerTorso") then
            character.LowerTorso.CanCollide = not Flags["Noclip"].Value
        end

        if Flags["DoorReach"].Value and workspace.CurrentRooms:FindFirstChild(latestRoom.Value) then
            local door = workspace.CurrentRooms[latestRoom.Value]:FindFirstChild("Door")

            if door and door:FindFirstChild("ClientOpen") then
                door.ClientOpen:FireServer()
            end
        end
    end
end))
-- #endregion --

message.update_message("[clutch.lua]: Successfully loaded!", "rbxasset://textures/AudioDiscovery/done.png", Color3.fromRGB(51, 255, 85))
Midnight:LoadAutoloadConfig()
