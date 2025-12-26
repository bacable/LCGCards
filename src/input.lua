local love = require "love"

local Util = require "src.util"
local LayoutZones = require "src.layout_zones"
local PhaseUI = require "src.ui_phasebar"
local UIPiles = require "src.ui_piles"
local CardModel = require "src.model_card"

local Input = {}

local function cardAtPosition(state, x, y)
    for i = #state.playerHand, 1, -1 do
        local c = state.playerHand[i]
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return c, "hand"
        end
    end

    for i = #state.cards, 1, -1 do
        local c = state.cards[i]
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return c, "board"
        end
    end

    return nil, nil
end

local function bringToFront(state, card, where)
    if where == "hand" then
        return
    end

    for i, c in ipairs(state.cards) do
        if c == card then
            table.remove(state.cards, i)
            table.insert(state.cards, card)
            return
        end
    end
end

function Input.keypressed(state, key, deps)
    deps = deps or {}
    if key == "1" and deps.loadGame then deps.loadGame("marvel") end
    if key == "2" and deps.loadGame then deps.loadGame("lotr") end
    if key == "3" and deps.loadGame then deps.loadGame("arkham") end
    if key == "4" and deps.loadGame then deps.loadGame("ashes") end

    if key == "n" then PhaseUI.nextPhase(state) end
    if key == "e" then CardModel.toggleExhaust(state.selectedCard) end
    if key == "d" then UIPiles.discardSelected(state); LayoutZones.layoutHand(state) end
end

function Input.wheelmoved(state, dx, dy)
    if dy ~= 0 then
        state.handScrollX = state.handScrollX + dy * 60
        LayoutZones.layoutHand(state)
    end
end

function Input.mousepressed(state, x, y, button, deps)
    deps = deps or {}
    local vx, vy = Util.toVirtual(state, x, y)

    for _, btn in ipairs(state.phaseButtons or {}) do
        if Util.pointInRect(vx, vy, btn) then
            PhaseUI.setPhase(state, btn.phaseIndex)
            return
        end
    end

    if state.drawBtnRect and Util.pointInRect(vx, vy, state.drawBtnRect) then
        UIPiles.drawOne(state)
        LayoutZones.layoutHand(state)
        return
    end
    if state.discardBtnRect and Util.pointInRect(vx, vy, state.discardBtnRect) then
        UIPiles.discardSelected(state)
        LayoutZones.layoutHand(state)
        return
    end

    if button == 1 then
        local card, where = cardAtPosition(state, vx, vy)
        if card then
            state.selectedCard = card
            card.dragging = true
            card.dragOffsetX = vx - card.x
            card.dragOffsetY = vy - card.y
            bringToFront(state, card, where)
        else
            state.selectedCard = nil
        end
    elseif button == 2 then
        local card = select(1, cardAtPosition(state, vx, vy))
        if card then CardModel.flip(card) end
    elseif button == 3 then
        local card = select(1, cardAtPosition(state, vx, vy))
        if card then
            state.selectedCard = card
            CardModel.toggleExhaust(card)
        end
    end
end

function Input.mousereleased(state, x, y, button)
    if button == 1 and state.selectedCard then
        state.selectedCard.dragging = false
    end
end

function Input.mousemoved(state, x, y, dx, dy)
    local vx, vy = Util.toVirtual(state, x, y)
    if state.selectedCard and state.selectedCard.dragging then
        state.selectedCard.x = vx - state.selectedCard.dragOffsetX
        state.selectedCard.y = vy - state.selectedCard.dragOffsetY
    end
end

return Input
