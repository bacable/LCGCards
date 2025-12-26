local love = require "love"

local app = require "src.app"

function love.load()
    app.load()
end

function love.resize(w, h)
    app.resize(w, h)
end

function love.update(dt)
    app.update(dt)
end

function love.draw()
    app.draw()
end

function love.keypressed(key)
    app.keypressed(key)
end

function love.wheelmoved(dx, dy)
    app.wheelmoved(dx, dy)
end

function love.mousepressed(x, y, button)
    app.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    app.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    app.mousemoved(x, y, dx, dy)
end
