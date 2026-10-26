-- ═══════════════════════════════════════════════════════════════
--  DIALOGUE CLIENT — DO NOT EDIT
--  Location: StarterPlayer/StarterPlayerScripts (LocalScript)
-- ═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local ContentProvider   = game:GetService("ContentProvider")

local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")
local Data             = require(ReplicatedStorage:WaitForChild("DialogueData"))
local DialogueEvent    = ReplicatedStorage:WaitForChild("DialogueEvent")
local DialogueRequest  = ReplicatedStorage:WaitForChild("DialogueRequest")
local Settings         = Data.Settings
local Assets           = Data.Assets

-- ─── SOUNDS ───
local SoundsFolder = ReplicatedStorage:WaitForChild("DialogueSounds")

-- ═══════════════════════════════════════════════════════════════
--  GUI CONSTRUCTION
-- ═══════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DialogueGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = false
ScreenGui.DisplayOrder = 50
ScreenGui.Parent = PlayerGui

local ClickCatcher = Instance.new("TextButton")
ClickCatcher.Size = UDim2.new(1, 0, 1, 0)
ClickCatcher.BackgroundTransparency = 1
ClickCatcher.Text = ""
ClickCatcher.AutoButtonColor = false
ClickCatcher.ZIndex = 1
ClickCatcher.Parent = ScreenGui

local Background = Instance.new("ImageLabel")
Background.Name = "Background"
Background.Size = UDim2.new(0, 900, 0, 320)
Background.AnchorPoint = Vector2.new(0.5, 1)
Background.Position = UDim2.new(0.5, 0, 1, 320)
Background.BackgroundTransparency = 1
Background.ScaleType = Enum.ScaleType.Slice
Background.SliceCenter = Rect.new(32, 32, 32, 32)
Background.Image = Assets.Background
Background.ZIndex = 2
Background.Parent = ScreenGui

local GRADIENT_START = (Assets.Gradient and Assets.Gradient.Start) or Color3.fromRGB(255, 215, 90)
local GRADIENT_END   = (Assets.Gradient and Assets.Gradient.End)   or Color3.fromRGB(255, 130, 40)

local function ApplyGradient(instance)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, GRADIENT_START),
        ColorSequenceKeypoint.new(1.00, GRADIENT_END),
    }
    g.Rotation = (Assets.Gradient and Assets.Gradient.Angle) or 0
    g.Parent = instance
    return g
end

local function MakeLabel(parent, name, text, pos, size, isBold)
    local lbl = Instance.new("TextLabel")
    lbl.Name = name; lbl.Text = text; lbl.Position = pos; lbl.Size = size
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = isBold and Enum.Font.GothamBold or Enum.Font.GothamMedium
    lbl.ZIndex = 3
    lbl.Parent = parent
    return lbl
end

local SpeakerLabel = MakeLabel(Background, "SpeakerName", "Speaker",
    UDim2.new(0.03, 0, 0.06, 0), UDim2.new(0.4, 0, 0.10, 0), true)
SpeakerLabel.TextSize = 26

local NameBar = Instance.new("Frame")
NameBar.Position = UDim2.new(0.03, 0, 0.16, 0)
NameBar.Size = UDim2.new(0.28, 0, 0, 3)
NameBar.BorderSizePixel = 0
NameBar.ZIndex = 3
NameBar.Parent = Background
ApplyGradient(NameBar)

local TextLabel = MakeLabel(Background, "MainText", "",
    UDim2.new(0.03, 0, 0.25, 0), UDim2.new(0.62, 0, 0.65, 0), false)
TextLabel.TextSize = 22
TextLabel.TextYAlignment = Enum.TextYAlignment.Top

local PictureBox = Instance.new("ImageLabel")
PictureBox.Position = UDim2.new(0.72, 0, 0.20, 0)
PictureBox.Size = UDim2.new(0.23, 0, 0.55, 0)
PictureBox.BackgroundTransparency = 1
PictureBox.ScaleType = Enum.ScaleType.Fit
PictureBox.ZIndex = 3
PictureBox.Parent = Background

local OptionsFrame = Instance.new("Frame")
OptionsFrame.Position = UDim2.new(1.05, 0, 0.05, 0)
OptionsFrame.Size = UDim2.new(0, 380, 0.55, 0)
OptionsFrame.BackgroundTransparency = 1
OptionsFrame.ZIndex = 3
OptionsFrame.Parent = Background

