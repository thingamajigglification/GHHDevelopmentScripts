-- ═══════════════════════════════════════════════════════════════
--  DIALOGUE BUILDER — DO NOT EDIT
--  Location: ReplicatedStorage (ModuleScript named "DialogueBuilder")
-- ═══════════════════════════════════════════════════════════════

local Builder = {}

Builder.ATTACH_GOODBYE = { kind = "flag" }

local function makeNode(speaker, text, picture)
    return function(children)
        children = children or {}
        local kids = {}
        local hasGoodbye = false
        for _, c in ipairs(children) do
            if c == Builder.ATTACH_GOODBYE then
                hasGoodbye = true
            else
                table.insert(kids, c)
            end
        end
        return {
            kind       = "node",
            speaker    = speaker,
            text       = text,
            picture    = picture,
            children   = kids,
            goodbye    = hasGoodbye,
            shortLabel = nil,
            hook       = nil,   -- set post-creation: node.hook = "MyHookName"
        }
    end
end

Builder.NODE = makeNode

function Builder.SAY(speaker, text, picture)
    return {
        kind     = "say",
        speaker  = speaker,
        text     = text,
        picture  = picture,
        children = {},
        goodbye  = false,
        hook     = nil,
    }
end

function Builder.LEAF(speaker, text, picture)
    return {
        kind     = "node",
        speaker  = speaker,
        text     = text,
        picture  = picture,
        children = {},
        goodbye  = false,
        hook     = nil,
    }
end

return Builder
