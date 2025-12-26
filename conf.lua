local love = require "love"

function love.conf(t)
    t.identity = "data/saves" --where files are saved
    t.version = "11.4" --version number, supposedly version of love2d
    t.console = false --whether console should be attached, windows only

    --for android make true
    t.externalstorage = true -- whether you want to save it on external disk, like on sd card and not phone storage, might be android only
    t.gammacorrect = false -- if system supports it, enable gamma correct rendering
    t.audio.mic = true -- if on android and you want to enable microphone, will show popup for permission
    t.window.title = "LCG Cards"
    t.window.resizable = true -- usually don't want to resize this
    t.window.borderless = false
    t.window.vsync = 1 -- use number 1 if enabled

    t.window.width = 720
    t.window.height = 1280

    t.window.fsaa = 8

    -- t.window.x = 200 -- specifies x position for window, can also do this for y, probably best to save window location on exit
    t.modules.timer = true -- can disable specific modules, probably shouldn't use unless need something extra lightweight
    t.console = true
end