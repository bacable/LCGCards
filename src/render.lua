local love = require "love"

local PhaseUI = require "src.ui_phasebar"
local UIPiles = require "src.ui_piles"

local Render = {}

local function drawZone(zone, fonts)
    love.graphics.setColor(0.16, 0.16, 0.20)
    love.graphics.rectangle("fill", zone.x, zone.y, zone.w, zone.h, 18, 18)
    love.graphics.setColor(0.55, 0.55, 0.65)
    love.graphics.rectangle("line", zone.x, zone.y, zone.w, zone.h, 18, 18)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print(zone.name, zone.x + 12, zone.y + 10)
end

local function formatTypeLine(side)
    local t = side.cardType or "?"
    local st = side.cardSubType
    local role = side.role
    local bits = { t }
    if st then table.insert(bits, st) end
    if role then table.insert(bits, "["..role.."]") end
    return table.concat(bits, "  •  ")
end

local function formatStatsLine(gameId, side)
    local s = side.stats or {}
    local out = {}

    local function add(label, key)
        if s[key] ~= nil then table.insert(out, label .. ":" .. tostring(s[key])) end
    end

    if gameId == "marvel" then
        add("THW", "thwart"); add("ATK","attack"); add("DEF","defense"); add("REC","recover")
        add("SCH","scheme"); add("HP","hitPoints")
        if side.handSize then table.insert(out, "HAND:"..side.handSize) end
    elseif gameId == "lotr" then
        add("WP","willpower"); add("ATK","attack"); add("DEF","defense"); add("HP","hitPoints")
        add("THR","threat"); add("QP","questPoints")
    elseif gameId == "arkham" then
        add("WIL","willpower"); add("INT","intellect"); add("COM","combat"); add("AGI","agility")
        add("HLTH","health"); add("SAN","sanity")
        add("SHR","shroud"); add("CLUE","cluesPerInvestigator")
    elseif gameId == "ashes" then
        if side.cardType == "enemy" and side.cardSubType == "boss" then
            add("HEALTH","health"); add("THREAT","threat"); add("ULT","ultimate")
        else
            add("LIFE","life"); add("BATTLE","battlefield"); add("SPELL","spellboard")
        end
    end

    if #out == 0 then
        for k,v in pairs(s) do table.insert(out, tostring(k)..":"..tostring(v)) end
    end

    return table.concat(out, "   ")
end

local function drawCard(gameId, fonts, card, isSelected, getActiveSide)
    local side = getActiveSide(card)

    local rot = card.exhausted and (math.pi / 2) or 0
    local cx = card.x + card.w / 2
    local cy = card.y + card.h / 2

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(rot)
    love.graphics.translate(-card.w / 2, -card.h / 2)

    if isSelected then love.graphics.setColor(0.26, 0.26, 0.36)
    else love.graphics.setColor(0.20, 0.20, 0.30) end
    love.graphics.rectangle("fill", 0, 0, card.w, card.h, 14, 14)

    love.graphics.setColor(0.85, 0.85, 0.92)
    love.graphics.rectangle("line", 0, 0, card.w, card.h, 14, 14)

    love.graphics.setColor(0.14, 0.14, 0.22)
    love.graphics.rectangle("fill", 0, 0, card.w, 54, 14, 14)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(side.name or "(No name)", 10, 10, card.w - 20, "left")

    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.92, 0.92, 0.98)
    love.graphics.printf(formatTypeLine(side), 10, 62, card.w - 20, "left")

    if side.traits and #side.traits > 0 then
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf("Traits: " .. table.concat(side.traits, ", "), 10, 88, card.w - 20, "left")
    end

    local statsText = formatStatsLine(gameId, side)
    if statsText and statsText ~= "" then
        love.graphics.setColor(0.13, 0.13, 0.20)
        love.graphics.rectangle("fill", 10, card.h - 54, card.w - 20, 44, 10, 10)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.printf(statsText, 18, card.h - 46, card.w - 36, "left")
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.92, 0.92, 0.98)
    love.graphics.printf(side.text or "", 10, 120, card.w - 20, "left")

    if card.exhausted then
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("EXHAUSTED", 10, card.h - 80)
    end

    if isSelected then
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", -3, -3, card.w + 6, card.h + 6, 16, 16)
    end

    love.graphics.pop()
end

local function drawHud(state)
    love.graphics.setFont(state.fonts.small)
    love.graphics.setColor(1, 1, 1)
    local hud =
        "Game: " .. state.currentGameId .. "   |   Phase: " .. PhaseUI.currentPhaseName(state) .. "\n" ..
        "Keys: [1] Marvel  [2] LOTR  [3] Arkham  [4] Ashes PvE   |   [N] Next Phase\n" ..
        "Mouse: Left-drag move  |  Right-click flip  |  Wheel: scroll hand\n" ..
        "Selected: [E] Exhaust/Ready   |   [D] Discard Selected"
    love.graphics.print(hud, 60, state.VIRTUAL_HEIGHT - 170)
end

function Render.draw(state, getActiveSide)
    love.graphics.push()
    love.graphics.translate(state.offsetX, state.offsetY)
    love.graphics.scale(state.scale)

    state.phaseButtons = PhaseUI.draw(state)

    for _, zone in pairs(state.zones) do
        drawZone(zone, state.fonts)
    end

    for _, card in ipairs(state.cards) do
        drawCard(state.currentGameId, state.fonts, card, card == state.selectedCard, getActiveSide)
    end

    local _, _, drawBtn, discardBtn = UIPiles.drawPilesAndButtons(state)
    state.drawBtnRect = drawBtn
    state.discardBtnRect = discardBtn

    local draggedHandCard = nil
    for _, card in ipairs(state.playerHand) do
        if card.dragging then
            draggedHandCard = card
        else
            drawCard(state.currentGameId, state.fonts, card, card == state.selectedCard, getActiveSide)
        end
    end
    if draggedHandCard then
        drawCard(state.currentGameId, state.fonts, draggedHandCard, draggedHandCard == state.selectedCard, getActiveSide)
    end

    drawHud(state)

    love.graphics.pop()
end

return Render
