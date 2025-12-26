local love = require "love"
local LayoutZones = require "src.layout_zones"

local UIPiles = {}

function UIPiles.resetPiles(state)
    state.zoneCards = state.zoneCards or {}
    state.zoneCards.playerDeck = state.zoneCards.playerDeck or {}
    state.zoneCards.playerHand = state.zoneCards.playerHand or {}
    state.zoneCards.playerDiscard = state.zoneCards.playerDiscard or {}

    state.playerDeck = state.zoneCards.playerDeck
    state.playerHand = state.zoneCards.playerHand
    state.playerDiscard = state.zoneCards.playerDiscard

    state.handScrollX = 0
end

function UIPiles.drawOne(state)
    if #state.playerDeck == 0 then return end
    local card = table.remove(state.playerDeck)
    LayoutZones.moveCard(state, card, "playerHand")
    card.faceUp = true
end

function UIPiles.discardSelected(state)
    local selected = state.selectedCard
    if not selected then return end

    if selected.zoneId == "playerHand" then
        local idx = nil
        for i, c in ipairs(state.playerHand) do
            if c == selected then
                idx = i
                break
            end
        end

        LayoutZones.moveCard(state, selected, "playerDiscard")

        if #state.playerHand > 0 and idx then
            local nextIndex = math.min(idx, #state.playerHand)
            state.selectedCard = state.playerHand[nextIndex]
        elseif #state.playerHand == 0 then
            state.selectedCard = nil
        end

        return
    end

    local originZone = selected.zoneId
    local originList = originZone and state.zoneCards[originZone]
    local originIndex = nil
    if originList then
        for i, c in ipairs(originList) do
            if c == selected then
                originIndex = i
                break
            end
        end
    end

    LayoutZones.moveCard(state, selected, "playerDiscard")

    originList = originZone and state.zoneCards[originZone]
    if originList and #originList > 0 then
        local nextIndex = originIndex and math.min(originIndex, #originList) or 1
        state.selectedCard = originList[nextIndex]
    else
        state.selectedCard = nil
    end
end

local function getPileRects(state)
    local deckZone = state.zones.playerDeck
    local discardZone = state.zones.playerDiscard

    if not deckZone or not discardZone then
        local empty = { x=0, y=0, w=0, h=0 }
        return empty, empty, empty, empty
    end

    local deckRect = deckZone
    local discardRect = discardZone

    local drawBtn = { x=deckRect.x, y=discardRect.y + discardRect.h + 24, w=deckRect.w, h=56 }
    local discardBtn = { x=deckRect.x, y=drawBtn.y + 70, w=deckRect.w, h=56 }

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
