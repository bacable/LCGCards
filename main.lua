-- main.lua
-- LCG Engine Scaffold Demo v4.1
-- Fixes:
-- - Hand selection bug: clicking a hand card no longer reorders hand (no “swap” / “always far right”)
-- - Dragged hand card is drawn last so it appears on top without reordering

local love = require "love"

----------------------------------------------------------
-- 1. Virtual resolution / scaling
----------------------------------------------------------

local VIRTUAL_WIDTH  = 1080
local VIRTUAL_HEIGHT = 1920

local windowWidth, windowHeight
local scale, offsetX, offsetY = 1, 0, 0

local function updateScreenScale()
    windowWidth, windowHeight = love.graphics.getDimensions()
    local scaleX = windowWidth  / VIRTUAL_WIDTH
    local scaleY = windowHeight / VIRTUAL_HEIGHT
    scale = math.min(scaleX, scaleY)
    offsetX = (windowWidth  - VIRTUAL_WIDTH  * scale) / 2
    offsetY = (windowHeight - VIRTUAL_HEIGHT * scale) / 2
end

local function toVirtual(x, y)
    return (x - offsetX) / scale, (y - offsetY) / scale
end

----------------------------------------------------------
-- 2. Card model: CardDef + CardInstance
----------------------------------------------------------

local nextInstanceId = 1