local OptionsLayout = Instance.new("UIListLayout")
OptionsLayout.Padding = UDim.new(0, 6)
OptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
OptionsLayout.Parent = OptionsFrame

local GoodbyeBtn = Instance.new("TextButton")
GoodbyeBtn.Name = "GoodbyeButton"
GoodbyeBtn.Text = "Goodbye"
GoodbyeBtn.Position = UDim2.new(0.72, 0, 0.80, 0)
GoodbyeBtn.Size = UDim2.new(0.23, 0, 0.14, 0)
GoodbyeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GoodbyeBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
GoodbyeBtn.TextScaled = true
GoodbyeBtn.Font = Enum.Font.GothamBold
GoodbyeBtn.BorderSizePixel = 0
GoodbyeBtn.Visible = false
GoodbyeBtn.ZIndex = 4
GoodbyeBtn.Parent = Background
local gc = Instance.new("UICorner"); gc.CornerRadius = UDim.new(0, 8); gc.Parent = GoodbyeBtn
ApplyGradient(GoodbyeBtn)

-- Preload portraits
task.spawn(function()
    local list = {}
    for _, id in pairs(Assets.Portraits or {}) do
        if id and id ~= "" then table.insert(list, id) end
    end
    if #list > 0 then pcall(function() ContentProvider:PreloadAsync(list) end) end
end)

-- ═══════════════════════════════════════════════════════════════
--  SOUNDS
-- ═══════════════════════════════════════════════════════════════
local function GetSound(npcId, key)
    if npcId then
        local nf = SoundsFolder:FindFirstChild("NPC")
            and SoundsFolder.NPC:FindFirstChild(npcId)
        if nf then
            local s = nf:FindFirstChild(key .. "Sound")
            if s then return s end
        end
    end
    return SoundsFolder:FindFirstChild(key .. "Sound")
end

local function PlayVar(soundVar)
    if not soundVar or soundVar.SoundId == "" then return end
    local clone = soundVar:Clone()
    clone.Parent = ScreenGui
    clone:Play()
    clone.Ended:Connect(function() clone:Destroy() end)
end

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════
local Stack       = {}
local ActiveNPCId = nil
local IsTyping    = false
local TypeThread  = nil
local CurrentTextRaw = ""
local ReadyToAdvance = false
local FinalNode      = false
local CurrentSpeakerName   = LocalPlayer.Name
local CurrentSpeakerUserId = LocalPlayer.UserId
local DistancePending = false   -- awaiting server distance check

-- ─── SLIDE ───
local SHOWN_POS = UDim2.new(0.5, 0, 1, -20)
local HIDDEN_POS = UDim2.new(0.5, 0, 1, 320)

local function SlideUp()
    Background.Position = HIDDEN_POS
    TweenService:Create(Background, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = SHOWN_POS }):Play()
end

local function SlideDown()
    local t = TweenService:Create(Background, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = HIDDEN_POS })
    t:Play()
    t.Completed:Connect(function() ScreenGui.Enabled = false end)
end

-- ─── NAME ───
local function ApplyPlayerName(text)
    return (text:gsub("%[PLAYERNAME%]", CurrentSpeakerName))
end

-- ─── TYPEWRITER ───
local function TypeText(text)
    if TypeThread then task.cancel(TypeThread) end
    IsTyping = true; CurrentTextRaw = text; TextLabel.Text = ""; ReadyToAdvance = false
    local textSoundVar = GetSound(ActiveNPCId, "Text")
    TypeThread = task.spawn(function()
        for i = 1, #text do
            if not IsTyping then return end
            TextLabel.Text = string.sub(text, 1, i)
            if i % 2 == 0 then PlayVar(textSoundVar) end
            task.wait(Settings.TypeSpeed)
        end
        TextLabel.Text = text
        IsTyping = false
        ReadyToAdvance = true
    end)
end

local function SkipTyping()
    if not IsTyping then return false end
    IsTyping = false
    if TypeThread then task.cancel(TypeThread) end
    TextLabel.Text = CurrentTextRaw
    ReadyToAdvance = true
    return true
end

