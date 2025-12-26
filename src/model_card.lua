local love = require "love"

local CardModel = {}

local function getSideKeys(def)
    local keys = {}
    for key, _ in pairs(def.sides or {}) do
        table.insert(keys, key)
    end
    return keys
end

function CardModel.newInstance(state, def, sideId)
    local card = {
        instanceId   = state.nextInstanceId,
        def          = def,
        activeSideId = sideId or def.defaultSideId or "front",

        zoneId       = nil,
        x            = 0,
        y            = 0,
        w            = 280,
        h            = 400,

        dragging     = false,
        dragOffsetX  = 0,
        dragOffsetY  = 0,

        exhausted    = false,
        tokens       = {},
        faceUp       = true,
    }

    state.nextInstanceId = state.nextInstanceId + 1
    return card
end

function CardModel.getActiveSide(card)
    return card.def.sides[card.activeSideId]
end

function CardModel.flip(card)
    local side = CardModel.getActiveSide(card)
    local canFlipTo = side and side.canFlipTo

    if canFlipTo and #canFlipTo > 0 then
        card.activeSideId = canFlipTo[1]
        return
    end

    local keys = getSideKeys(card.def)
    if #keys == 2 then
        card.activeSideId = (card.activeSideId == keys[1]) and keys[2] or keys[1]
    end
end

function CardModel.toggleExhaust(card)
    if not card then return end
    card.exhausted = not card.exhausted
end

return CardModel
