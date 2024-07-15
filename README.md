# Flow for Solar2D

`Flow` is a comprehensive animation and task management library designed for Solar2D that simplifies the creation of complex, dynamic, and interactive animations. It integrates animations and task scheduling in a unified framework, allowing for fluid control over display objects and time-based actions.

## Features

- **Unified Animation and Task Management**: Manage both animations and scheduled tasks under a single framework for cohesive control.
- **Branching Animations**: Group related animations into branches for organized management and collective control.
- **Flexible Animation Controls**: Extensive set of animation functions for precise visual manipulations.
- **Task Scheduling**: Enhanced task scheduling with built-in pause, resume, and destroy capabilities.
- **Randomized and Dynamic Animations**: Support for dynamic properties, allowing for random and varied animations on each iteration.

## Installation

To use `Flow`, place the `Flow.lua` file in your project's directory.

In your Solar2D project, require the module where you need to use it:

```lua
_G.Flow = require("Flow")
```

## Usage

### Branching Animations

In `Flow`, a branch is a powerful feature that allows you to group and manage related animations together. This organizational tool is ideal for handling complex animation sequences across multiple objects or for managing animations that are logically grouped together.

#### Creating and Managing Branches

To create a new branch, simply call the `branch` method on an existing `Flow` instance. This new branch will inherit all the characteristics of the parent but can be controlled independently.

```lua
local mainFlow = Flow:branch()  -- Parent branch
local subFlow = mainFlow:branch()  -- Child branch
```

#### Nested Branching

Branches can be nested, meaning you can create branches from other branches. This is useful for complex scene management where different sections of your scene may need to animate independently.

```lua
local branchA = Flow:branch()
local branchB = branchA:branch()  -- Branch from another branch
```

#### Controlling Branches

When you control a branch (pause, resume, or cancel), all its child branches and their animations are also affected. This cascading control makes it easy to manage complex animations with minimal code.

```lua
branchA:pause()  -- Pauses branchA and branchB
branchA:resume()  -- Resumes animations in both branchA and branchB
branchA:cancel()  -- Cancels all ongoing animations in branchA and branchB
```

#### Cleaning Up

When you are done with a branch and no longer need its animations, use the `:destroy()` method. This will clean up all resources associated with that branch and its children, ensuring efficient memory management.

```lua
branchA:destroy()  -- Properly disposes of branchA and all its children
```

### Managing Tasks with Flow

`Flow` integrates task scheduling and animation into a single framework, simplifying the management of timed functions alongside animations. This integration is crucial for maintaining synchronization between animations and related tasks without the need to manage multiple systems.

#### Using `performWithDelay`

The `performWithDelay` method allows you to schedule functions to be executed after a specified delay. It's an enhanced version of Solar2D's standard timing functions, with the added benefit of being controllable through the Flow's branch system.

```lua
local flow = Flow:branch()
flow:performWithDelay(1000, function()
    print("This function runs after 1 second.")
end, 3)  -- The function will run 3 times at 1-second intervals.
```

#### Task Functions

Tasks within `Flow` can be manipulated using several methods to control their execution:

- **`fastForward(time)`**: Advances the task's timeline by the specified amount of milliseconds, which can be positive to move forward or negative to rewind.
- **`getProgress()`**: Returns the current progress of the task as a fraction (0 to 1).
- **`pause()`**: Pauses the task.
- **`resume()`**: Resumes a paused task.
- **`stop()`**: Stops the task and prevents any further execution.
- **`destroy()`**: Cleans up the task and removes it from the system.

#### Example: Controlling Tasks

Here is how you might integrate tasks with animations and manage them:

```lua
local flow = Flow:branch()

-- Scheduling a task
local task = flow:performWithDelay(500, function()
    print("Task executed.")
end, 5)

-- Manipulating a running task
task:fastForward(1500)  -- Advances the task by 1.5 seconds
print("Progress:", task:getProgress())  -- Outputs the progress of the task

-- Controlling the task execution
task:pause()
task:resume()
task:stop()
task:destroy()
```

### Creating and Managing Animations with Flow

`Flow` provides a versatile system for animating display objects in Solar2D, offering extensive control over animation properties and behaviors.

#### Initiating Animations

To start an animation, use `flow(target, defaultParams)` where `target` is the display object you want to animate, and `defaultParams` can include:

