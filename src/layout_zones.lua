local love = require "love"

local LayoutZones = {}

local function buildDeckDiscardForHand(zone)
    local padding = 16
    local x = zone.x + padding
    local y = zone.y + padding + 40
    local pileW = 120
    local pileH = 160

    local deckRect = { x=x, y=y, w=pileW, h=pileH, id="playerDeck", name="Deck", layout="pile" }
    local discardRect = { x=x, y=y + pileH + 24, w=pileW, h=pileH, id="playerDiscard", name="Discard", layout="pile" }
    return deckRect, discardRect
end

function LayoutZones.createZonesForGame(gameId)
    local order, zones = {}, {}

    if gameId == "marvel" then
        local base = {
            { id="villain",         name="Villain",                 x=60,  y=80,  w=260, h=400, layout="anchor" },
            { id="mainScheme",      name="Main Scheme",             x=340, y=80,  w=260, h=400, layout="anchor" },
            { id="encounterDeck",   name="Encounter Deck",          x=620, y=80,  w=150, h=200, layout="pile" },
            { id="encounterDiscard",name="Encounter Discard",       x=620, y=300, w=150, h=200, layout="pile" },
            { id="encounterBoard",  name="Encounter Board",         x=60,  y=500, w=710, h=220, layout="row" },
            { id="playerIdentity",  name="Identity",                x=60,  y=750, w=260, h=420, layout="anchor", lock=true },
            { id="playerPlay",      name="Upgrades / Supports",     x=340, y=750, w=720, h=420, layout="row" },
            { id="playerHand",      name="Hand",                    x=60,  y=1320,w=960, h=540, layout="hand" },
        }

        for _, z in ipairs(base) do
            zones[z.id] = z
            table.insert(order, z)
        end

        local deckRect, discardRect = buildDeckDiscardForHand(zones.playerHand)
        zones[deckRect.id] = deckRect
        zones[discardRect.id] = discardRect
        table.insert(order, deckRect)
        table.insert(order, discardRect)
    elseif gameId == "lotr" then
        local topY, topH = 140, 520
        local base = {
            { id="activeLocation", name="Active Location", x=60, y=topY, w=300, h=topH, layout="anchor" },
            { id="stagingArea",    name="Staging / Quest", x=380, y=topY, w=640, h=topH, layout="row" },
            { id="playerBoard",    name="Heroes / Allies", x=60,  y=720, w=960, h=540, layout="row" },
            { id="playerHand",     name="Hand",            x=60,  y=1320,w=960, h=540, layout="hand" },
        }
        for _, z in ipairs(base) do
            zones[z.id] = z
            table.insert(order, z)
        end
        local deckRect, discardRect = buildDeckDiscardForHand(zones.playerHand)
        zones[deckRect.id] = deckRect
        zones[discardRect.id] = discardRect
        table.insert(order, deckRect)
        table.insert(order, discardRect)
    elseif gameId == "arkham" then
        local base = {
            { id="encounterBoard", name="Agenda / Act",      x=60, y=140,  w=960, h=420, layout="row" },
            { id="playerBoard",    name="Play Area",         x=60, y=600,  w=960, h=660, layout="row" },
            { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540, layout="hand" },
        }
        for _, z in ipairs(base) do
            zones[z.id] = z
            table.insert(order, z)
        end
        local deckRect, discardRect = buildDeckDiscardForHand(zones.playerHand)
        zones[deckRect.id] = deckRect
        zones[discardRect.id] = discardRect
        table.insert(order, deckRect)
        table.insert(order, discardRect)
    elseif gameId == "ashes" then
        local base = {
            { id="encounterBoard", name="Boss / Encounter",  x=60, y=140,  w=960, h=520, layout="row" },
            { id="playerBoard",    name="Spellboard / Units",x=60, y=720,  w=960, h=540, layout="row" },
            { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540, layout="hand" },
        }
        for _, z in ipairs(base) do
            zones[z.id] = z
            table.insert(order, z)
        end
        local deckRect, discardRect = buildDeckDiscardForHand(zones.playerHand)
        zones[deckRect.id] = deckRect
        zones[discardRect.id] = discardRect
        table.insert(order, deckRect)
        table.insert(order, discardRect)
    end

    return zones, order
end

