# signals-react

React hooks for integrating Signals with React components.

## Overview

`signals-react` provides React hooks that bridge Signals' reactive system with React's component model. These hooks enable React components to automatically re-render when signal values change.

## API Reference

### useSignalState

Subscribe a React component to a signal, causing re-renders when the signal changes.

```luau
function useSignalState<T>(getter: getter<T>): T
```

#### Parameters

- **getter**: A signal getter from `createSignal` or `createComputed`

#### Returns

- The current value of the signal

Subscribes the component to the signal and automatically cleans up on unmount.

#### Example

```luau
local React = require(Packages.React)
local Signals = require(Packages.Signals)
local SignalsReact = require(Packages.SignalsReact)

local useSignalState = SignalsReact.useSignalState

local getCount, setCount = Signals.createSignal(0)

local function Counter()
    local count = useSignalState(getCount)
    
    return React.createElement("Frame", {
        Size = UDim2.fromOffset(200, 100),
    }, {
        Label = React.createElement("TextLabel", {
            Text = `Count: {count}`,
            Size = UDim2.new(1, 0, 0.5, 0),
        }),
        
        Button = React.createElement("TextButton", {
            Text = "Increment",
            Size = UDim2.new(1, 0, 0.5, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            [React.Event.Activated] = function()
                setCount(function(prev) return prev + 1 end)
            end,
        }),
    })
end
```

---

### useSignalBinding

Convert a signal into a React binding for use with Roblox instance properties. Prefer this over `useSignalState` when a property accepts bindings, as it updates without causing a component re-render.

```luau
function useSignalBinding<T>(getter: getter<T>): Binding<T>
```

#### Parameters

- **getter**: A signal getter from `createSignal` or `createComputed`

#### Returns

- A React `Binding<T>` that updates when the signal changes

#### Example

```luau
local React = require(Packages.React)
local Signals = require(Packages.Signals)
local SignalsReact = require(Packages.SignalsReact)

local useSignalBinding = SignalsReact.useSignalBinding

local getOpacity, setOpacity = Signals.createSignal(1)

local function FadingFrame()
    local opacityBinding = useSignalBinding(getOpacity)
    
    return React.createElement("Frame", {
        Size = UDim2.fromOffset(100, 100),
        BackgroundTransparency = opacityBinding, -- Updates without re-render
    })
end
```

## Best Practices

**Create signals outside components** to persist across renders:

```luau
-- Good: Signal created outside component
local getCount, setCount = Signals.createSignal(0)

local function Counter()
    local count = useSignalState(getCount)
    return React.createElement("TextLabel", { Text = count })
end
```

**Use computeds for derived state** before passing to React:

```luau
local getColor = Signals.createComputed(function(scope)
    local health = getHealth(scope)
    if health > 75 then return Color3.new(0, 1, 0)
    elseif health > 25 then return Color3.new(1, 1, 0)
    else return Color3.new(1, 0, 0) end
end)

local function HealthBar()
    local color = useSignalBinding(getColor)
    return React.createElement("Frame", { BackgroundColor3 = color })
end
```

**Only subscribe to what you need** to minimize re-renders:

```luau
-- Good: Only re-renders on name change
local function PlayerName()
    local name = useSignalState(getName)
    return React.createElement("TextLabel", { Text = name })
end
```
