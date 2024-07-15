-- SETUP ---------------------------------------------------------------------------------------------------------------

display.setDefault("background", 0, .5, .8)

------------------------------------------------------------------------------------------------------------------------
-- RUN GAME --
------------------------------------------------------------------------------------------------------------------------

_G.Flow = require("Flow")

local r = math.random

local flow = Flow:branch()

local cx, cy = display.contentCenterX, display.contentCenterY
local ox, oy = display.screenOriginX, display.screenOriginY
local edgeX, edgeY = display.actualContentWidth, display.actualContentHeight

-- Sample 1
local obj1 = display.newRoundedRect(ox + 60, oy + 60, 60, 60, 2)
obj1.alpha = .5
obj1:setFillColor(0, 1, 0)
obj1.strokeWidth = 2


flow(obj1, { time = 2000, ease = "inOutQuad", iterations = -1 })
    :radius( 25, { bounce = true, ease = "inOutQuad" } )
    :rotate( 360, { ease = "linear" } )
    :alpha( 1, { bounce = true, ease = "inOutQuad" } )
    :color( {.5, 1}, {.5, 1}, {.5, 1}, { reset = true } )
    :size( 50, 50, { time = 2000, ease = "inOutQuad", bounce = true } )


-- sample 3
local circle = display.newCircle( ox + 60, cy, 5 )
-- circle:setFillColor( 1, 0, 0 )

flow(circle, { time = 70, ease = "outQuad", iterations = -1 })
    :move( {30, -30}, {-30, 30}, {reset = true})



local circle = display.newCircle( cx, oy + 60, 60 )
circle:setFillColor( 1, 0, 0 )
circle.strokeWidth = 1
circle:scale(.25, .25)
    
flow(circle, { time = 2000, ease = "outQuad", iterations = -1 })
    :strokeWidth( 1, {iterations = 1, time = 1000 } )
    :strokeWidth( 120, {ease = "inQuad", time = 2000, bounce = true, onRepeat = function() circle:setStrokeColor( r(), r(), r() ) end })
    :radius( 120, {time = 2000, bounce = true, onRepeat = function() circle:setFillColor( r(), r(), r() ) end } )

-- sample 4
local circle = display.newCircle( cx, cy, 30 )
circle:setFillColor( 1, 0, 0 )
circle.strokeWidth = 2

local f; f = flow(circle, { time = 700, ease = "inOutQuad" })
    :scale( .75, .75, { bounce = true, time = 700, iterations = -1 } )
    :move( 0, 100 )
    :move( 100, 0 )
    :move( 0, -100 )
    :move( -100, 0, { onComplete = function() f:rewind(4, "position") end } )

local flow = Flow:branch()

-- Scheduling a task
local task = flow:performWithDelay(500, function()
    print("Task executed.")
end, 5)

-- Manipulating a running task
task:fastForward(1500)  -- This will complete 3 of the 5 scheduled executions