local function ShowPlayerPic()
    PictureBox.Image = Players:GetUserThumbnailAsync(
        CurrentSpeakerUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    PictureBox.ScaleType = Enum.ScaleType.Fit
end

-- ─── FORWARD ───
local RenderNode, GoDown, CloseDialogue

local function ClearOptions()
    for _, c in ipairs(OptionsFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
end

local function MakeButton(label, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 46)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 20
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextWrapped = true
    btn.ZIndex = 4
    btn.Parent = OptionsFrame
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = btn
    ApplyGradient(btn)

    btn.MouseButton1Click:Connect(function()
        if SkipTyping() then return end
        -- ⭐ Ask server to verify distance BEFORE advancing
        DistancePending = true
        DialogueRequest:FireServer("VerifyDistance")
        -- Store the pending action; DistanceOK will fire it
        pendingAdvance = onClick
    end)
end

-- ⭐ The pending advance is executed when server says DistanceOK
pendingAdvance = nil

function RenderNode(node)
    ReadyToAdvance = false
    FinalNode = false

    if node.speaker == "PLAYER" then
        SpeakerLabel.Text = CurrentSpeakerName
        ShowPlayerPic()
    else
        SpeakerLabel.Text = node.speaker
        if node.picture and node.picture ~= "" then
            PictureBox.Image = node.picture
            PictureBox.ScaleType = Enum.ScaleType.Fit
        end
    end

    TypeText(ApplyPlayerName(node.text))
    GoodbyeBtn.Visible = node.goodbye
    ClearOptions()

    -- ⭐ Run hook on SERVER via RemoteEvent, not locally.
    if node.hook and node.hook ~= "" then
        DialogueRequest:FireServer("RunHook", node.hook)
    end

    if #node.children == 0 then
        FinalNode = true
        if not node.goodbye then GoodbyeBtn.Visible = true end
        return
    end

    if node.kind == "say" or #node.children == 1 then
        local child = node.children[1]
        MakeButton("▸ Continue", function() GoDown(child) end)
        return
    end

    for _, child in ipairs(node.children) do
        local label = child.shortLabel or child.text
        MakeButton(label, function() GoDown(child) end)
    end
end

function GoDown(childNode)
    table.insert(Stack, childNode)
    RenderNode(childNode)
end

local function OpenDialogue(npcId, npcModel, speakerName, speakerUserId)
    local root = Data.NPCs[npcId]
    if not root or type(root) ~= "table" or not root.kind then return end

    CurrentSpeakerName   = speakerName or LocalPlayer.Name
    CurrentSpeakerUserId = speakerUserId or LocalPlayer.UserId
    ActiveNPCId = npcId
    Stack = { root }
    ScreenGui.Enabled = true
    PlayVar(GetSound(npcId, "SlideUp"))
    SlideUp()
    RenderNode(root)
end

function CloseDialogue()
    if TypeThread then task.cancel(TypeThread) end
    IsTyping = false; ReadyToAdvance = false
    PlayVar(GetSound(ActiveNPCId, "SlideDown"))
    SlideDown()
    ClearOptions()
    Stack = {}
    ActiveNPCId = nil
    pendingAdvance = nil
    DistancePending = false
    DialogueRequest:FireServer("Close")
end

-- ─── CLICK ANYWHERE ───
ClickCatcher.MouseButton1Click:Connect(function()
    if not ScreenGui.Enabled then return end
    if SkipTyping() then return end
    if FinalNode then CloseDialogue() return end
    if ReadyToAdvance then
        local node = Stack[#Stack]
        if node and #node.children == 1 then
            -- Ask server to verify distance
            DistancePending = true
            DialogueRequest:FireServer("VerifyDistance")
            pendingAdvance = function() GoDown(node.children[1]) end
        end
    end
end)

-- ─── SERVER RESPONSES ───
DialogueEvent.OnClientEvent:Connect(function(action, a1, a2, a3, a4)
    if action == "Open" then
        OpenDialogue(a1, a2, a3, a4)
    elseif action == "AutoClose" or action == "ForceClose" then
        CloseDialogue()
    end
end)

DialogueRequest.OnClientEvent:Connect(function(action)
    if action == "DistanceOK" then
        DistancePending = false
        if pendingAdvance then
            PlayVar(GetSound(ActiveNPCId, "Response"))
            local fn = pendingAdvance
            pendingAdvance = nil
            fn()
        end
    end
end)

GoodbyeBtn.MouseButton1Click:Connect(function()
    if SkipTyping() then return end
    PlayVar(GetSound(ActiveNPCId, "Response"))
    CloseDialogue()
end)

LocalPlayer.CharacterAdded:Connect(function()
    if ScreenGui.Enabled then CloseDialogue() end
end)
