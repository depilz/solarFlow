local Flow = setmetatable({}, { __call = function(self, target, kind, params) return self:new(target, kind, params, 4) end })

local branchMeta = { 
    __index = Flow,
    __call = function(self, target, kind, params) return self:new(target, kind, params, 4) 
end }


-- helpers -------------------------------------------------------------------------------------------------------------

local type = _G.type
local random = math.random
local unpack = unpack
local zero = 0.000000001 -- just to avoid floating point errors
local function assert(level, condition, message, ...)
    if not condition then
        error(message:format(...), level)
    end
end

local function sum(a, b)
    return a + b
end

local function mult(a, b)
    return a * b
end

local function getValue(t)
    if type(t) == "table" then
        if t[2] then
            return t[1] + random() * (t[2] - t[1])
        else
            return random() * t[1]
        end
    end

    return t
end


local function getParam(dst, src, op)
    if not dst then return nil end

    if type(dst) == "table" then
        assert(4, type(dst[1]) == "number", "Invalid range")
        assert(4, type(dst[2]) == "number", "Invalid range")
        return {op( src, dst[1] ), op( src, dst[2] )}
    end

    return op(src, dst)
end

local function getTargetName(target)
    return target.__name__
        or target.name
        or target.id
        or target.alias
        or "Unknown"
end

local function getEase(ease, _level)
    if not ease then return nil end

    if type(ease) == "string" then
        local fn = easing[ease]
        assert(_level, fn, ease .. " is not a valid easing function")
        return fn
    end

    assert(_level, type(ease) == "function", "Invalid easing function")
    return ease
end

------------------------------------------------------------------------------------------------------------------------
-- Flow main class
------------------------------------------------------------------------------------------------------------------------

-- branching -----------------------------------------------------------------------------------------------------------

Flow._children = {}
Flow._kind = "scene"

function Flow:branch(kind)
    local branch = setmetatable({}, branchMeta)
    branch._children = {}

    -- kind is meant to be used in cases you have other enterFrame dispatchers you want to subscribe to
    -- default is "Runtimes' enterFrame"
    branch._kind = kind or self._kind
    
    branch.__parent = self
    self._children[branch] = true

    return branch
end

-- branch lifecycle ----------------------------------------------------------------------------------------------------

function Flow:pause(tag)
    for child, _ in pairs(self._children) do
        child:pause(tag)
    end
end

function Flow:resume(tag)
    for child, _ in pairs(self._children) do
        child:resume(tag)
    end
end

function Flow:stop(tag)
    for child, _ in pairs(self._children) do
        child:stop(tag)
    end
end
Flow.cancel = Flow.stop

function Flow:destroy()
    self:cancel()

    self.__parent._children[self] = nil
    for child, _ in pairs(self._children) do
        child:destroy()
    end 

    setmetatable(self, nil)
    for k, _ in pairs(self) do
        self[k] = nil
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Perform with delay
------------------------------------------------------------------------------------------------------------------------

local Task = {}
local taskMeta = { __index = Task }

function Flow:performWithDelay(delay, func, iterations)
    local delayType = type(delay)
    local funcType = type(func)
    assert(3, delayType == "number", "bad argument #1 to 'performWithDelay' (number expected, got %s)", delayType)
    assert(3, funcType == "function", "bad argument #2 to 'performWithDelay' (function expected, got %s)", funcType)

    local task = setmetatable({
        delay  = delay,
        func   = func,
        time   = 0,
        kind   = self._kind,
        __paused = false,
        __prevTime = system.getTimer(),
        iterations = iterations or 1,
    }, taskMeta)

    self._children[task] = true
    task.__parent = self

    task:__subscribe()

    return task
end

function Flow:nextFrame(fn)
    return self:performWithDelay(0, fn)
end

function Task:__subscribe()
    if self.kind == "scene" then
        Runtime:addEventListener("enterFrame", self)
    end
end

function Task:__unsubscribe()
    if self.kind == "scene" then
        Runtime:removeEventListener("enterFrame", self)
    end
end

function Task:tick()
    self:__update()
end

function Task:enterFrame()
    self:__update()
end

function Task:__update()
    local time = system.getTimer()
    local timeElapsed = time - self.__prevTime
    self:step(timeElapsed)
    self.__prevTime = time
end

