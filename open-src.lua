if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
local RS      = game:GetService("ReplicatedStorage")
local WS      = game:GetService("Workspace")
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- Modules
local Fsys       = require(RS:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")
local InteriorsM = Fsys("InteriorsM")

local RiverNet = require(
    RS.SharedModules.ContentPacks.Sugarfest2026.ChocolateRiver.ChocolateRiverNet)

local RiverSchedule = require(
    RS.SharedModules.ContentPacks.Sugarfest2026.ChocolateRiver.ChocolateRiverSchedule)

-- Config
local RIVER_INTERIOR   = "MainMap!Sugarfest2026"
local RIVER_ENTRY      = Vector3.new(-286.88,24,-1598.95)
local REDEEM_POS       = Vector3.new(-304.43,35,-1598.94)

local EGG_DELAY        = 0.5
local SWIM_WAIT        = 1.5
local QUEUE_FLUSH_WAIT = 2.5
local LOOP_INTERVAL    = 70
local TP_WAIT          = 5

local enabled   = true
local running   = false
local totalEggs = 0

local sg = Instance.new("ScreenGui")
sg.Name = "RiverFarmerGui"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = PG

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(275,210)
panel.Position = UDim2.fromOffset(20,80)
panel.BackgroundColor3 = Color3.fromRGB(10,14,24)
panel.BorderSizePixel = 0
panel.Parent = sg
Instance.new("UICorner",panel).CornerRadius = UDim.new(0,10)

local stroke = Instance.new("UIStroke",panel)
stroke.Color = Color3.fromRGB(80,200,255)
stroke.Thickness = 1.5

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,34)
titleBar.BackgroundColor3 = Color3.fromRGB(15,90,150)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner",titleBar).CornerRadius = UDim.new(0,10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-8,1,0)
title.Position = UDim2.fromOffset(8,0)
title.BackgroundTransparency = 1
title.Text = "🍫 Cocoa River Farmer"
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = Color3.new(1,1,1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local function label(text,y,color,bold)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-16,0,18)
    l.Position = UDim2.fromOffset(8,y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.fromRGB(200,200,200)
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = panel
    return l
end

local function divider(y)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-16,0,1)
    f.Position = UDim2.fromOffset(8,y)
    f.BackgroundColor3 = Color3.fromRGB(40,55,75)
    f.BorderSizePixel = 0
    f.Parent = panel
end

divider(37)

local statusLbl = label("Status: Waiting...",42,Color3.fromRGB(180,255,180))
local actionLbl = label("Action: —",60,Color3.fromRGB(130,210,255))
local eggLbl    = label("Eggs: —",78,Color3.fromRGB(255,220,100))
local pileLbl   = label("Pile: —",96,Color3.fromRGB(160,255,160))
local swimLbl   = label("Swim state: —",114,Color3.fromRGB(150,150,180))

divider(134)

local totalLbl = label("Total this run: 0",140)

local BTN_ON  = Color3.fromRGB(15,110,180)
local BTN_OFF = Color3.fromRGB(55,55,65)

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1,-16,0,32)
toggle.Position = UDim2.fromOffset(8,164)
toggle.BackgroundColor3 = BTN_ON
toggle.TextColor3 = Color3.new(1,1,1)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 12
toggle.Text = "🟢 Active — Click to Pause"
toggle.AutoButtonColor = false
toggle.Parent = panel
Instance.new("UICorner",toggle).CornerRadius = UDim.new(0,7)

toggle.MouseButton1Click:Connect(function()
    enabled = not enabled
    toggle.BackgroundColor3 = enabled and BTN_ON or BTN_OFF
    toggle.Text = enabled and "🟢 Active — Click to Pause" or "🔴 Paused — Click to Resume"

    if not enabled then
        statusLbl.Text = "Status: Paused"
        actionLbl.Text = "Action: —"
    end
end)

