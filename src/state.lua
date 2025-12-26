local love = require "love"

local State = {}

local function newState()
    return {
        VIRTUAL_WIDTH  = 1080,
        VIRTUAL_HEIGHT = 1920,

        windowWidth = 0,
        windowHeight = 0,
        scale = 1,
        offsetX = 0,
        offsetY = 0,

        zones = {},
        cards = {},
        selectedCard = nil,

        fonts = {},
        phaseButtons = {},
        drawBtnRect = nil,
        discardBtnRect = nil,

        currentGameId = "marvel",
        phaseIndex = 1,

        playerDeck = {},
        playerHand = {},
        playerDiscard = {},
        handScrollX = 0,

        nextInstanceId = 1,
    }
end

function State.new()
    return newState()
end

return State
