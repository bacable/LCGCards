local love = require "love"

local Util = {}

function Util.updateScreenScale(state)
    state.windowWidth, state.windowHeight = love.graphics.getDimensions()
    local scaleX = state.windowWidth / state.VIRTUAL_WIDTH
    local scaleY = state.windowHeight / state.VIRTUAL_HEIGHT
    state.scale = math.min(scaleX, scaleY)
    state.offsetX = (state.windowWidth - state.VIRTUAL_WIDTH * state.scale) / 2
    state.offsetY = (state.windowHeight - state.VIRTUAL_HEIGHT * state.scale) / 2
end

function Util.toVirtual(state, x, y)
    return (x - state.offsetX) / state.scale, (y - state.offsetY) / state.scale
end

function Util.pointInRect(px, py, rect)
    return rect
        and px >= rect.x and px <= rect.x + rect.w
        and py >= rect.y and py <= rect.y + rect.h
end

return Util