function Task:step(ms)
    self.time = self.time + ms

    while self.time > self.delay do
        self.func()

        if self.destroy then 
            self.iterations = self.iterations - 1
            if self.iterations == 0 then
                self:destroy()
                return false

            else
                self.time = self.time - self.delay

            end
        else
            -- task was destroyed on callback
            return
            
        end
    end

    return true
end

Task.fastForward = Task.step

function Task:getProgress()
    return self.time / self.delay
end

function Task:pause()
    self:__unsubscribe()
end

function Task:resume()
    self.__prevTime = system.getTimer()
    self:__subscribe()
end

function Task:stop()
    self:destroy()
end
Task.cancel = Task.stop

function Task:destroy()
    self.__parent._children[self] = nil
    self:__unsubscribe()

    setmetatable(self, nil)
    for k, _ in pairs(self) do
        self[k] = nil
    end
end



------------------------------------------------------------------------------------------------------------------------
-- Flow animations
------------------------------------------------------------------------------------------------------------------------

-- start new animation -------------------------------------------------------------------------------------------------

local Animation = {}

local animationMeta = { 
    __index = Animation,
 }

function Flow:new(target, params, _level)
    params = params or {}
    _level = _level or 3

    assert(_level, type(target) == "table", "Arg[1] is not a valid target")
    assert(_level, type(params) == "table", "Arg[2] is not a params table")

    local flow = setmetatable({
        id              = getTargetName(target),
        target          = target,
        kind            = self._kind,
        defaultTime     = params.time or 1000,
        defaultDelay    = params.delay or 0,
        defaultEase     = getEase(params.ease, _level+1) or easing.linear,
        defaultIterations = params.iterations or 1,
        defaultBounce   = params.bounce or false,
        onCancel        = params.onCancel,
        onComplete      = params.onComplete,
        onUpdate        = params.onUpdate,

        timeScale       = 1,

        __parent        = self,
        __queue         = {},
        __prevTime      = system.getTimer(),
        __pausedTransitions = {},
    }, animationMeta)

    self._children[flow] = true
    
    return flow
end

-- animation lifecycle -------------------------------------------------------------------------------------------------

function Animation:__subscribe()
    if self._subscribed then return end
    self._subscribed = true

    if self.kind == "scene" then
        Runtime:addEventListener("enterFrame", self)
    end
end

function Animation:__unsubscribe()
    if not self._subscribed then return end
    self._subscribed = false

    if self.kind == "scene" then
        Runtime:removeEventListener("enterFrame", self)
    end
end

function Animation:tick()
    self:__update()
end

function Animation:enterFrame()
    self:__update()
end

function Animation:__update()
    local time = system.getTimer()
    local timeElapsed = (time - self.__prevTime) * self.timeScale
    if self:step(timeElapsed) then
        self.__prevTime = time
    
    else -- all animations are completed
        if self.onComplete then
            self.onComplete(self.target)
        end

        if self.destroy then
            self:destroy()
        end
    end
end

