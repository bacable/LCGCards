local love = require "love"

local State = require "src.state"
local Util = require "src.util"
local CardModel = require "src.model_card"
local LayoutZones = require "src.layout_zones"
local ContentSamples = require "src.content_samples"
local PhaseUI = require "src.ui_phasebar"
local UIPiles = require "src.ui_piles"
local Render = require "src.render"
local Input = require "src.input"

local state = State.new()

local function loadFonts()
    state.fonts.title = love.graphics.newFont(28)
    state.fonts.small = love.graphics.newFont(20)
    state.fonts.tiny  = love.graphics.newFont(18)
end

local function buildSampleCards(gameId, defs)
    local c1 = CardModel.newInstance(state, defs[1])
    local c2 = CardModel.newInstance(state, defs[2])
    local c3 = CardModel.newInstance(state, defs[3])

    if gameId == "lotr" then
        LayoutZones.moveCard(state, c2, "stagingArea")
        LayoutZones.moveCard(state, c3, "activeLocation")
        LayoutZones.moveCard(state, c1, "playerBoard")
    else
        if gameId == "marvel" then
            LayoutZones.moveCard(state, c2, "villain")
            LayoutZones.moveCard(state, c3, "encounterBoard")
            LayoutZones.moveCard(state, c1, "playerIdentity")
        else
            LayoutZones.moveCard(state, c2, "encounterBoard")
            LayoutZones.moveCard(state, c1, "playerBoard")
            LayoutZones.moveCard(state, c3, "playerBoard")
        end
    end
end

local function fillDemoDeck(gameId)
    local internalKey = ContentSamples.deckGameKey(gameId)
    for i = 1, 10 do
        local def = ContentSamples.makeGenericPlayerCard(internalKey, i)
        local inst = CardModel.newInstance(state, def)
        table.insert(state.playerDeck, inst)
    end
end

local function loadGame(gameId)
    state.currentGameId = gameId
    state.selectedCard = nil
    state.zoomCard = nil
    state.nextInstanceId = 1
    state.phaseIndex = 1

    state.zones, state.zoneOrder = LayoutZones.createZonesForGame(gameId)
    LayoutZones.initZoneCards(state)
    UIPiles.resetPiles(state)

    state.playerHand = state.zoneCards.playerHand or {}
    state.playerDeck = state.zoneCards.playerDeck or {}
    state.playerDiscard = state.zoneCards.playerDiscard or {}

    local defs = ContentSamples.sampleDefs(gameId)
    if #defs >= 3 then
        buildSampleCards(gameId, defs)
    end

    fillDemoDeck(gameId)
    LayoutZones.layoutAll(state)
end

local function loadInitialState()
    love.window.setTitle("LCG Engine Scaffold Demo (Multi-game)")
    love.graphics.setBackgroundColor(0.11, 0.11, 0.15)

    Util.updateScreenScale(state)
    loadFonts()
    loadGame("marvel")
end

local app = {}

function app.load()
    loadInitialState()
end

function app.resize(w, h)
    Util.updateScreenScale(state)
end

function app.update(dt)
    LayoutZones.layoutHand(state)
end

function app.draw()
    Render.draw(state, CardModel.getActiveSide)
end

function app.keypressed(key)
    Input.keypressed(state, key, { loadGame = loadGame })
end

function app.wheelmoved(dx, dy)
    Input.wheelmoved(state, dx, dy)
end

function app.mousepressed(x, y, button)
    Input.mousepressed(state, x, y, button, { loadGame = loadGame })
end

function app.mousereleased(x, y, button)
    Input.mousereleased(state, x, y, button)
end

function app.mousemoved(x, y, dx, dy)
    Input.mousemoved(state, x, y, dx, dy)
end

return app
