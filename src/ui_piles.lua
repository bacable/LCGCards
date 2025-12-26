local love = require "love"

local UIPiles = {}

local function pushToDiscard(state, card)
    if not card then return end
    card.zoneId = "playerDiscard"
    table.insert(state.playerDiscard, card)
end

function UIPiles.resetPiles(state)
    state.playerDeck = {}
    state.playerHand = {}
    state.playerDiscard = {}
    state.handScrollX = 0
end

function UIPiles.drawOne(state)
    if #state.playerDeck == 0 then return end
    local card = table.remove(state.playerDeck)
    card.zoneId = "playerHand"
    card.faceUp = true
    table.insert(state.playerHand, card)
end

function UIPiles.discardSelected(state)
    local selected = state.selectedCard
    if not selected then return end

    for i = #state.playerHand, 1, -1 do
        if state.playerHand[i] == selected then
            local discarded = table.remove(state.playerHand, i)
            pushToDiscard(state, discarded)

            if #state.playerHand > 0 then
                local nextIndex = math.min(i, #state.playerHand)
                state.selectedCard = state.playerHand[nextIndex]
            else
                state.selectedCard = nil
            end

            return
        end
    end

    for i = #state.cards, 1, -1 do
        if state.cards[i] == selected then
            local discarded = table.remove(state.cards, i)
            pushToDiscard(state, discarded)

            if #state.cards > 0 then
                local nextIndex = math.min(i, #state.cards)
                state.selectedCard = state.cards[nextIndex]
            else
                state.selectedCard = nil
            end

            return
        end
    end
end

local function getPileRects(state)
    local z = state.zones.playerHand
    if not z then
        local empty = { x=0, y=0, w=0, h=0 }
        return empty, empty, empty, empty
    end

    local padding = 16
    local x = z.x + padding
    local y = z.y + padding + 40
    local pileW = 120
    local pileH = 160

    local deckRect = { x=x, y=y, w=pileW, h=pileH }
    local discardRect = { x=x, y=y + pileH + 24, w=pileW, h=pileH }

    local drawBtn = { x=x, y=discardRect.y + pileH + 24, w=pileW, h=56 }
    local discardBtn = { x=x, y=drawBtn.y + 70, w=pileW, h=56 }

    return deckRect, discardRect, drawBtn, discardBtn
end

local function drawButton(font, btn, label, enabled)
    enabled = (enabled ~= false)

    love.graphics.setColor(enabled and 0.18 or 0.12, enabled and 0.18 or 0.12, enabled and 0.26 or 0.16)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 12, 12)

    love.graphics.setColor(enabled and 0.7 or 0.45, enabled and 0.7 or 0.45, enabled and 0.85 or 0.55)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 12, 12)

    love.graphics.setFont(font)
    love.graphics.setColor(enabled and 1 or 0.7, enabled and 1 or 0.7, enabled and 1 or 0.7)
    love.graphics.printf(label, btn.x, btn.y + 10, btn.w, "center")
end

function UIPiles.drawPilesAndButtons(state)
    local deckRect, discardRect, drawBtn, discardBtn = getPileRects(state)

    love.graphics.setColor(0.18, 0.18, 0.24)
    love.graphics.rectangle("fill", deckRect.x, deckRect.y, deckRect.w, deckRect.h, 12, 12)
    love.graphics.setColor(0.7, 0.7, 0.85)
    love.graphics.rectangle("line", deckRect.x, deckRect.y, deckRect.w, deckRect.h, 12, 12)
    love.graphics.setFont(state.fonts.small)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Deck\n"..tostring(#state.playerDeck), deckRect.x, deckRect.y + 40, deckRect.w, "center")

    love.graphics.setColor(0.18, 0.18, 0.24)
    love.graphics.rectangle("fill", discardRect.x, discardRect.y, discardRect.w, discardRect.h, 12, 12)
    love.graphics.setColor(0.7, 0.7, 0.85)
    love.graphics.rectangle("line", discardRect.x, discardRect.y, discardRect.w, discardRect.h, 12, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Discard\n"..tostring(#state.playerDiscard), discardRect.x, discardRect.y + 40, discardRect.w, "center")

    drawButton(state.fonts.small, drawBtn, "Draw", #state.playerDeck > 0)
    drawButton(state.fonts.small, discardBtn, "Discard\nSelected", state.selectedCard ~= nil)
    return deckRect, discardRect, drawBtn, discardBtn
end

return UIPiles
