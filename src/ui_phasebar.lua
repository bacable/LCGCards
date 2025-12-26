local love = require "love"

local PhaseUI = {}

local phaseLists = {
    marvel = { "Setup", "Player Phase", "Villain Phase", "Encounter", "End / Cleanup" },
    lotr   = { "Resource", "Planning", "Quest", "Travel", "Encounter", "Combat", "Refresh" },
    arkham = { "Mythos", "Investigation", "Enemy", "Upkeep" },
    ashes  = { "Setup", "Player Turn", "Encounter (Threat)", "Resolution", "End / Cleanup" },
}

function PhaseUI.currentPhaseName(state)
    local list = phaseLists[state.currentGameId] or { "Phase" }
    return list[state.phaseIndex] or list[1]
end

function PhaseUI.nextPhase(state)
    local list = phaseLists[state.currentGameId] or { "Phase" }
    state.phaseIndex = state.phaseIndex + 1
    if state.phaseIndex > #list then state.phaseIndex = 1 end
end

function PhaseUI.setPhase(state, i)
    local list = phaseLists[state.currentGameId] or { "Phase" }
    if i >= 1 and i <= #list then
        state.phaseIndex = i
    end
end

function PhaseUI.draw(state)
    local phases = phaseLists[state.currentGameId] or { "Phase" }
    local x = 60
    local y = 40
    local w = 960
    local h = 72
    local padding = 10

    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", x, y, w, h, 16, 16)
    love.graphics.setColor(0.55, 0.55, 0.7)
    love.graphics.rectangle("line", x, y, w, h, 16, 16)

    love.graphics.setFont(state.fonts.small)
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

        local active = (i == state.phaseIndex)
        love.graphics.setColor(active and 0.22 or 0.16, active and 0.22 or 0.16, active and 0.34 or 0.22)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 14, 14)
        love.graphics.setColor(active and 1 or 0.7, active and 1 or 0.7, active and 1 or 0.85)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 14, 14)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(p, btn.x, btn.y + 14, btn.w, "center")
    end

    return phaseButtons
end

return PhaseUI