function LayoutZones.initZoneCards(state)
    state.zoneCards = {}
    for id, _ in pairs(state.zones) do
        state.zoneCards[id] = {}
    end
end

local function layoutPile(zone, cards)
    if not zone or not cards then return end
    local offset = 2
    for i, card in ipairs(cards) do
        card.x = zone.x + offset * (i - 1)
        card.y = zone.y + offset * (i - 1)
    end
end

local function layoutAnchor(zone, cards)
    if not zone or not cards then return end
    local cx = zone.x + zone.w / 2
    local cy = zone.y + zone.h / 2
    for _, card in ipairs(cards) do
        card.x = cx - card.w / 2
        card.y = cy - card.h / 2
    end
end

local function layoutRow(zone, cards)
    if not zone or not cards or #cards == 0 then return end
    local padding = 18
    local startX  = zone.x + padding
    local y       = zone.y + (zone.h - cards[1].h) / 2

    local slotW = cards[1].w + padding
    for i, card in ipairs(cards) do
        card.x = startX + (i-1) * slotW
        card.y = y
    end
end

function LayoutZones.layoutHand(state)
    local zone = state.zones.playerHand
    local hand = state.playerHand
    if not zone or not hand then return end
    if #hand == 0 then return end

    local padding = 16
    local pileW = 130
    local left = zone.x + padding + pileW + padding
    local right = zone.x + zone.w - padding
    local usableW = right - left

    local cardW = hand[1].w
    local gap = 16
    local totalW = #hand * cardW + (#hand - 1) * gap

    local minScroll = math.min(0, usableW - totalW)
    if state.handScrollX < minScroll then state.handScrollX = minScroll end
    if state.handScrollX > 0 then state.handScrollX = 0 end

    local y = zone.y + (zone.h - hand[1].h) / 2
    for i, card in ipairs(hand) do
        card.zoneId = "playerHand"
        card.x = left + state.handScrollX + (i-1) * (cardW + gap)
        card.y = y
    end
end

function LayoutZones.layoutZone(state, zoneId)
    local zone = state.zones[zoneId]
    local cards = state.zoneCards[zoneId]
    if not zone or not cards then return end

    if zone.layout == "hand" then
        LayoutZones.layoutHand(state)
        return
    elseif zone.layout == "pile" then
        layoutPile(zone, cards)
    elseif zone.layout == "anchor" then
        layoutAnchor(zone, cards)
    else
        layoutRow(zone, cards)
    end
end

function LayoutZones.layoutAll(state)
    for id, _ in pairs(state.zoneCards) do
        LayoutZones.layoutZone(state, id)
    end
end

function LayoutZones.zoneAtPoint(state, x, y)
    if not state.zoneOrder then return nil end
    for i = #state.zoneOrder, 1, -1 do
        local z = state.zoneOrder[i]
        if x >= z.x and x <= z.x + z.w and y >= z.y and y <= z.y + z.h then
            return z.id
        end
    end
    return nil
end

local function removeFromZone(zoneCards, zoneId, card)
    local list = zoneCards[zoneId]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == card then
            table.remove(list, i)
            return
        end
    end
end

function LayoutZones.moveCard(state, card, toZoneId)
    if not card or not toZoneId then return end
    local currentZone = card.zoneId and state.zones[card.zoneId]
    if currentZone and currentZone.lock and toZoneId ~= card.zoneId then
        LayoutZones.layoutZone(state, card.zoneId)
        return
    end

    if not state.zones[toZoneId] then
        LayoutZones.layoutZone(state, card.zoneId)
        return
    end

    if card.zoneId == toZoneId then
        LayoutZones.layoutZone(state, toZoneId)
        return
    end

    local fromZone = card.zoneId
    removeFromZone(state.zoneCards, fromZone, card)

    if not state.zoneCards[toZoneId] then
        state.zoneCards[toZoneId] = {}
    end
    table.insert(state.zoneCards[toZoneId], card)
    card.zoneId = toZoneId

    if fromZone then LayoutZones.layoutZone(state, fromZone) end
    LayoutZones.layoutZone(state, toZoneId)
end

function LayoutZones.ensureZone(state, zoneId)
    if not state.zoneCards[zoneId] then
        state.zoneCards[zoneId] = {}
    end
    return state.zoneCards[zoneId]
end

return LayoutZones
