local love = require "love"

local LayoutZones = {}

function LayoutZones.createZonesForGame(gameId)
    if gameId == "marvel" then
        return {
            encounterBoard = { id="encounterBoard", name="Villain / Schemes", x=60, y=140,  w=960, h=520 },
            playerBoard    = { id="playerBoard",    name="Hero / Allies",     x=60, y=720,  w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    elseif gameId == "lotr" then
        local topY, topH = 140, 520
        return {
            activeLocation = { id="activeLocation", name="Active Location", x=60, y=topY, w=300, h=topH },
            stagingArea    = { id="stagingArea",    name="Staging / Quest", x=380, y=topY, w=640, h=topH },
            playerBoard    = { id="playerBoard",    name="Heroes / Allies", x=60,  y=720, w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",            x=60,  y=1320,w=960, h=540 },
        }
    elseif gameId == "arkham" then
        return {
            encounterBoard = { id="encounterBoard", name="Agenda / Act",      x=60, y=140,  w=960, h=420 },
            playerBoard    = { id="playerBoard",    name="Play Area",         x=60, y=600,  w=960, h=660 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    elseif gameId == "ashes" then
        return {
            encounterBoard = { id="encounterBoard", name="Boss / Encounter",  x=60, y=140,  w=960, h=520 },
            playerBoard    = { id="playerBoard",    name="Spellboard / Units",x=60, y=720,  w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    end

    return {}
end

function LayoutZones.placeCardsInZone(zones, zoneId, cardList)
    local zone = zones[zoneId]
    if not zone then return end
    if #cardList == 0 then return end

    local padding = 18
    local startX  = zone.x + padding
    local y       = zone.y + (zone.h - cardList[1].h) / 2

    local slotW = cardList[1].w + padding
    for i, card in ipairs(cardList) do
        card.zoneId = zoneId
        card.x = startX + (i-1) * slotW
        card.y = y
    end
end

function LayoutZones.layoutHand(state)
    local zone = state.zones.playerHand
    if not zone then return end
    if #state.playerHand == 0 then return end

    local padding = 16
    local pileW = 130
    local left = zone.x + padding + pileW + padding
    local right = zone.x + zone.w - padding
    local usableW = right - left

    local cardW = state.playerHand[1].w
    local gap = 16
    local totalW = #state.playerHand * cardW + (#state.playerHand - 1) * gap

    local minScroll = math.min(0, usableW - totalW)
    if state.handScrollX < minScroll then state.handScrollX = minScroll end
    if state.handScrollX > 0 then state.handScrollX = 0 end

    local y = zone.y + (zone.h - state.playerHand[1].h) / 2
    for i, card in ipairs(state.playerHand) do
        card.zoneId = "playerHand"
        card.x = left + state.handScrollX + (i-1) * (cardW + gap)
        card.y = y
    end
end

return LayoutZones
