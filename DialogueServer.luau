-- ═══════════════════════════════════════════════════════════════
--  DIALOGUE SERVER — DO NOT EDIT
--  Location: ServerScriptService (Script named "DialogueServer")
-- ═══════════════════════════════════════════════════════════════
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

-- ⭐ LOAD CONFIG FROM STUDIO
local Config = require(ReplicatedStorage:WaitForChild("DialogueConfig"))

local Assets   = Config
local Settings = Config
local Hooks    = Config.Hooks

-- ... (The rest of the server script remains exactly the same)
-- ─── 1. REMOTE EVENTS ───
local function EnsureRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if not r then
        r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = ReplicatedStorage
    end
    return r
end

local DialogueEvent    = EnsureRemote("DialogueEvent")     -- server → client: Open / AutoClose
local DialogueRequest  = EnsureRemote("DialogueRequest")   -- client → server: VerifyDistance / RunHook / Close

-- ─── 2. BUILD SOUNDS ───
local function BuildSound(name, soundId, volume)
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = soundId or ""
    s.Volume = volume or 0.5
    return s
end

local SoundsFolder = ReplicatedStorage:FindFirstChild("DialogueSounds")
if not SoundsFolder then
    SoundsFolder = Instance.new("Folder")
    SoundsFolder.Name = "DialogueSounds"
    SoundsFolder.Parent = ReplicatedStorage
end
for _, c in ipairs(SoundsFolder:GetChildren()) do c:Destroy() end

for key, soundId in pairs(Assets.Sounds) do
    BuildSound(key .. "Sound", soundId, Volumes[key]).Parent = SoundsFolder
end

local NPCSoundsFolder = Instance.new("Folder")
NPCSoundsFolder.Name = "NPC"
NPCSoundsFolder.Parent = SoundsFolder
for npcId, overrides in pairs(Assets.SoundOverrides or {}) do
    local f = Instance.new("Folder"); f.Name = npcId; f.Parent = NPCSoundsFolder
    for key, soundId in pairs(overrides) do
        BuildSound(key .. "Sound", soundId, Volumes[key]).Parent = f
    end
end

-- ─── 3. NPC RESOLVER ───
local function ResolveNPC(npcId)
    return workspace:FindFirstChild(npcId, true) or CollectionService:GetTagged(npcId)[1]
end

-- ─── 4. DISTANCE HELPER ───
-- Returns the distance from the player's HumanoidRootPart to the NPC, or
-- math.huge if it cannot be determined.
local function GetDistanceToNPC(player, npc)
    if not npc or not player.Character then return math.huge end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return math.huge end
    local npcPos
    if npc:IsA("Model") then
        npcPos = npc.PrimaryPart and npc.PrimaryPart.Position
    else
        npcPos = npc.Position
    end
    if not npcPos then return math.huge end
    return (hrp.Position - npcPos).Magnitude
end

-- ─── 5. TRACK ACTIVE DIALOGUES ───
-- [player] = { npcId = "...", npc = Instance, heartBeat = RBXScriptConnection }
local ActiveDialogues = {}

local function EndDialogueState(player)
    local state = ActiveDialogues[player]
    if not state then return end
    if state.heartbeat then state.heartbeat:Disconnect() end
    ActiveDialogues[player] = nil
end

-- ─── 6. PROMPTS ───
local function SetupNPC(npcId)
    local root = Data.NPCs[npcId]
    if type(root) ~= "table" or not root.kind then return end

    local npc = ResolveNPC(npcId)
    if not npc then
        warn("[DialogueServer] Missing NPC in Workspace: " .. npcId)
        return
    end
    if npc:FindFirstChild("TalkPrompt") then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "TalkPrompt"
    prompt.ActionText = "Talk"
    prompt.ObjectText = npcId
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.Parent = npc

    prompt.Triggered:Connect(function(player)
        -- ⭐ SERVER-SIDE DISTANCE CHECK
        local dist = GetDistanceToNPC(player, npc)
        if dist > Settings.WalkAwayDistance then
            warn(("[Dialogue] %s too far (%.1f studs) to start %s")
                :format(player.Name, dist, npcId))
            return
        end

        -- Already in a dialogue? Close the old one cleanly first.
        if ActiveDialogues[player] then
            EndDialogueState(player)
        end

        -- Open dialogue
        DialogueEvent:FireClient(player, "Open", npcId, npc, player.Name, player.UserId)

        -- ⭐ HEARTBEAT DISTANCE MONITOR
        local hb
        hb = RunService.Heartbeat:Connect(function()
            local state = ActiveDialogues[player]
            if not state then
                hb:Disconnect()
                return
            end
            if GetDistanceToNPC(player, state.npc) > Settings.WalkAwayDistance then
                DialogueEvent:FireClient(player, "AutoClose", "TooFar")
                EndDialogueState(player)
            end
        end)

        ActiveDialogues[player] = { npcId = npcId, npc = npc, heartbeat = hb }
    end)
end

for npcId, _ in pairs(Data.NPCs) do
    SetupNPC(npcId)
end

-- ─── 7. HANDLE CLIENT REQUESTS ───
-- Client fires: ("VerifyDistance", npcId) or ("RunHook", hookName) or ("Close",)
DialogueRequest.OnServerEvent:Connect(function(player, action, payload)
    local state = ActiveDialogues[player]

    if action == "Close" then
        EndDialogueState(player)
        return
    end

    if action == "VerifyDistance" then
        if not state then
            DialogueRequest:FireClient(player, "ForceClose", "NoActiveDialogue")
            return
        end
        local dist = GetDistanceToNPC(player, state.npc)
        if dist > Settings.WalkAwayDistance then
            DialogueEvent:FireClient(player, "AutoClose", "TooFar")
            EndDialogueState(player)
        else
            DialogueRequest:FireClient(player, "DistanceOK")
        end
        return
    end

    if action == "RunHook" then
        if not state then return end
        local hookName = payload
        local fn = Hooks[hookName]
        if type(fn) == "function" then
            local ok, err = pcall(fn, player)
            if not ok then
                warn(("[Dialogue] Hook '%s' failed for %s: %s")
                    :format(hookName, player.Name, tostring(err)))
            end
        else
            warn("[Dialogue] Unknown hook: " .. tostring(hookName))
        end
        return
    end
end)

-- ─── 8. CLEANUP ON LEAVE ───
Players.PlayerRemoving:Connect(function(player)
    EndDialogueState(player)
end)

print("[DialogueServer] Ready — server-verified distance + hooks.")
