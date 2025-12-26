local love = require "love"

local LayoutZones = require "src.layout_zones"
local CardModel = require "src.model_card"

local ActionStrip = {}

local function addButton(buttons, id, label, enabled)
    table.insert(buttons, { id=id, label=label, enabled=enabled ~= false })
end

local function hasFlip(card)
    if not card then return false end
    local side = CardModel.getActiveSide(card)
    if side and side.canFlipTo and #side.canFlipTo > 0 then return true end
    local count = 0
    for _ in pairs(card.def.sides or {}) do count = count + 1 end
    return count > 1
end

function ActionStrip.buildButtons(state)
    local buttons = {}
    local card = state.selectedCard
    if not card then return buttons end

    addButton(buttons, "zoom", "Zoom", true)
    addButton(buttons, "flip", "Flip / Advance", hasFlip(card))
    addButton(buttons, "exhaust", card.exhausted and "Ready" or "Exhaust", true)
    addButton(buttons, "dmg_plus", "+Damage", true)
    addButton(buttons, "dmg_minus", "-Damage", true)
    addButton(buttons, "thr_plus", "+Threat", true)
    addButton(buttons, "thr_minus", "-Threat", true)
    addButton(buttons, "stunned", card.tokens.stunned and "Clear Stun" or "Stun", true)
    addButton(buttons, "confused", card.tokens.confused and "Clear Confuse" or "Confuse", true)
    addButton(buttons, "tough", card.tokens.tough and "Clear Tough" or "Tough", true)

    local hasHand = state.zones.playerHand ~= nil
    local hasDiscard = state.zones.playerDiscard ~= nil
    local hasPlay = state.zones.playerPlay ~= nil
    local hasEncounter = state.zones.encounterBoard ~= nil

    addButton(buttons, "move_hand", "To Hand", hasHand and card.zoneId ~= "playerHand")
    addButton(buttons, "move_discard", "To Discard", hasDiscard and card.zoneId ~= "playerDiscard")
    addButton(buttons, "move_play", "To Play", hasPlay and card.zoneId ~= "playerPlay")
    addButton(buttons, "move_encounter", "To Encounter", hasEncounter and card.zoneId ~= "encounterBoard")

    return buttons
end

function ActionStrip.handleClick(state, id)
    local card = state.selectedCard
    if not card then return end

    if id == "zoom" then
        state.zoomCard = card
        return
    elseif id == "flip" then
        CardModel.flip(card)
    elseif id == "exhaust" then
        CardModel.toggleExhaust(card)
    elseif id == "dmg_plus" then
        CardModel.adjustToken(card, "damage", 1)
    elseif id == "dmg_minus" then
        CardModel.adjustToken(card, "damage", -1)
    elseif id == "thr_plus" then
        CardModel.adjustToken(card, "threat", 1)
    elseif id == "thr_minus" then
        CardModel.adjustToken(card, "threat", -1)
    elseif id == "stunned" then
        CardModel.toggleStatus(card, "stunned")
    elseif id == "confused" then
        CardModel.toggleStatus(card, "confused")
    elseif id == "tough" then
        CardModel.toggleStatus(card, "tough")
    elseif id == "move_hand" then
        LayoutZones.moveCard(state, card, "playerHand")
    elseif id == "move_discard" then
        LayoutZones.moveCard(state, card, "playerDiscard")
    elseif id == "move_play" then
        LayoutZones.moveCard(state, card, "playerPlay")
    elseif id == "move_encounter" then
        LayoutZones.moveCard(state, card, "encounterBoard")
    end
end

function ActionStrip.draw(state)
    local buttons = ActionStrip.buildButtons(state)
    state.actionButtons = {}
    if #buttons == 0 then return end

    local stripX = 60
    local stripY = 1180
    local stripW = state.VIRTUAL_WIDTH - 120
    local stripH = 90

    love.graphics.setColor(0.12, 0.12, 0.18, 0.9)
    love.graphics.rectangle("fill", stripX, stripY, stripW, stripH, 16, 16)
    love.graphics.setColor(0.5, 0.5, 0.7)
    love.graphics.rectangle("line", stripX, stripY, stripW, stripH, 16, 16)

    local gap = 10
    local btnW = math.min(170, math.floor((stripW - gap * (#buttons + 1)) / #buttons))
    local btnH = stripH - 20
    local x = stripX + gap
    local y = stripY + 10

    for _, btn in ipairs(buttons) do
        local rect = { x=x, y=y, w=btnW, h=btnH, id=btn.id, enabled=btn.enabled ~= false }
        table.insert(state.actionButtons, rect)

        local enabled = btn.enabled
        love.graphics.setColor(enabled and 0.2 or 0.12, enabled and 0.25 or 0.12, enabled and 0.34 or 0.18)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 10, 10)
        love.graphics.setColor(enabled and 0.9 or 0.6, enabled and 0.9 or 0.6, enabled and 0.95 or 0.65)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 10, 10)
        love.graphics.setColor(1, 1, 1, enabled and 1 or 0.6)
        love.graphics.setFont(state.fonts.small)
        love.graphics.printf(btn.label, rect.x + 6, rect.y + 16, rect.w - 12, "center")

        x = x + btnW + gap
    end
end

return ActionStrip