do
    local dragging, dragStart, startPos

    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = i.Position
            startPos = panel.Position
        end
    end)

    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            panel.Position = UDim2.fromOffset(
                startPos.X.Offset + d.X,
                startPos.Y.Offset + d.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

local function setStatus(t,c)
    statusLbl.Text = "Status: "..t
    statusLbl.TextColor3 = c or Color3.fromRGB(180,255,180)
    print("[River]",t)
end

local function setAction(t,c)
    actionLbl.Text = "Action: "..(t or "—")
    actionLbl.TextColor3 = c or Color3.fromRGB(130,210,255)
end

local function updatePile()
    local p = ClientData.get(RiverSchedule.MARSHMALLOWS_IN_HOUSE_KEY) or 0
    pileLbl.Text = "Pile: "..p.." eggs"
    return p
end

local function HRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function Hum()
    local c = LP.Character
    return c and c:FindFirstChild("Humanoid")
end

local function teleport(v)
    local hrp = HRP()
    if hrp then
        hrp.CFrame = CFrame.new(v)
        task.wait(.05)
    end
end

local function swimming()
    local h = Hum()
    return h and h:GetState() == Enum.HumanoidStateType.Swimming
end

local function eggs()
    local interior = WS.Interiors:FindFirstChild(RIVER_INTERIOR)
    if not interior then return {} end

    local t = {}
    for _,v in ipairs(interior:GetChildren()) do
        if v.Name:sub(1,8) == "CandyEgg" then
            local c = v:FindFirstChild("Collider")
            if c then table.insert(t,c) end
        end
    end
    return t
end

local function riverTick()
    if not enabled or running then return end
    running = true

    if (InteriorsM.get_current_location() or {}).destination_id ~= "MainMap" then
        setStatus("Teleporting to MainMap",Color3.fromRGB(255,220,100))
        setAction("Teleporting")
        pcall(function()
            InteriorsM.enter_smooth("MainMap","MainDoor",{})
        end)
        task.wait(TP_WAIT)
    end

    setAction("Scanning eggs")
    local e = eggs()
    eggLbl.Text = "Eggs: "..#e.." in river"
    setStatus("Found "..#e.." eggs")

    if #e == 0 then
        setStatus("No eggs available",Color3.fromRGB(255,180,80))
        running = false
        return
    end

    local hrp = HRP()
    local origin = hrp and hrp.CFrame or CFrame.new()

    teleport(RIVER_ENTRY)

    local t = 0
    while not swimming() and t < SWIM_WAIT do
        task.wait(.1)
        t += .1
    end

    local collected = 0
    for _,c in ipairs(e) do
        if not enabled then break end
        teleport(c.Position + Vector3.new(0,3,0))
        collected += 1

        if collected % 10 == 0 or collected == #e then
            setAction(("Collecting %d/%d"):format(collected,#e))
            eggLbl.Text = ("Eggs: %d/%d"):format(collected,#e)
        end

        task.wait(EGG_DELAY)
    end

    setAction("Syncing")
    task.wait(QUEUE_FLUSH_WAIT)

    if hrp then hrp.CFrame = origin end
    task.wait(.3)

    local pile = updatePile()
    setStatus("Collected — pile "..pile)

    if pile > 0 then
        setAction("Redeeming "..pile)
        teleport(REDEEM_POS)

        pcall(function()
            RiverNet.RedeemPending:fire_server()
        end)

        task.wait(1)

        local new = updatePile()
        totalEggs += pile
        totalLbl.Text = "Total this run: "..totalEggs

        setStatus(("Redeemed %d | Total %d"):format(pile,totalEggs),
            Color3.fromRGB(80,255,150))

        if hrp then hrp.CFrame = origin end
    end

    running = false
end

print("[River] Farmer started")
setStatus("Waiting for ClientData")

local t = 0
repeat task.wait(.5) t += .5 until ClientData.get or t >= 15

updatePile()
setStatus("Ready")

task.spawn(function()
    while true do
        if enabled then
            local ok,err = pcall(riverTick)
            if not ok then
                warn("[River]",err)
                running = false
            end
        end

        local waited = 0
        while waited < LOOP_INTERVAL do
            task.wait(2)
            waited += 2

            if enabled and not running then
                setAction("Next cycle in "..(LOOP_INTERVAL-waited).."s",
                    Color3.fromRGB(90,110,140))
                updatePile()
            end
        end
    end
end)

loadstring(game:HttpGet('https://raw.githubusercontent.com/OPAdoptScripts/UniversalAdoptMe/refs/heads/main/Scripts'))()
