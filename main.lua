-- main.lua
-- LCG Engine Scaffold Demo v3
-- Updates:
-- - LOTR: adds Active Location zone; location placed with encounter-side zones
-- - Ashes PvE (Red Rains): boss modeled as difficulty variant sheet (no stage flipping)
-- - Ashes stats renderer shows HEALTH/THREAT/ULT for boss cards

----------------------------------------------------------
-- 1. Virtual resolution / scaling
----------------------------------------------------------

local love = require "love"

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
        tokens       = {}, -- optional runtime token store later
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

----------------------------------------------------------
-- 3. Zones & layout
----------------------------------------------------------

local zones = {}
local cards = {}
local selectedCard = nil

local function createZonesForGame(gameId)
    -- layout in portrait; each game changes labels and shapes a little
    if gameId == "marvel" then
        zones = {
            encounterBoard = { id="encounterBoard", name="Villain / Schemes", x=60, y=120,  w=960, h=520 },
            playerBoard    = { id="playerBoard",    name="Hero / Allies",     x=60, y=700,  w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    elseif gameId == "lotr" then
        zones = {
            stagingArea    = { id="stagingArea",    name="Staging / Quest",   x=60, y=120,  w=960, h=380 },
            activeLocation = { id="activeLocation", name="Active Location",   x=60, y=520,  w=960, h=200 },
            playerBoard    = { id="playerBoard",    name="Heroes / Allies",   x=60, y=760,  w=960, h=480 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    elseif gameId == "arkham" then
        zones = {
            encounterBoard = { id="encounterBoard", name="Agenda / Act",      x=60, y=120,  w=960, h=420 },
            playerBoard    = { id="playerBoard",    name="Play Area",         x=60, y=600,  w=960, h=640 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    elseif gameId == "ashes" then
        zones = {
            encounterBoard = { id="encounterBoard", name="Boss / Encounter",  x=60, y=120,  w=960, h=520 },
            playerBoard    = { id="playerBoard",    name="Spellboard / Units",x=60, y=700,  w=960, h=540 },
            playerHand     = { id="playerHand",     name="Hand",              x=60, y=1320, w=960, h=540 },
        }
    end
end

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

----------------------------------------------------------
-- 4. Unified taxonomy helpers (for display)
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
-- 5. Sample content per game
----------------------------------------------------------

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
                text="Alter-ego ability (paraphrased).\nRight-click to flip to Hero.",
                canFlipTo={ "hero" },
            },
            hero = {
                name="Demo Hero",
                cardType="identity", cardSubType="hero", role="player",
                handSize=5,
                stats={ thwart=2, attack=2, defense=2, hitPoints=11 },
                traits={ "Avenger" },
                text="Hero ability (paraphrased).\nRight-click to flip to Alter-Ego.",
                canFlipTo={ "alter_ego" },
            },
        },
        defaultSideId="alter_ego",
        printings={ { setId="DEMO", setName="Demo", cardNumbers={1}, modularTags={"Demo"} } }
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
        printings={ { setId="DEMO", setName="Demo", cardNumbers={10}, modularTags={"Demo"} } }
    }

    local sideSchemeDef = {
        id="MC_DEMO_SIDE_SCHEME", game="marvel_champions",
        sides = {
            front = {
                name="Demo Side Scheme",
                cardType="treachery", cardSubType="hazard", role="encounter",
                stats={ threat=3 },
                text="Enters with threat.\n(Represents persistent scenario pressure.)",
            }
        },
        defaultSideId="front",
        printings={ { setId="DEMO", setName="Demo", cardNumbers={11}, modularTags={"Demo"} } }
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
                text="Response (paraphrased).\nA simple hero example.",
            }
        },
        defaultSideId="front",
        printings={ { setId="DEMO", setName="Demo", cardNumbers={1}, modularTags={"Demo"} } }
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
        printings={ { setId="DEMO", setName="Demo", cardNumbers={50}, modularTags={"DemoQuest"} } }
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
        printings={ { setId="DEMO", setName="Demo", cardNumbers={60}, modularTags={"DemoQuest"} } }
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
                text="Ability (paraphrased).\nBack side has deckbuilding.",
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
        printings={ { setId="DEMO", setName="Demo", cardNumbers={1}, modularTags={"Demo"} } }
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
        printings={ { setId="DEMO", setName="Demo", cardNumbers={100}, modularTags={"Scenario"} } }
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
        printings={ { setId="DEMO", setName="Demo", cardNumbers={120}, modularTags={"Scenario"} } }
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
                text="Phoenixborn powers (paraphrased).\n(Spellboard + battlefield limits.)",
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
        printings={ { setId="DEMO", setName="Demo", cardNumbers={1}, modularTags={"Demo"} } }
    }

    -- Red Rains boss modeled as a "sheet" with difficulty variant info.
    -- No stage flipping; behavior/ultimate decks level up later (not modeled yet).
    local bossDef = {
        id="ASHES_CORPSE_OF_VIROS_DEMO", game="ashes_reborn",
        sides = {
            front = {
                name="The Corpse of Viros",
                cardType="enemy", cardSubType="boss", role="encounter",

                -- displayed stats:
                stats={ health=30, threat=6, ultimate=5 },

                traits={ "Chimera" },

                text=
                    "Chimera (Boss)\n" ..
                    "Difficulty: Heroic Level 1\n" ..
                    "Players: 1–2\n\n" ..
                    "Starting Pattern is a sequence of droplet icons (length = THREAT).\n" ..
                    "In this demo, it's stored as numbers in redRains.startingPattern.\n" ..
                    "Right-click does nothing here (no stage flip).",

                redRains = {
                    difficultyId    = "heroic_1",
                    difficultyLabel = "Heroic Level 1",
                    playersSupported = { 1, 2 },

                    variants = {
                        ["1p"] = { health = 26 }, -- placeholder values for demo
                        ["2p"] = { health = 30 },
                    },

                    threat   = 6,
                    ultimate = 5,

                    -- 1 = single droplet, 2 = double droplet
                    startingPattern = { 1,2,1,1,2,1 },
                },

                canFlipTo = nil,
            },
        },
        defaultSideId="front",
        printings={ { setId="DEMO", setName="Demo", cardNumbers={200}, modularTags={"RedRains"} } }
    }

    local readySpellDef = {
        id="ASHES_DEMO_READY_SPELL", game="ashes_reborn",
        sides = {
            front = {
                name="Demo Ready Spell",
                cardType="upgrade", cardSubType="ready_spell", role="player",
                stats={ },
                text="Place on spellboard.\nSummon conjurations (paraphrased).",
            }
        },
        defaultSideId="front",
        printings={ { setId="DEMO", setName="Demo", cardNumbers={20}, modularTags={"Spells"} } }
    }

    return { phoenixbornDef, bossDef, readySpellDef }
end

local function loadGame(gameId)
    selectedCard = nil
    cards = {}
    nextInstanceId = 1

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
        -- quest + encounter things up top
        placeCardsInZone("stagingArea", { c2 })       -- Quest stage
        placeCardsInZone("activeLocation", { c3 })    -- Location example
        placeCardsInZone("playerBoard", { c1 })       -- Hero
        placeCardsInZone("playerHand", {})
        cards = { c2, c3, c1 }
    else
        -- default layout: scenario card top, player cards mid, hand bottom
        placeCardsInZone("encounterBoard", { c2 })
        placeCardsInZone("playerBoard", { c1, c3 })
        placeCardsInZone("playerHand", {})
        cards = { c2, c1, c3 }
    end
end

----------------------------------------------------------
-- 6. Rendering
----------------------------------------------------------

local fonts = {}

local function loadFonts()
    fonts.title = love.graphics.newFont(28)
    fonts.small = love.graphics.newFont(20)
    fonts.tiny  = love.graphics.newFont(18)
end

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

    -- Card base
    if isSelected then love.graphics.setColor(0.26, 0.26, 0.36)
    else love.graphics.setColor(0.20, 0.20, 0.30) end
    love.graphics.rectangle("fill", card.x, card.y, card.w, card.h, 14, 14)

    love.graphics.setColor(0.85, 0.85, 0.92)
    love.graphics.rectangle("line", card.x, card.y, card.w, card.h, 14, 14)

    -- Header strip
    love.graphics.setColor(0.14, 0.14, 0.22)
    love.graphics.rectangle("fill", card.x, card.y, card.w, 54, 14, 14)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(side.name or "(No name)", card.x + 10, card.y + 10, card.w - 20, "left")

    -- Type line
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.92, 0.92, 0.98)
    love.graphics.printf(formatTypeLine(side), card.x + 10, card.y + 62, card.w - 20, "left")

    -- Traits line (if any)
    if side.traits and #side.traits > 0 then
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf("Traits: " .. table.concat(side.traits, ", "),
            card.x + 10, card.y + 88, card.w - 20, "left")
    end

    -- Stats strip
    local statsText = formatStatsLine(gameId, side)
    if statsText and statsText ~= "" then
        love.graphics.setColor(0.13, 0.13, 0.20)
        love.graphics.rectangle("fill", card.x + 10, card.y + card.h - 54, card.w - 20, 44, 10, 10)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.printf(statsText, card.x + 18, card.y + card.h - 46, card.w - 36, "left")
    end

    -- Text box
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.92, 0.92, 0.98)
    local textTop = card.y + 120
    love.graphics.printf(side.text or "", card.x + 10, textTop, card.w - 20, "left")

    -- Selected border emphasis
    if isSelected then
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", card.x - 3, card.y - 3, card.w + 6, card.h + 6, 16, 16)
    end