local function newCardInstance(def, sideId)
    local card = {
        instanceId   = nextInstanceId,
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
    nextInstanceId = nextInstanceId + 1
    return card
end

local function getActiveSide(card)
    return card.def.sides[card.activeSideId]
end

local function flipCard(card)
    local side = getActiveSide(card)
    local canFlipTo = side.canFlipTo

    if canFlipTo and #canFlipTo > 0 then
        card.activeSideId = canFlipTo[1]
        return
    end

    local sideKeys = {}
    for key,_ in pairs(card.def.sides) do
        table.insert(sideKeys, key)
    end
    if #sideKeys == 2 then
        card.activeSideId = (card.activeSideId == sideKeys[1]) and sideKeys[2] or sideKeys[1]
    end
end

local function toggleExhaust(card)
    if not card then return end
    card.exhausted = not card.exhausted
end

----------------------------------------------------------
-- 3. Zones & layout
----------------------------------------------------------

local zones = {}
local cards = {}
local selectedCard = nil

local function createZonesForGame(gameId)
    if gameId == "marvel" then
        zones = {
            encounterBoard = { id="encounterBoard", name="Villain / Schemes", x=60, y=140,  w=960, h=520 },
            playerBoard    = { id="playerBoard",    name="Hero / Allies",     x=60, y=720,  w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    elseif gameId == "lotr" then
        local topY, topH = 140, 520
        zones = {
            activeLocation = { id="activeLocation", name="Active Location", x=60, y=topY, w=300, h=topH },
            stagingArea    = { id="stagingArea",    name="Staging / Quest", x=380, y=topY, w=640, h=topH },
            playerBoard    = { id="playerBoard",    name="Heroes / Allies", x=60,  y=720, w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",            x=60,  y=1320,w=960, h=540 },
        }
    elseif gameId == "arkham" then
        zones = {
            encounterBoard = { id="encounterBoard", name="Agenda / Act",      x=60, y=140,  w=960, h=420 },
            playerBoard    = { id="playerBoard",    name="Play Area",         x=60, y=600,  w=960, h=660 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    elseif gameId == "ashes" then
        zones = {
            encounterBoard = { id="encounterBoard", name="Boss / Encounter",  x=60, y=140,  w=960, h=520 },
            playerBoard    = { id="playerBoard",    name="Spellboard / Units",x=60, y=720,  w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    end
end

----------------------------------------------------------
-- 4. UI + Buttons
----------------------------------------------------------

local fonts = {}
local function loadFonts()
    fonts.title = love.graphics.newFont(28)
    fonts.small = love.graphics.newFont(20)
    fonts.tiny  = love.graphics.newFont(18)
end

local function pointInRect(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function drawButton(btn, label, enabled)
    enabled = (enabled ~= false)

    love.graphics.setColor(enabled and 0.18 or 0.12, enabled and 0.18 or 0.12, enabled and 0.26 or 0.16)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 12, 12)

    love.graphics.setColor(enabled and 0.7 or 0.45, enabled and 0.7 or 0.45, enabled and 0.85 or 0.55)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 12, 12)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(enabled and 1 or 0.7, enabled and 1 or 0.7, enabled and 1 or 0.7)
    love.graphics.printf(label, btn.x, btn.y + 10, btn.w, "center")
end

----------------------------------------------------------
-- 5. Taxonomy display helpers
----------------------------------------------------------

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

----------------------------------------------------------
-- 6. Phase system
----------------------------------------------------------

local phaseLists = {
    marvel = { "Setup", "Player Phase", "Villain Phase", "Encounter", "End / Cleanup" },
    lotr   = { "Resource", "Planning", "Quest", "Travel", "Encounter", "Combat", "Refresh" },
    arkham = { "Mythos", "Investigation", "Enemy", "Upkeep" },
    ashes  = { "Setup", "Player Turn", "Encounter (Threat)", "Resolution", "End / Cleanup" },
}

local currentGameId = "marvel"
local phaseIndex = 1

local function currentPhaseName()
    local list = phaseLists[currentGameId] or { "Phase" }
    return list[phaseIndex] or list[1]
end

local function nextPhase()
    local list = phaseLists[currentGameId] or { "Phase" }
    phaseIndex = phaseIndex + 1
    if phaseIndex > #list then phaseIndex = 1 end
end

local function setPhase(i)
    local list = phaseLists[currentGameId] or { "Phase" }
    if i >= 1 and i <= #list then
        phaseIndex = i
    end
end

----------------------------------------------------------
-- 7. Deck/Hand/Discard basics
----------------------------------------------------------

local playerDeck = {}
local playerHand = {}
local playerDiscard = {}
local handScrollX = 0

local function resetPiles()
    playerDeck = {}
    playerHand = {}
    playerDiscard = {}
    handScrollX = 0
end

local function pushToDiscard(card)
    if not card then return end
    card.zoneId = "playerDiscard"
    table.insert(playerDiscard, card)
end

local function removeCardFromList(list, card)
    for i = #list, 1, -1 do
        if list[i] == card then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local function drawOne()
    if #playerDeck == 0 then return end
    local card = table.remove(playerDeck)
    card.zoneId = "playerHand"
    card.faceUp = true
    table.insert(playerHand, card)
end

local function discardSelected()
    if not selectedCard then return end

    -- If it's in hand, move to discard and auto-select next hand card
    for i = #playerHand, 1, -1 do
        if playerHand[i] == selectedCard then
            local discarded = table.remove(playerHand, i)
            pushToDiscard(discarded)

            if #playerHand > 0 then
                local nextIndex = math.min(i, #playerHand)
                selectedCard = playerHand[nextIndex]
            else
                selectedCard = nil
            end

            return
        end
    end

    -- If it's on board, allow discarding too (optional)
    for i = #cards, 1, -1 do
        if cards[i] == selectedCard then
            local discarded = table.remove(cards, i)
            pushToDiscard(discarded)

            if #cards > 0 then
                local nextIndex = math.min(i, #cards)
                selectedCard = cards[nextIndex]
            else
                selectedCard = nil
            end

            return
        end
    end
end


----------------------------------------------------------
-- 8. Sample CardDefs per game (plus small draw deck filler)
----------------------------------------------------------

local function makeGenericPlayerCard(gameId, n)
    local name = (gameId == "marvel_champions" and ("Demo Event "..n))
        or (gameId == "lotr_lcg" and ("Demo Event "..n))
        or (gameId == "arkham_lcg" and ("Demo Event "..n))
        or (gameId == "ashes_reborn" and ("Demo Action Spell "..n))
        or ("Demo Card "..n)

    local subType = (gameId == "arkham_lcg") and "event" or ((gameId == "ashes_reborn") and "spell_action" or nil)

    return {
        id=("DEMO_DRAW_"..gameId.."_"..n),
        game=gameId,
        sides = {
            front = {
                name=name,
                cardType="event",
                cardSubType=subType,
                role="player",
                stats={},
                text="Drawn from deck.\nPress D to discard selected.\nPress E to exhaust.",
            }
        },
        defaultSideId="front",
        printings={ { setId="DEMO", setName="Demo", cardNumbers={ 300 + n }, modularTags={"Demo"} } }
    }
end

local function sampleDefs_Marvel()
    local heroDef = {
        id="MC_DEMO_IDENTITY", game="marvel_champions",
        sides = {
            alter_ego = {
                name="Demo Alter-Ego",
                cardType="identity", cardSubType="alter_ego", role="player",
                handSize=6,
                stats={ recover=3, hitPoints=11 },
                traits={ "Civilian" },
                text="Alter-ego ability (paraphrased).\nRight-click to flip to Hero.\nPress E to exhaust/ready.",
                canFlipTo={ "hero" },
            },
            hero = {
                name="Demo Hero",
                cardType="identity", cardSubType="hero", role="player",
                handSize=5,
                stats={ thwart=2, attack=2, defense=2, hitPoints=11 },
                traits={ "Avenger" },
                text="Hero ability (paraphrased).\nRight-click to flip to Alter-Ego.\nPress E to exhaust/ready.",
                canFlipTo={ "alter_ego" },
            },
        },
        defaultSideId="alter_ego",
    }

    local villainDef = {
        id="MC_DEMO_VILLAIN", game="marvel_champions",
        sides = {
            stage1 = {
                name="Demo Villain I",
                cardType="scenario", cardSubType="villain", role="encounter",
                stats={ attack=2, scheme=1, hitPoints=14 },
                traits={ "Criminal" },
                text="Stage I.\nRight-click to advance to Stage II.",
                canFlipTo={ "stage2" },
            },
            stage2 = {
                name="Demo Villain II",
                cardType="scenario", cardSubType="villain", role="encounter",
                stats={ attack=3, scheme=2, hitPoints=16 },
                traits={ "Criminal" },
                text="Stage II.\nFinal stage for demo.",
                canFlipTo={},
            },
        },
        defaultSideId="stage1",
    }

    local sideSchemeDef = {
        id="MC_DEMO_SIDE_SCHEME", game="marvel_champions",
        sides = {
            front = {
                name="Demo Side Scheme",
                cardType="treachery", cardSubType="hazard", role="encounter",
                stats={ threat=3 },
                text="Enters with threat.\n(Encounter-side persistent objective.)",
            }
        },
        defaultSideId="front",
    }

    return { heroDef, villainDef, sideSchemeDef }
end

local function sampleDefs_LOTR()
    local heroDef = {
        id="LOTR_DEMO_HERO", game="lotr_lcg",
        sides = {
            front = {
                name="Demo Hero",
                cardType="identity", cardSubType="lotr_hero", role="player",
                stats={ willpower=2, attack=2, defense=1, hitPoints=4 },
                traits={ "Noble" },
                text="Response (paraphrased).\nPress E to exhaust/ready.",
            }
        },
        defaultSideId="front",
    }

    local questDef = {
        id="LOTR_DEMO_QUEST_STAGE1", game="lotr_lcg",
        sides = {
            A = {
                name="Demo Quest 1A",
                cardType="scenario", cardSubType="quest", role="encounter",
                stats={ questPoints=6 },
                text="Setup / When Revealed (paraphrased).\nRight-click to flip to 1B.",
                canFlipTo={ "B" },
            },
            B = {
                name="Demo Quest 1B",
                cardType="scenario", cardSubType="quest", role="encounter",
                stats={ questPoints=6 },
                text="While this stage is active...\n(paraphrased)",
                canFlipTo={},
            },
        },
        defaultSideId="A",
    }

    local locationDef = {
        id="LOTR_DEMO_LOCATION", game="lotr_lcg",
        sides = {
            front = {
                name="Demo Location",
                cardType="location", cardSubType="travel_location", role="encounter",
                stats={ threat=2, questPoints=3 },
                text="Travel: (paraphrased).\nBelongs in staging or active location.",
            }
        },
        defaultSideId="front",
    }

    return { heroDef, questDef, locationDef }
end

local function sampleDefs_Arkham()
    local investigatorDef = {
        id="AH_DEMO_INVESTIGATOR", game="arkham_lcg",
        sides = {
            front = {
                name="Demo Investigator",
                cardType="identity", cardSubType="investigator", role="player",
                stats={ willpower=3, intellect=3, combat=2, agility=2, health=8, sanity=6 },
                traits={ "Detective" },
                text="Ability (paraphrased).\nBack side has deckbuilding.\nRight-click to flip.",
                canFlipTo={ "back" },
            },
            back = {
                name="Demo Investigator",
                cardType="identity", cardSubType="investigator", role="player",
                text="Deckbuilding + story text (paraphrased).\nRight-click to flip front.",
                canFlipTo={ "front" },
            }
        },
        defaultSideId="front",
    }

    local agendaDef = {
        id="AH_DEMO_AGENDA_1", game="arkham_lcg",
        sides = {
            front = {
                name="Agenda 1a",
                cardType="scenario", cardSubType="agenda", role="encounter",
                stats={ doomThreshold=3 },
                text="Doom advances this.\nRight-click to flip to 1b.",
                canFlipTo={ "back" },
            },
            back = {
                name="Agenda 1b",
                cardType="scenario", cardSubType="agenda", role="encounter",
                text="When advanced: do bad things.\n(paraphrased)",
                canFlipTo={},
            }
        },
        defaultSideId="front",
    }

    local locationDef = {
        id="AH_DEMO_LOCATION", game="arkham_lcg",
        sides = {
            unrevealed = {
                name="Demo Location (Unrevealed)",
                cardType="location", cardSubType="investigation_location", role="encounter",
                text="Unrevealed side.\nRight-click to reveal.",
                canFlipTo={ "revealed" },
            },
            revealed = {
                name="Demo Location",
                cardType="location", cardSubType="investigation_location", role="encounter",
                stats={ shroud=2, cluesPerInvestigator=1 },
                text="Revealed side.\nInvestigate here.",
                canFlipTo={ "unrevealed" },
            }
        },
        defaultSideId="unrevealed",
    }

    return { investigatorDef, agendaDef, locationDef }
end

local function sampleDefs_Ashes()
    local phoenixbornDef = {
        id="ASHES_DEMO_PHOENIXBORN", game="ashes_reborn",
        sides = {
            front = {
                name="Demo Phoenixborn",
                cardType="identity", cardSubType="phoenixborn", role="player",
                stats={ life=15, battlefield=5, spellboard=3 },
                traits={ "Natural" },
                text="Phoenixborn powers (paraphrased).\nPress E to exhaust/ready.",
                canFlipTo={ "back" },
            },
            back = {
                name="Demo Phoenixborn",
                cardType="identity", cardSubType="phoenixborn", role="player",
                text="Back side / deckbuilding (paraphrased).",
                canFlipTo={ "front" },
            }
        },
        defaultSideId="front",
    }

    local bossDef = {
        id="ASHES_CORPSE_OF_VIROS_DEMO", game="ashes_reborn",
        sides = {
            front = {
                name="The Corpse of Viros",
                cardType="enemy", cardSubType="boss", role="encounter",
                stats={ health=30, threat=6, ultimate=5 },
                traits={ "Chimera" },
                text=
                    "Chimera (Boss)\n" ..
                    "Difficulty: Heroic Level 1\n" ..
                    "Players: 1–2\n" ..
                    "Starting Pattern stored in redRains.startingPattern.\n" ..
                    "(No stage flipping.)",
                redRains = {
                    difficultyId    = "heroic_1",
                    difficultyLabel = "Heroic Level 1",
                    playersSupported = { 1, 2 },
                    variants = {
                        ["1p"] = { health = 26 },
                        ["2p"] = { health = 30 },
                    },
                    threat   = 6,
                    ultimate = 5,
                    startingPattern = { 1,2,1,1,2,1 },
                },
            },
        },
        defaultSideId="front",
    }

    local readySpellDef = {
        id="ASHES_DEMO_READY_SPELL", game="ashes_reborn",
        sides = {
            front = {
                name="Demo Ready Spell",
                cardType="upgrade", cardSubType="ready_spell", role="player",
                stats={},
                text="Place on spellboard.\nSummon conjurations (paraphrased).",
            }
        },
        defaultSideId="front",
    }

    return { phoenixbornDef, bossDef, readySpellDef }
end

----------------------------------------------------------
-- 9. Layout helpers
----------------------------------------------------------

local function placeCardsInZone(zoneId, cardList)
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

local function layoutHand()
    local zone = zones.playerHand
    if not zone then return end

    local padding = 16
    local pileW = 130
    local left = zone.x + padding + pileW + padding
    local right = zone.x + zone.w - padding
    local usableW = right - left

    if #playerHand == 0 then return end

    local cardW = playerHand[1].w
    local gap = 16
    local totalW = #playerHand * cardW + (#playerHand - 1) * gap

    local minScroll = math.min(0, usableW - totalW)
    if handScrollX < minScroll then handScrollX = minScroll end
    if handScrollX > 0 then handScrollX = 0 end

    local y = zone.y + (zone.h - playerHand[1].h) / 2
    for i, card in ipairs(playerHand) do
        card.zoneId = "playerHand"
        card.x = left + handScrollX + (i-1) * (cardW + gap)
        card.y = y
    end
end

----------------------------------------------------------
-- 10. Draw piles UI positions (inside hand zone)
----------------------------------------------------------

local function getPileRects()
    local z = zones.playerHand
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

----------------------------------------------------------
-- 11. Card picking + dragging
----------------------------------------------------------

local function cardAtPosition(x, y)
    for i = #playerHand, 1, -1 do
        local c = playerHand[i]
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return c, "hand"
        end
    end

    for i = #cards, 1, -1 do
        local c = cards[i]
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return c, "board"
        end
    end

    return nil, nil
end

-- IMPORTANT FIX:
-- For hand: do NOT reorder list on click; that was causing “always rightmost selected”
-- and the apparent “swapping” of card titles/state.
local function bringToFront(card, where)
    if where == "hand" then
        return -- keep hand order stable
    end

    for i, c in ipairs(cards) do
        if c == card then
            table.remove(cards, i)
            table.insert(cards, card)
            return
        end
    end
end

----------------------------------------------------------
-- 12. Rendering
----------------------------------------------------------

local function drawZone(zone)
    love.graphics.setColor(0.16, 0.16, 0.20)
    love.graphics.rectangle("fill", zone.x, zone.y, zone.w, zone.h, 18, 18)
    love.graphics.setColor(0.55, 0.55, 0.65)
    love.graphics.rectangle("line", zone.x, zone.y, zone.w, zone.h, 18, 18)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print(zone.name, zone.x + 12, zone.y + 10)
end

local function drawCard(gameId, card, isSelected)
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

local function drawPilesAndButtons()
    local deckRect, discardRect, drawBtn, discardBtn = getPileRects()

    love.graphics.setColor(0.18, 0.18, 0.24)
    love.graphics.rectangle("fill", deckRect.x, deckRect.y, deckRect.w, deckRect.h, 12, 12)
    love.graphics.setColor(0.7, 0.7, 0.85)
    love.graphics.rectangle("line", deckRect.x, deckRect.y, deckRect.w, deckRect.h, 12, 12)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Deck\n"..tostring(#playerDeck), deckRect.x, deckRect.y + 40, deckRect.w, "center")

    love.graphics.setColor(0.18, 0.18, 0.24)
    love.graphics.rectangle("fill", discardRect.x, discardRect.y, discardRect.w, discardRect.h, 12, 12)
    love.graphics.setColor(0.7, 0.7, 0.85)
    love.graphics.rectangle("line", discardRect.x, discardRect.y, discardRect.w, discardRect.h, 12, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Discard\n"..tostring(#playerDiscard), discardRect.x, discardRect.y + 40, discardRect.w, "center")

    drawButton(drawBtn, "Draw", #playerDeck > 0)
    drawButton(discardBtn, "Discard\nSelected", selectedCard ~= nil)
    return deckRect, discardRect, drawBtn, discardBtn
end

local function drawPhaseBar()
    local phases = phaseLists[currentGameId] or { "Phase" }
    local x = 60
    local y = 40
    local w = 960
    local h = 72
    local padding = 10

    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", x, y, w, h, 16, 16)
    love.graphics.setColor(0.55, 0.55, 0.7)
    love.graphics.rectangle("line", x, y, w, h, 16, 16)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Phase:", x + 14, y + 22)

    local btnX = x + 110
    local btnY = y + 10
    local btnH = h - 20
    local btnW = math.floor((w - 130 - padding * (#phases - 1)) / #phases)

    local phaseButtons = {}
    for i, p in ipairs(phases) do
        local bx = btnX + (i-1) * (btnW + padding)
        local btn = { x=bx, y=btnY, w=btnW, h=btnH, phaseIndex=i }
        phaseButtons[i] = btn

        local active = (i == phaseIndex)
        love.graphics.setColor(active and 0.22 or 0.16, active and 0.22 or 0.16, active and 0.34 or 0.22)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 14, 14)
        love.graphics.setColor(active and 1 or 0.7, active and 1 or 0.7, active and 1 or 0.85)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 14, 14)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(p, btn.x, btn.y + 14, btn.w, "center")
    end

    return phaseButtons
end

----------------------------------------------------------
-- 13. Game loading
----------------------------------------------------------

local phaseButtons = {}
local drawBtnRect, discardBtnRect

local function loadGame(gameId)
    currentGameId = gameId
    selectedCard = nil
    cards = {}
    nextInstanceId = 1
    phaseIndex = 1

    resetPiles()
    createZonesForGame(gameId)

    local defs
    if gameId == "marvel" then defs = sampleDefs_Marvel()
    elseif gameId == "lotr" then defs = sampleDefs_LOTR()
    elseif gameId == "arkham" then defs = sampleDefs_Arkham()
    elseif gameId == "ashes" then defs = sampleDefs_Ashes()
    end

    local c1 = newCardInstance(defs[1])
    local c2 = newCardInstance(defs[2])
    local c3 = newCardInstance(defs[3])

    if gameId == "lotr" then
        placeCardsInZone("stagingArea", { c2 })
        placeCardsInZone("activeLocation", { c3 })
        placeCardsInZone("playerBoard", { c1 })
        cards = { c2, c3, c1 }
    else
        placeCardsInZone("encounterBoard", { c2 })
        placeCardsInZone("playerBoard", { c1, c3 })
        cards = { c2, c1, c3 }
    end

    -- Deck filler
    local internalGameKey =
        (gameId == "marvel" and "marvel_champions") or
        (gameId == "lotr" and "lotr_lcg") or
        (gameId == "arkham" and "arkham_lcg") or
        (gameId == "ashes" and "ashes_reborn") or
        gameId

    for i = 1, 10 do
        local def = makeGenericPlayerCard(internalGameKey, i)
        local inst = newCardInstance(def)
        table.insert(playerDeck, inst)
    end

    layoutHand()
end

----------------------------------------------------------
-- 14. Picking + dragging interactions
----------------------------------------------------------

function love.load()
    love.window.setTitle("LCG Engine Scaffold Demo (Multi-game)")
    love.graphics.setBackgroundColor(0.11, 0.11, 0.15)

    updateScreenScale()
    loadFonts()
    loadGame("marvel")
end

function love.resize(w, h) updateScreenScale() end

function love.update(dt)
    layoutHand()
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)

    phaseButtons = drawPhaseBar()

    for _, zone in pairs(zones) do
        drawZone(zone)
    end

    for _, card in ipairs(cards) do
        drawCard(currentGameId, card, card == selectedCard)
    end

    local _, _, drawBtn, discardBtn = drawPilesAndButtons()
    drawBtnRect = drawBtn
    discardBtnRect = discardBtn

    -- Draw hand cards, but draw the dragged hand card last (so it appears on top)
    local draggedHandCard = nil
    for _, card in ipairs(playerHand) do
        if card.dragging then
            draggedHandCard = card
        else
            drawCard(currentGameId, card, card == selectedCard)
        end
    end
    if draggedHandCard then
        drawCard(currentGameId, draggedHandCard, draggedHandCard == selectedCard)
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1)
    local hud =
        "Game: " .. currentGameId .. "   |   Phase: " .. currentPhaseName() .. "\n" ..
        "Keys: [1] Marvel  [2] LOTR  [3] Arkham  [4] Ashes PvE   |   [N] Next Phase\n" ..
        "Mouse: Left-drag move  |  Right-click flip  |  Wheel: scroll hand\n" ..
        "Selected: [E] Exhaust/Ready   |   [D] Discard Selected"
    love.graphics.print(hud, 60, VIRTUAL_HEIGHT - 170)

    love.graphics.pop()
end

function love.keypressed(key)
    if key == "1" then loadGame("marvel") end
    if key == "2" then loadGame("lotr") end
    if key == "3" then loadGame("arkham") end
    if key == "4" then loadGame("ashes") end

    if key == "n" then nextPhase() end
    if key == "e" then toggleExhaust(selectedCard) end
    if key == "d" then discardSelected(); layoutHand() end
end

function love.wheelmoved(dx, dy)
    if dy ~= 0 then
        handScrollX = handScrollX + dy * 60
        layoutHand()
    end
end

function love.mousepressed(x, y, button)
    local vx, vy = toVirtual(x, y)

    for _, btn in ipairs(phaseButtons or {}) do
        if pointInRect(vx, vy, btn) then
            setPhase(btn.phaseIndex)
            return
        end
    end

    if drawBtnRect and pointInRect(vx, vy, drawBtnRect) then
        drawOne()
        layoutHand()
        return
    end
    if discardBtnRect and pointInRect(vx, vy, discardBtnRect) then
        discardSelected()
        layoutHand()
        return
    end

    if button == 1 then
        local card, where = cardAtPosition(vx, vy)
        if card then
            selectedCard = card
            card.dragging = true
            card.dragOffsetX = vx - card.x
            card.dragOffsetY = vy - card.y
            bringToFront(card, where)
        else
            selectedCard = nil
        end
    elseif button == 2 then
        local card = select(1, cardAtPosition(vx, vy))
        if card then flipCard(card) end
    elseif button == 3 then
        local card = select(1, cardAtPosition(vx, vy))
        if card then
            selectedCard = card
            toggleExhaust(card)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and selectedCard then
        selectedCard.dragging = false
    end
end

function love.mousemoved(x, y, dx, dy)
    local vx, vy = toVirtual(x, y)
    if selectedCard and selectedCard.dragging then
        selectedCard.x = vx - selectedCard.dragOffsetX
        selectedCard.y = vy - selectedCard.dragOffsetY
    end
end
