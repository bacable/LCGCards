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
        tokens       = { damage=0, threat=0, counters=0, stunned=false, confused=false, tough=false },
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

local function clampToken(card, key)
    if card.tokens[key] and card.tokens[key] < 0 then
        card.tokens[key] = 0
    end
end

function CardModel.adjustToken(card, key, delta)
    if not card or not key or not delta then return end
    CardModel.ensureTokens(card)
    local current = card.tokens[key] or 0
    if type(current) == "boolean" then
        card.tokens[key] = delta > 0
        return
    end
    card.tokens[key] = current + delta
    clampToken(card, key)
end

function CardModel.toggleStatus(card, key)
    if not card or not key then return end
    CardModel.ensureTokens(card)
    local current = card.tokens[key]
    if type(current) == "boolean" then
        card.tokens[key] = not current
    end
end

function CardModel.ensureTokens(card)
    card.tokens = card.tokens or {}
    card.tokens.damage = card.tokens.damage or 0
    card.tokens.threat = card.tokens.threat or 0
    card.tokens.counters = card.tokens.counters or 0
    card.tokens.stunned = card.tokens.stunned or false
    card.tokens.confused = card.tokens.confused or false
    card.tokens.tough = card.tokens.tough or false
end

return CardModel
