local love = require "love"

local Util = require "src.util"
local LayoutZones = require "src.layout_zones"
local PhaseUI = require "src.ui_phasebar"
local UIPiles = require "src.ui_piles"
local CardModel = require "src.model_card"
local ActionStrip = require "src.ui_actionstrip"

local Input = {}

local function cardAtPosition(state, x, y)
    if not state.zoneOrder then return nil, nil end

    for i = #state.playerHand, 1, -1 do
        local c = state.playerHand[i]
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return c, "hand"
        end
    end

    for i = #state.zoneOrder, 1, -1 do
        local zone = state.zoneOrder[i]
        if zone.id ~= "playerHand" and zone.layout ~= "pile" then
            local list = state.zoneCards[zone.id] or {}
            for j = #list, 1, -1 do
                local c = list[j]
                if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
                    return c, zone.id
                end
            end
        end
    end

    return nil, nil
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

    if key == "z" then
        state.zoomCard = state.zoomCard and nil or state.selectedCard
    end

    if key == "[" then CardModel.adjustToken(state.selectedCard, "damage", -1) end
    if key == "]" then CardModel.adjustToken(state.selectedCard, "damage", 1) end
    if key == ";" then CardModel.adjustToken(state.selectedCard, "threat", -1) end
    if key == "'" then CardModel.adjustToken(state.selectedCard, "threat", 1) end
    if key == "s" then CardModel.toggleStatus(state.selectedCard, "stunned") end
    if key == "c" then CardModel.toggleStatus(state.selectedCard, "confused") end
    if key == "t" then CardModel.toggleStatus(state.selectedCard, "tough") end
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

    if state.actionButtons then
        for _, btn in ipairs(state.actionButtons) do
            if btn.enabled and Util.pointInRect(vx, vy, btn) then
                ActionStrip.handleClick(state, btn.id)
                return
            end
        end
    end

    if state.zoomCard and button == 1 then
        state.zoomCard = nil
        return
    end

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
            local now = love.timer.getTime()
            local isDouble = state.lastClickCard == card and state.lastClickTime and (now - state.lastClickTime) < 0.3
            state.lastClickTime = now
            state.lastClickCard = card
            if isDouble then
                state.zoomCard = card
            end
            state.selectedCard = card
            card.dragging = true
            card.dragOffsetX = vx - card.x
            card.dragOffsetY = vy - card.y
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

        local card = state.selectedCard
        local cx = card.x + card.w / 2
        local cy = card.y + card.h / 2
        local zoneId = LayoutZones.zoneAtPoint(state, cx, cy)
        if zoneId then
            LayoutZones.moveCard(state, card, zoneId)
        else
            LayoutZones.layoutZone(state, card.zoneId)
        end
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