function Animation:step(ms)
    local dir = ms >= 0 and 1 or -1

    local waiting = {}
    local pendingWait
    local onGoingAnimations = false

    for id, queue in pairs(self.__queue) do
        local index = queue.index or 1
        local q = queue[index]

        local deltaTime = ms

        onGoingAnimations = onGoingAnimations or q and deltaTime * dir > zero
        while q and deltaTime > zero and not self.__pausedTransitions[id] do
            local consumed = 0

            if dir == 1 then

                if q.isWait then
                    
                    if q.released then
                        index = index + 1
                        queue.index = index
                        q = queue[index]
                    
                    elseif not q.tag then

                        pendingWait = pendingWait or {}

                        pendingWait.time = pendingWait.time or q.time
                        waiting[id] = { wait = q, start = ms - deltaTime }

                    elseif q.tag  == id then

                        -- They are waiting for us!

                        local duration = q.duration or 0
                        q.timeElapsed = q.timeElapsed or 0

                        if duration < q.timeElapsed + deltaTime then

                            -- We are done waiting

                            consumed = duration - q.timeElapsed
                            
                            q.released = true
                            q.timeElapsed = q.duration
                            
                        else
                            -- We are still waiting
                            
                            consumed = deltaTime
                            
                            q.timeElapsed = q.timeElapsed + deltaTime

                        end
                        
                    else
                        consumed = deltaTime
                        waiting[id] = { wait = q, start = ms - deltaTime }
                        
                    end

                else
                    local dest = q.dest
                    local params = q.params

                    local target = params.target or self.target

                    if not q.timeElapsed then
                        q.delay       = getValue(params.delay) or self.defaultDelay
                        q.duration    = getValue(params.time) or self.defaultTime
                        q.timeElapsed = 0
                        q.src         = {}
                        q.dst         = {}
                        q.iterations  = 0
                        q.started     = false
                        for k, v in pairs(dest) do
                            q.src[k] = target[k]
                            q.dst[k] = getValue(v)
                        end
                    end

                    local delay = q.delay
                    local dt = q.timeElapsed + deltaTime - delay

                    if not q.started then

                        if dt >= 0 then

                            -- passed the delay ---

                            q.started = true
                            if params.onStart then
                                params.onStart()
                            end

                            consumed = delay - q.timeElapsed
                            q.timeElapsed = delay

                        else

                            -- still in delay ---

                            consumed = deltaTime
                            q.timeElapsed = q.timeElapsed + deltaTime

                        end


                    elseif dt >= q.duration then

                        -- Completed a cycle ---

                        q.iterations = q.iterations + 1

                        consumed = (q.duration + q.delay) - q.timeElapsed
                        q.timeElapsed = 0

                        if params.iterations > 0 and q.iterations >= params.iterations then

                            -- Completed all iterations ---

                            local dst = params.bounce and q.src or q.dst

                            for k, v in pairs(dst) do
                                target[k] = v
                            end

                            index = index + 1
                            queue.index = index
                            q = queue[index]

                            if params.onComplete then
                                params.onComplete()
                            end

                            if not self.destroy then
                                return
                            end
                            
                        else

                            -- Repeat ---

                            q.delay = 0 -- delay only on the first iteration

                            for k, v in pairs(dest) do
                                q.dst[k] = getValue(v)
                            end

                            if params.reset then
                                for k, v in pairs(q.src) do
                                    q.src[k] = target[k]
                                end
                            end

                            if params.onRepeat then
                                params.onRepeat()
                            end
                        end


                    else

                        -- In progress ---

                        local x = q.timeElapsed-delay

                        if params.bounce then
                            if x > q.duration * .5 then
                                x = q.duration - x
                            end
                            x = x * 2
                        end

                        local delta = params.ease(x, q.duration, 0, 1)
                        for k, v in pairs(q.src) do
                            target[k] = v + (q.dst[k] - v) * delta
                        end

                        consumed = deltaTime
                        q.timeElapsed = q.timeElapsed + deltaTime

                    end

                end

                deltaTime = deltaTime - consumed

            else

                -- TODO: handle on reverse


            end
        end
    end

    if self.onUpdate then
        self.onUpdate(self.target)
    end

    return onGoingAnimations
end

Animation.fastForward = Animation.step

local function resetEntry(queue)
    queue.delay = nil
    queue.duration = nil
    queue.timeElapsed = nil
    queue.src = nil
    queue.dst = nil
    queue.iterations = nil
    queue.started = nil
end

local function rewind(q, n)
    local newIndex = q.index > n and q.index - n or 1
    for i = q.index, newIndex, -1 do
        resetEntry(q)
    end
    q.index = newIndex
end

function Animation:rewind(n, tag)
    if tag then
        rewind(self.__queue[tag], n)
    else
        for _, q in pairs(self.__queue) do
            rewind(q, n)
        end
    end
end

function Animation:pause(tag)
    if tag then
        self.__pausedTransitions[tag] = true
    else
        self:__unsubscribe()
    end
end

function Animation:resume(tag)
    if tag then
        self.__pausedTransitions[tag] = nil
    else
        self.__prevTime = system.getTimer()
    end

    self:__subscribe()
end

function Animation:stop(tag)
    if tag then
        self.__queue[tag] = nil
    else
        if self.onCancel then
            self.onCancel(self.target)
        end
        
        if self.destroy then
            self:destroy()
        end
    end
end
Animation.cancel = Animation.stop

function Animation:destroy()
    self:__unsubscribe()
    self.__parent._children[self] = nil

    setmetatable(self, nil)
    for k, _ in pairs(self) do
        self[k] = nil
    end
end


-- transitions ---------------------------------------------------------------------------------------------------------