- **`ease`**: Type of easing function.
- **`time`**: Duration of the animation.
- **`delay`**: Time before the animation starts.
- **`bounce`**: Makes the animation go to the target, then return to the original state.
- **`iterations`**: Number of times the animation repeats.
- **`onComplete`**: Callback function when the animation completes.

#### Chaining Animations

After initiating an animation, you can chain multiple animation commands to create complex sequences:

```lua
flow(target, { time = 1000, ease = "linear", iterations = 2 })
    :scale({0.5, 1.5}, {0.5, 1.5})  -- Random scale each iteration
    :rotate(360)
    :position(100, 100)
    :wait("scale")  -- Waits for the scale animation to complete
    :alpha(0)  -- Fades out after scaling is done
```

#### Randomized Parameters

`Flow` allows for randomness within animation parameters, offering dynamic visual effects. Instead of specifying exact values, you can provide a range from which `Flow` will randomly select a value each iteration:

```lua
flow(target, { time = {500, 1500} })
    :scale({0.5, 1.5}, {0.5, 1.5})
    :color({0, 1}, {0, 1}, {0, 1})
```

#### Managing Animation Stacks

If you add the same type of transition multiple times, they will queue up:

```lua
flow(target)
    :scale(1.5) 
    :scale(0.5)
    :position(50, 50)
    :scale(2.0)  -- This will execute after all prior animations are complete
```

#### Controlling Flow with `wait`

You can synchronize animations by using `:wait()` to pause the sequence until a specific animation completes:

```lua
flow(target)
    :scale(1.5) 
    :scale(0.5)
    :wait("scale")
    :position(50, 50)  -- Starts only after all scaling is done
    :scale(2.0)
```

#### Comprehensive Animation Functions

`Flow` supports a wide range of animation functions to modify nearly every aspect of a display object:

- **Transformation**:
  - `x(x, params)`
  - `y(y, params)`
  - `position(x, y, params)`
  - `move(dx, dy, params)`
  - `size(width, height, params)`
  - `scale(xScale, yScale, params)`
  - `scaleBy(xScale, yScale, params)`
  - `rotate(angle, params)`
  - `rotateBy(angle, params)`
  - `anchor(x, y, params)`
  - `alpha(alpha, params)`

- **Color Manipulations**:
  - `color(color, params)`
  - `color(r, g, b, params)`
  - `color(r, g, b, a, params)`

- **Advanced Path and Effect Animations**:
  - `effect(dest, params)`
  - `fontSize(size, params)`
  - `path(x1, y1, x2, y2, ..., params)`
  - `pathBy(dx1, dy1, dx2, dy2, ..., params)`
  - `radius(radius, params)`
  - `radiusBy(dr, params)`
  - `strokeWidth(width, params)`
  - `strokeEffect(dest, params)`

- **Mask Animations**:
  - `maskX(x, params)`
  - `maskY(y, params)`
  - `maskPosition(x, y, params)`
  - `maskMove(dx, dy, params)`
  - `maskScale(xScale, yScale, params)`
  - `maskScaleX(xScale, params)`
  - `maskScaleY(yScale, params)`
  - `maskScaleBy(xScale, yScale, params)`
  - `maskRotate(angle, params)`
  - `maskRotateBy(angle, params)`

- **Spine Animations**:
  - `spineColor(color, params)`
  - `spineColor(r, g, b, params)`
  - `spineColor(r, g, b, a, params)`

- **Composite Animations**:
  - `shrink(params)`
  - `fadeIn(params)`
  - `fadeOut(params)`
  - `jiggle(params)`

Each function can be customized with parameters like `delay`, `time`, `iterations`, `ease`, `bounce`, `reset`, `onComplete`, `onStart`, `onRepeat`, and `onCancel` to precisely control the behavior and flow of animations.

### Example: Comprehensive Animation Sequence

```lua
local box = display.newRect(100, 100, 100, 100)
local myFlow = Flow:branch()

myFlow(box, { time = 2000, ease = "inQuad", onComplete = function() print("Animation complete!") end })
    :color({0, 1}, {0, 1}, {0, 1}, {time = 500, bounce = true})
    :scale({0.5, 1.5}, {0.5, 1.5}, {iterations = 5})
    :rotate(360, {ease = "inOutCubic"})
    :wait("scale")
    :move(150, 150, {time = 1000})
```
