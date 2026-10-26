-- ═══════════════════════════════════════════════════════════════
--  DIALOGUE DATA — THE ONLY FILE A NON-PROGRAMMER EDITS
--  Location: ReplicatedStorage (ModuleScript named "DialogueData")
-- ═══════════════════════════════════════════════════════════════

local Builder = require(script.Parent.DialogueBuilder)
local NODE, SAY, LEAF, ATTACH_GOODBYE =
    Builder.NODE, Builder.SAY, Builder.LEAF, Builder.ATTACH_GOODBYE

local DialogueData = {}

-- ╔═══════════════════════════════════════════════════════════╗
-- ║  ALL ASSET IDs                                              ║
-- ╚═══════════════════════════════════════════════════════════╝
DialogueData.Assets = {
    Background = "rbxassetid://106084690775810",
    Portraits  = {
        Receptionist = "rbxassetid://0000000000",
        Bellhop      = "rbxassetid://0000000000",
    },
    Sounds = {
        SlideUp   = "rbxassetid://3779053277",
        SlideDown = "rbxassetid://3779036535",
        Response  = "rbxassetid://102702078778790",
        Text      = "rbxassetid://6957635256",
    },
    SoundOverrides = {},
    Volumes = {
        SlideUp = 0.6, SlideDown = 0.6, Response = 0.5, Text = 0.30,
    },
}

-- ═══════════════════════════════════════════════════════════════
--  SETTINGS
-- ═══════════════════════════════════════════════════════════════
DialogueData.Settings = {
    TypeSpeed        = 0.02,
    WalkAwayDistance = 25,   -- ⭐ enforced server-side
}


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  SERVER-SIDE HOOKS                                         ║
--  These run ONLY on the server. They cannot touch the UI.   ║
--  Each hook receives (player) — do side effects here.       ║
-- ╚═══════════════════════════════════════════════════════════╝
DialogueData.Hooks = {

    GiveVIPBadge = function(player)
        local BadgeService = game:GetService("BadgeService")
        -- Replace with your badge ID
        pcall(function() BadgeService:AwardBadge(player.UserId, 0000000000) end)
        print("[Hook] Gave VIP badge to " .. player.Name)
    end,

    DeductRoomCost = function(player)
        local leaderstats = player:FindFirstChild("leaderstats")
        local coins = leaderstats and leaderstats:FindFirstChild("Coins")
        if coins and coins.Value >= 50 then
            coins.Value -= 50
            print("[Hook] Deducted 50 coins from " .. player.Name)
        else
            print("[Hook] " .. player.Name .. " could not afford room.")
        end
    end,

    GiveBagBadge = function(player)
        local BadgeService = game:GetService("BadgeService")
        pcall(function() BadgeService:AwardBadge(player.UserId, 0000000000) end)
        print("[Hook] Gave bag badge to " .. player.Name)
    end,
}


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  NPC DIALOGUES                                             ║
-- ╚═══════════════════════════════════════════════════════════╝
local P = DialogueData.Assets.Portraits

DialogueData.NPCs = {

    Receptionist = NODE("Receptionist", "Hello [PLAYERNAME], welcome to the Grand Palazzo Hotel!", P.Receptionist) {
        ATTACH_GOODBYE,

        NODE("PLAYER", "I'd like to book a room for the night.") {
            NODE("Receptionist", "Certainly. That will be 50 coins per night.", P.Receptionist) {
                (function()
                    local n = NODE("PLAYER", "Here you go — 50 coins.") {
                        -- ⭐ This node charges the player. Hook runs server-side.
                        SAY("Receptionist", "Room 204. Enjoy your stay!", P.Receptionist),
                    }
                    n.hook = "DeductRoomCost"
                    return n
                end)(),
                NODE("PLAYER", "Actually, never mind.") {
                    SAY("Receptionist", "No problem. Take your time.", P.Receptionist),
                },
            },
        },

        NODE("PLAYER", "Just looking around.") {
            SAY("Receptionist", "Feel free to explore the Grand Palazzo!", P.Receptionist),
        },
    },

    Bellhop = NODE("Bellhop", "Need help with your bags, [PLAYERNAME]?", P.Bellhop) {
        ATTACH_GOODBYE,

        (function()
            local n = NODE("PLAYER", "Yes, please take my bags to my room.") {
                SAY("Bellhop", "Right this way, [PLAYERNAME]!", P.Bellhop),
                SAY("Bellhop", "Here is your room.", P.Bellhop),
            }
            n.shortLabel = "Yes please"
            n.hook      = "GiveBagBadge"   -- ⭐ server-side badge award
            return n
        end)(),

        (function()
            local n = NODE("PLAYER", "No, I'll manage on my own.") {
                SAY("Bellhop", "Very well — enjoy your stay, [PLAYERNAME]!", P.Bellhop),
            }
            n.shortLabel = "No thanks"
            return n
        end)(),
    },

}

return DialogueData