-- core
function Animation:__getPrev(target, id, vars)
    local res = {}
    local count = 0

    local q = self.__queue[id] or {}

    for i = #q, 1, -1 do
        local t = (q[i] or {})
        
        if t.dest then -- waits don't have dest
            local bounce = (t.params or {}).bounce or self.defaultBounce
            local dest = t.dest
            for j = 1, #vars do
                if not res[j] and dest[vars[j]] and not bounce then
                    res[j] = dest[vars[j]]
                    count = count + 1
                end
            end
            
            if count == #vars then
                break
            end
        end
    end
    
    for j = 1, #vars do
        res[j] = res[j] or target[vars[j]]
    end

    return unpack(res)
end

-- core
function Animation:__transition(id, dest, params)
    if not self._subscribed then
        self:__subscribe()
    end

    params = params or {}

    if not self.__queue[id] then
        self.__queue[id] = { self._lastWait }
    end

    if params.ease then
        params.ease = getEase(params.ease, 5)
    else
        params.ease = self.defaultEase
    end


    params.iterations = params.iterations or self.defaultIterations or 1
    params.bounce = params.bounce or self.defaultBounce

    local target = params.target or self.target

    for k, v in pairs(dest) do
        local tp = type(v)

        if tp == "table" then
            -- this is a random range

            assert(4, v[1], "Invalid range for %s", k)
            assert(4, v[2], "Invalid range for %s", k)

        else
            -- this is a fixed value

            assert(4, tp == "number", "%s is not a number", k)

        end

        assert(4, target[k], "Property %s not found in %s", k, self.id)
    end

    local t = {
        dest = dest,
        params = params
    }

    table.insert(self.__queue[id], t)
end


function Animation:x(x, params)
    self:__transition("x", { x = x }, params)

    return self
end

function Animation:y(y, params)
    self:__transition("y", { y = y }, params)

    return self
end

function Animation:position(x, y, params)
    self:__transition("position", { x = x, y = y }, params)

    return self
end

function Animation:move(dx, dy, params)
    params = params or {}
    -- you can omit dx or dy to move only in one direction

    local target = params.target or self.target
    local prevX, prevY = self:__getPrev(target, "position", {"x", "y"})
    if not prevX then
        prevX = self:__getPrev(target, "x", {"x"})
    end

    if not prevY then
        prevY = self:__getPrev(target, "y", {"y"})
    end

    self:__transition("position", { 
        x = getParam(dx, prevX, sum),
        y = getParam(dy, prevY, sum)
    }, params)

    return self
end

function Animation:size(width, height, params)
    self:__transition("size", { width = width, height = height }, params)

    return self
end

-- t:scale(scale, params)
-- t:scale(xScale, yScale, params)
function Animation:scale(xScale, yScale, params)
    if not yScale or type(yScale) == "table" and not yScale[1] then
        params = yScale
        yScale = xScale
    end
    self:__transition("scale", { xScale = xScale, yScale = yScale }, params)

    return self
end

function Animation:scaleBy(xScale, yScale, params)
    if not yScale or type(yScale) == "table" and not yScale[1] then
        params = yScale
        yScale = xScale
    end

    params = params or {}

    local target = params.target or self.target
    local prevScaleX = self:__getPrev(target, "scale", {"xScale"})
    local prevScaleY = self:__getPrev(target, "scale", {"yScale"})

    self:__transition("scale", { 
        xScale = getParam(xScale, prevScaleX, mult),
        yScale = getParam(yScale, prevScaleY, mult)
    }, params)

    return self
end

function Animation:rotate(angle, params)
    self:__transition("rotation", { rotation = angle }, params)

    return self
end

function Animation:rotateBy(angle, params)
    params = params or {}

    local target = params.target or self.target
    local prevRotation = self:__getPrev(target, "rotation", {"rotation"})

    assert(4, type(prevRotation) == "number", "Can not find a rotation property in: %s", self.id)

    self:__transition("rotation", { 
        rotation = getParam(angle, prevRotation, sum)
    }, params)

    return self
end

function Animation:anchor(x, y, params)
    self:__transition("anchor", { anchorX = x, anchorY = y }, params)

    return self
end

function Animation:alpha(alpha, params)
    self:__transition("alpha", { alpha = alpha }, params)

    return self
end


-- t:color(color, params)
-- t:color(r, g, b, params)
-- t:color(r, g, b, a, params)
function Animation:color(r, g, b, a, params)
    if type(r) == "table" and not b then
        params = g
        r, g, b, a = unpack(r)
    elseif type(a) == "table" and not a[1] then
        params = a
        a = nil
    end

    params = params or {}
    params.target = self.target.fill

    self:__transition("color", { r = r, g = g, b = b, a = a }, params)

    return self