end

----------------------------------------------------------
-- 7. Input: picking & dragging
----------------------------------------------------------

local function cardAtPosition(x, y)
    for i = #cards, 1, -1 do
        local c = cards[i]
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return c
        end
    end
    return nil
end

----------------------------------------------------------
-- 8. Game selection + Love2D callbacks
----------------------------------------------------------

local currentGameId = "marvel"

function love.load()
    love.window.setTitle("LCG Engine Scaffold Demo (Multi-game)")
    love.graphics.setBackgroundColor(0.11, 0.11, 0.15)

    updateScreenScale()
    loadFonts()

    loadGame(currentGameId)
end

function love.resize(w, h)
    updateScreenScale()
end

function love.update(dt) end

function love.draw()
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)

    -- zones
    for _, zone in pairs(zones) do
        drawZone(zone)
    end

    -- cards
    for _, card in ipairs(cards) do
        drawCard(currentGameId, card, card == selectedCard)
    end

    -- HUD / instructions
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1)
    local hud =
        "Game: " .. currentGameId .. "\n" ..
        "Keys: [1] Marvel  [2] LOTR  [3] Arkham  [4] Ashes PvE\n" ..
        "Mouse: Left-drag move  |  Right-click flip side"
    love.graphics.print(hud, 60, VIRTUAL_HEIGHT - 150)

    love.graphics.pop()
end

function love.keypressed(key)
    if key == "1" then currentGameId = "marvel"; loadGame(currentGameId) end
    if key == "2" then currentGameId = "lotr";   loadGame(currentGameId) end
    if key == "3" then currentGameId = "arkham"; loadGame(currentGameId) end
    if key == "4" then currentGameId = "ashes";  loadGame(currentGameId) end
end

function love.mousepressed(x, y, button)
    local vx, vy = toVirtual(x, y)

    if button == 1 then
        local card = cardAtPosition(vx, vy)
        if card then
            selectedCard = card
            card.dragging = true
            card.dragOffsetX = vx - card.x
            card.dragOffsetY = vy - card.y

            -- move to top
            for i, c in ipairs(cards) do
                if c == card then
                    table.remove(cards, i)
                    table.insert(cards, card)
                    break
                end
            end
        else
            selectedCard = nil
        end
    elseif button == 2 then
        local card = cardAtPosition(vx, vy)
        if card then
            -- Ashes boss has no canFlipTo, so flipCard will do nothing (as desired)
            flipCard(card)
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
