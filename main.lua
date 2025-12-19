-- main.lua
-- Basic LCG-style scaffold for Love2D:
-- - Virtual resolution & scaling
-- - Simple CardDef / CardInstance model with multiple sides
-- - Three zones + dragging + right-click flip

----------------------------------------------------------
-- 1. Virtual resolution / scaling
----------------------------------------------------------

local love = require "love"

local VIRTUAL_WIDTH  = 1080
local VIRTUAL_HEIGHT = 1920

local windowWidth, windowHeight
local scale          = 1
local offsetX        = 0
local offsetY        = 0

local function updateScreenScale()
    windowWidth, windowHeight = love.graphics.getDimensions()
    local scaleX = windowWidth  / VIRTUAL_WIDTH
    local scaleY = windowHeight / VIRTUAL_HEIGHT
    scale = math.min(scaleX, scaleY)

    -- Center the virtual area in the window
    offsetX = (windowWidth  - VIRTUAL_WIDTH  * scale) / 2
    offsetY = (windowHeight - VIRTUAL_HEIGHT * scale) / 2
end

-- Convert real screen coords to virtual coords
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
        w            = 220,
        h            = 320,

        dragging     = false,
        dragOffsetX  = 0,
        dragOffsetY  = 0,
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

    -- If canFlipTo is defined, cycle through those options
    if canFlipTo and #canFlipTo > 0 then
        -- For now just pick the first one; you can later add “cycle through” logic.
        card.activeSideId = canFlipTo[1]
        return
    end

    -- Fallback: if def defines exactly 2 sides, toggle between them
    local sideKeys = {}
    for key,_ in pairs(card.def.sides) do
        table.insert(sideKeys, key)
    end
    if #sideKeys == 2 then
        card.activeSideId = (card.activeSideId == sideKeys[1]) and sideKeys[2] or sideKeys[1]
    end
end

----------------------------------------------------------
-- 3. Zones & simple game state
----------------------------------------------------------

local zones = {}
local cards = {}

local selectedCard = nil

local function createZones()
    zones = {
        -- Encounter / villain area (top)
        encounterBoard = {
            id   = "encounterBoard",
            name = "Encounter",
            x    = 60,
            y    = 160,
            w    = 960,
            h    = 480,
        },

        -- Player board area (middle)
        playerBoard = {
            id   = "playerBoard",
            name = "Player Board",
            x    = 60,
            y    = 720,
            w    = 960,
            h    = 480,
        },

        -- Player hand (bottom)
        playerHand = {
            id   = "playerHand",
            name = "Hand",
            x    = 60,
            y    = 1320,
            w    = 960,
            h    = 480,
        },
    }
end

local function placeCardInZone(card, zoneId, index)
    card.zoneId = zoneId
    local zone = zones[zoneId]
    if not zone then return end

    -- Simple layout: place cards in a row within the zone, spaced by card width
    local padding = 20
    local slotW   = card.w + padding
    index = index or 1
    card.x = zone.x + padding + (index - 1) * slotW
    card.y = zone.y + (zone.h - card.h) / 2
end

----------------------------------------------------------
-- 4. Sample CardDefs (Marvel-style hero & villain)
----------------------------------------------------------

local function createSampleCardDefs()
    -- Simple Hero identity with two sides (alter-ego + hero)
    local heroDef = {
        id           = "DEMO_HERO_IDENTITY",
        game         = "marvel_champions",
        globalTraits = { "Demo" },

        sides = {
            alter_ego = {
                name        = "Demo Alter-Ego",
                cardType    = "identity",
                cardSubType = "alter_ego",
                role        = "player",

                handSize    = 6,
                stats       = { recover = 3, hitPoints = 11 },
                traits      = { "Civilian" },
                text        = "Alter-ego ability text goes here.\n(Recover 3.)",

                -- For the demo, we don't load images, just text.
                images      = {},
                formTag     = "alter_ego",
                canFlipTo   = { "hero" },
            },

            hero = {
                name        = "Demo Hero",
                cardType    = "identity",
                cardSubType = "hero",
                role        = "player",

                handSize    = 5,
                stats       = { thwart = 2, attack = 2, defense = 2, hitPoints = 11 },
                traits      = { "Avenger", "Soldier" },
                text        = "Hero ability text goes here.\n(Ready once per round.)",

                images      = {},
                formTag     = "hero",
                canFlipTo   = { "alter_ego" },
            },
        },

        defaultSideId = "alter_ego",

        printings = {
            {
                setId       = "DEMO_SET",
                setName     = "Demo Starter",
                cardNumbers = { 1 },
                modularTags = { "DemoHero" },
            },
        },
    }

    -- Simple Villain with two stages
    local villainDef = {
        id   = "DEMO_VILLAIN",
        game = "marvel_champions",

        sides = {
            stage1 = {
                name        = "Demo Villain I",
                cardType    = "scenario",
                cardSubType = "villain",
                role        = "encounter",

                stats       = { attack = 2, scheme = 1, hitPoints = 14 },
                traits      = { "Criminal" },
                text        = "Stage I villain text.\nWhen defeated, flip to Stage II.",
                images      = {},
                canFlipTo   = { "stage2" },
            },
            stage2 = {
                name        = "Demo Villain II",
                cardType    = "scenario",
                cardSubType = "villain",
                role        = "encounter",

                stats       = { attack = 3, scheme = 2, hitPoints = 16 },
                traits      = { "Criminal" },
                text        = "Stage II villain text.\nFinal stage for the demo.",
                images      = {},
                canFlipTo   = {}, -- end of line
            },
        },

        defaultSideId = "stage1",

        printings = {
            {
                setId       = "DEMO_SET",
                setName     = "Demo Starter",
                cardNumbers = { 10 },
                modularTags = { "DemoVillain" },
            },
        },
    }

    return heroDef, villainDef