end

function Animation:effect(dest, params)
    params = params or {}
    params.target = self.target.fill.effect
    
    self:__transition("fillEffect", dest, params)

    return self
end


-- Text ----------------------------------------------------------------------------------------------------------------

function Animation:fontSize(size, params)
    self:__transition("fontSize", { size = size }, params)

    return self
end


-- Path ----------------------------------------------------------------------------------------------------------------

function Animation:path(...)

    local vars = {}
    local params = {}
    local n = math.floor(#arg / 2)
    if #arg % 2 == 1 then
        params = arg[#arg]
    end

    for i = 1, n do
        vars["x" .. i] = arg[i*2-1]
        vars["y" .. i] = arg[i*2]
    end
    
    params.target = self.target.path or self.target
    
    self:__transition("path", vars, params)

    return self
end

function Animation:pathBy(dx1, dy1, dx2, dy2, dx3, dy3, dx4, dy4, params)
    params = params or {}
    params.target = self.target.path
    local prevX1, prevX2, prevX3, prevX4, prevY1, prevY2, prevY3, prevY4 = self:__getPrev(params.target, "path", {"x1", "x2", "x3", "x4", "y1", "y2", "y3", "y4"})

    self:__transition("path", {
        x1 = getParam(dx1, prevX1, sum),
        x2 = getParam(dx2, prevX2, sum),
        x3 = getParam(dx3, prevX3, sum),
        x4 = getParam(dx4, prevX4, sum),
        y1 = getParam(dy1, prevY1, sum),
        y2 = getParam(dy2, prevY2, sum),
        y3 = getParam(dy3, prevY3, sum),
        y4 = getParam(dy4, prevY4, sum),
    }, params)

    return self
end

function Animation:radius(radius, params)
    params = params or {}
    params.target = self.target.path

    self:__transition("radius", { radius = radius }, params)

    return self
end

function Animation:radiusBy(dr, params)
    params = params or {}
    params.target = self.target.path
    local prevRadius = self:__getPrev(params.target, "radius", {"radius"})

    self:__transition("radius", { radius = prevRadius + dr }, params)

    return self
end


-- Stroke --------------------------------------------------------------------------------------------------------------

function Animation:strokeWidth(width, params)
    self:__transition("strokeWidth", { strokeWidth = width }, params)

    return self
end

function Animation:strokeEffect(dest, params)
    params = params or {}
    params.target = self.target.stroke.effect

    self:__transition("strokeEffect", dest, params)

    return self
end


-- Mask ----------------------------------------------------------------------------------------------------------------

function Animation:maskX(x, params)
    self:__transition("maskX", { maskX = x }, params)

    return self
end

function Animation:maskY(y, params)
    self:__transition("maskY", { maskY = y }, params)

    return self
end

function Animation:maskPosition(x, y, params)
    self:__transition("maskPosition", { maskX = x, maskY = y }, params)

    return self
end

function Animation:maskMove(dx, dy, params)
    params = params or {}

    local target = params.target or self.target
    local prevMaskX, prevMaskY = self:__getPrev(target, "maskPosition", {"maskX, maskY"})
    prevMaskX = prevMaskX or target.maskX
    prevMaskY = prevMaskY or target.maskY

    self:__transition("maskPosition", {
        maskX = getParam(dx, prevMaskX, sum),
        maskY = getParam(dy, prevMaskY, sum)
    }, params)

    return self
end

function Animation:maskScale(xScale, yScale, params)
    if not yScale or type(yScale) == "table" and not yScale[1] then
        params = yScale
        yScale = xScale
    end

    self:__transition("scaleMask", {
        maskScaleX = xScale,
        maskScaleY = yScale
    }, params)

    return self
end

function Animation:maskScaleX(xScale, params)
    self:__transition("maskScaleX", { maskScaleX = xScale }, params)

    return self
end

function Animation:maskScaleY(yScale, params)
    self:__transition("maskScaleY", { maskScaleY = yScale }, params)

    return self
end

function Animation:maskScaleBy(xScale, yScale, params)
    params = params or {}

    local target = params.target or self.target
    local prevMaskScaleX, prevMaskScaleY = self:__getPrev(target, "maskScale", {"maskScaleX, maskScaleY"})

    self:__transition("maskScale", {
        maskScaleX = getParam(xScale, prevMaskScaleX, mult),
        maskScaleY = getParam(yScale, prevMaskScaleY, mult),
    }, params)

    return self
end

function Animation:maskRotate(angle, params)
    self:__transition("rotateMask", { maskRotation = angle }, params)

    return self
end

function Animation:maskRotateBy(angle, params)
    params = params or {}

    local target = params.target or self.target
    local prevMaskRotation = self:__getPrev(target, "maskRotation", {"maskRotation"})
    self:__transition("maskRotation", { maskRotation = getParam(angle, prevMaskRotation, sum) }, params)

    return self
end


-- Spine ---------------------------------------------------------------------------------------------------------------

function Animation:spineColor(r, g, b, a, params)
    assert(self.target.skeleton, "This is not a spine object")

    if type(r) == "table" and not b then
        params = g
        r, g, b, a = unpack(r)
    elseif type(a) == "table" and not a[1] then
        params = a
        a = nil
    end

    params = params or {}
    params.target = self.target.skeleton.color

    self:__transition("spineColor", { r = r, g = g, b = b, a = a }, params)

    return self
end


-- Composite Animations ------------------------------------------------------------------------------------------------

function Animation:shrink(params)
    params = params or {}

    params.ease = params.ease or "outQuad"
    local onComplete = params.onComplete or function() end
    params.onComplete = function()
        self.target.alpha = 0
        onComplete()
    end

    return self:scale(.01,.01, params)
end

function Animation:fadeIn(params)
    params = params or {}
    params.ease = params.ease or easing.outQuad
    self:__transition("alpha", { alpha = 1 }, params)

    return self
end

function Animation:fadeOut(params)
    params = params or {}
    params.ease = params.ease or easing.outQuad
    self:__transition("alpha", { alpha = 0 }, params)

    return self
end

function Animation:fadeOutAndRemove(params)
    self:fadeOut(params)
    self:destroyTarget()

    return self
end


function Animation:jiggle(params)
    params = params or {}

    local time       = params.time or self.defaultTime
    local target = params.target or self.target
    local center     = params.center or self:__getPrev(target, "rotation", {"rotation"})
    local angle      = (params.angle or 10)/2
    local iterations = params.iterations or 1
    iterations = iterations <= 0 and math.huge or iterations
    
    assert(3, type(center) == "number", "Can not find a rotation property in: %s", self.id)

    self:rotate(center + angle, { time = time / 2, ease = "outQuad", iterations = 1 })

    
    if iterations ~= 1 then
        local dir = 1
        if iterations % 2 == 0 then
            self:rotate(center - angle, { time = time, ease = "inOutQuad", iterations = 1 })
            dir = -1
            iterations = iterations - 1

        end

        if iterations > 2 then
            self:rotate(center - angle * dir, { time = time * 2, ease = "inOutQuad", bounce = true, iterations = (iterations-1)/2 })
        end
        
    end

    return self:rotate(center, { time = time/2, ease = "inQuad" })
end


-- Custom --------------------------------------------------------------------------------------------------------------

function Animation:custom(id, dest, params)
    assert(3, type(dest) == "table", "Arg[1] is not a valid destination table")

    self:__transition(id, dest, params)

    return self
end


-- actions --------------------------------------------------------------------------------------------------------------

function Animation:repeatIt(n, tag)
    n = n or 100
    local awaitData = { isWait = true, tag = tag, onComplete = function() self:rewind(n, tag) end }

    self._lastWait = awaitData

    for _, queue in pairs(self.__queue) do
        table.insert(queue, awaitData)
    end

    return self
end

function Animation:reverse()

    return self
end

function Animation:destroyTarget(onComplete)
    self:wait()
    self:call(function()
        self.target:removeSelf()
        if onComplete then
            onComplete()
        end
    end)

    return self
end


function Animation:call(func, delay)
    self.__queue.callbacks = self.__queue.callbacks or {}

    table.insert(self.__queue.callbacks, { 
        dest   = {},
        params = { onStart = func, delay = delay, time = 0 }
    })

    return self
end

-- lock all new transitions until we finish awaiting
-- t:wait(tag)
-- t:wait(time)
-- t:wait(tag, time)
function Animation:wait(tag, time)
    if type(tag) == "number" then
        time = tag
        tag = nil
    end

    local awaitData = { isWait = true, duration = time, tag = tag }

    self._lastWait = awaitData

    for _, queue in pairs(self.__queue) do
        table.insert(queue, awaitData)
    end

    return self
end

return Flow