end

----------------------------------------------------------
-- 5. Input helpers: card picking & dragging
----------------------------------------------------------

local function cardAtPosition(x, y)
    -- simple topmost-first search; if you later track z-order, iterate in that.
    for i = #cards, 1, -1 do
        local c = cards[i]
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            return c
        end
    end
    return nil
end

----------------------------------------------------------
-- 6. Love2D callbacks
----------------------------------------------------------

function love.load()
    love.window.setTitle("LCG Engine Scaffold Demo")
    love.graphics.setBackgroundColor(0.12, 0.12, 0.16)

    updateScreenScale()

    createZones()

    local heroDef, villainDef = createSampleCardDefs()

    -- Create instances
    local heroCard    = newCardInstance(heroDef)
    local villainCard = newCardInstance(villainDef)

    -- Put villain in encounter zone, hero in player board
    placeCardInZone(villainCard, "encounterBoard", 1)
    placeCardInZone(heroCard, "playerBoard", 1)

    cards = { villainCard, heroCard }
end

function love.resize(w, h)
    updateScreenScale()
end

function love.update(dt)
    -- Future: animations, timers, game logic
end

function love.draw()
    -- apply virtual resolution transform
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)

    -- draw zones
    for _, zone in pairs(zones) do
        love.graphics.setColor(0.16, 0.16, 0.20)
        love.graphics.rectangle("fill", zone.x, zone.y, zone.w, zone.h, 16, 16)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("line", zone.x, zone.y, zone.w, zone.h, 16, 16)

        love.graphics.setColor(0.8, 0.8, 0.9)
        love.graphics.print(zone.name, zone.x + 8, zone.y + 8)
    end

    -- draw cards
    for _, card in ipairs(cards) do
        local side = getActiveSide(card)
        local isSelected = (card == selectedCard)

        -- Card body
        if isSelected then
            love.graphics.setColor(0.25, 0.25, 0.35)
        else
            love.graphics.setColor(0.2, 0.2, 0.3)
        end
        love.graphics.rectangle("fill", card.x, card.y, card.w, card.h, 12, 12)

        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.rectangle("line", card.x, card.y, card.w, card.h, 12, 12)

        -- Name bar
        love.graphics.setColor(0.15, 0.15, 0.25)
        love.graphics.rectangle("fill", card.x, card.y, card.w, 40, 12, 12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(side.name or "(No name)", card.x + 8, card.y + 10)

        -- Type / subtype
        love.graphics.setColor(0.9, 0.9, 0.9)
        local typeText = (side.cardType or "") .. (side.cardSubType and (" / " .. side.cardSubType) or "")
        love.graphics.print(typeText, card.x + 8, card.y + 50)

        -- Some stats displayed in corners (if present)
        if side.stats then
            local stats = side.stats
            local textBits = {}

            if stats.thwart then table.insert(textBits, "THW:" .. stats.thwart) end
            if stats.attack then table.insert(textBits, "ATK:" .. stats.attack) end
            if stats.defense then table.insert(textBits, "DEF:" .. stats.defense) end
            if stats.recover then table.insert(textBits, "REC:" .. stats.recover) end
            if stats.hitPoints then table.insert(textBits, "HP:" .. stats.hitPoints) end

            love.graphics.print(table.concat(textBits, "  "),
                card.x + 8, card.y + card.h - 28)
        end

        -- Text box
        love.graphics.setColor(0.85, 0.85, 0.9)
        local text = side.text or ""
        love.graphics.printf(text, card.x + 8, card.y + 80, card.w - 16)
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Left-click & drag cards to move.\nRight-click a card to flip side.",
        40, VIRTUAL_HEIGHT - 80)

    love.graphics.pop()
end

function love.mousepressed(x, y, button)
    local vx, vy = toVirtual(x, y)

    if button == 1 then -- left
        local card = cardAtPosition(vx, vy)
        if card then
            selectedCard = card
            card.dragging = true
            card.dragOffsetX = vx - card.x
            card.dragOffsetY = vy - card.y

            -- move card to top of draw order
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
    elseif button == 2 then -- right-click flips card (if any)
        local card = cardAtPosition(vx, vy)
        if card then
            flipCard(card)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        if selectedCard then
            selectedCard.dragging = false
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    local vx, vy = toVirtual(x, y)
    if selectedCard and selectedCard.dragging then
        selectedCard.x = vx - selectedCard.dragOffsetX
        selectedCard.y = vy - selectedCard.dragOffsetY
    end
end
