# signals

A minimal and scalable reactive state management framework for Luau.

## Overview

Signals provides fine-grained reactive primitives for building reactive systems. The core library consists of three fundamental primitives that enable automatic dependency tracking and efficient updates.

## Quick Start

```luau
local Signals = require(Packages.Signals)
local createSignal = Signals.createSignal
local createComputed = Signals.createComputed
local createEffect = Signals.createEffect

-- Create reactive state
local getFirstName, setFirstName = createSignal("David")
local getLastName, setLastName = createSignal("Tennant")

-- Create derived state
local getFullName = createComputed(function(scope)
    return `{getFirstName(scope)} {getLastName(scope)}`
end)

-- Create reactive side effects
local dispose = createEffect(function(scope)
    print(`Full name: {getFullName(scope)}`)
end)
-- Prints: Full name: David Tennant

-- Update state
setFirstName("Matt")
setLastName("Smith")
-- Prints: Full name: Matt Smith

-- Clean up
dispose()
```

## Core Concepts

### Reactive Graph

Signals builds a reactive dependency graph automatically:

1. **Signals** - Sources of reactive state
2. **Computeds** - Derived values from other reactive values
3. **Effects** - Side effects that re-run when dependencies change

### Automatic Dependency Tracking

Dependencies are tracked automatically when you pass `scope` to getters:

```luau
local getA, setA = createSignal(1)
local getB, setB = createSignal(2)

createEffect(function(scope)
    print(getA(scope) + getB(scope))
end)
-- Prints: 3

setA(5) -- Prints: 7
setB(10) -- Prints: 15
```

### Lazy Evaluation

Computeds are lazy - they only recalculate when read:

```luau
local getInput, setInput = createSignal(1)

local getExpensive = createComputed(function(scope)
    print("Computing...")
    return getInput(scope) * 2
end)

setInput(2) -- Doesn't print anything yet
setInput(3) -- Still doesn't print

print(getExpensive(false)) -- Prints "Computing..." (inside the computed), then prints 6
```

## API Reference

### createSignal

Creates a queryable and settable reactive value.

```luau
function createSignal<T>(
    initial: (() -> T) | T,
    equals: equals<T>?
): (getter<T>, setter<T>)
```

#### Parameters

- **initial**: Initial value or a function that returns the initial value (for lazy initialization)
- **equals** *(optional)*: Custom equality function to determine if the value changed. Defaults to `==`

#### Returns

A tuple of `(getter, setter)`:
- **getter**: `(scope | false | nil) -> T` - Function to read the current value
- **setter**: `(update<T>) -> ()` - Function to update the value

#### Type Definitions

```luau
type getter<T> = (scope | false | nil) -> T
type setter<T> = (update<T>) -> ()
type update<T> = ((previous: T) -> T) | T
type equals<T> = (current: T, incoming: T) -> boolean
```

#### Examples

```luau
local getCount, setCount = createSignal(0)

print(getCount(false)) -- 0

setCount(5)
print(getCount(false)) -- 5

-- Update based on previous value
setCount(function(prev) 
    return prev + 1 
end)
print(getCount(false)) -- 6
```

**Custom equality:**
```luau
local getPosition, setPosition = createSignal(
    Vector3.zero, 
    function(current, incoming)
        return (current - incoming).Magnitude < 0.01
    end
)

setPosition(Vector3.new(0, 0.005, 0)) -- Change too small, no notifications
setPosition(Vector3.new(0, 1, 0)) -- Significant change, observers notified
```

---

### createComputed

Creates a read-only reactive derived value.

```luau
function createComputed<T>(
    computed: (scope) -> T,
    equals: equals<T>?
): getter<T>
```

#### Parameters

- **computed**: A function that computes the derived value. Receives a `scope` parameter for tracking dependencies
- **equals** *(optional)*: Custom equality function to determine if the computed value changed. Defaults to `==`

#### Returns

- **getter**: `(scope | false | nil) -> T` - Function to read the computed value

#### Behavior

- **Lazy evaluation**: Only recalculates when the value is read
- **Automatic caching**: Caches result until dependencies change
- **Smart updates**: Only notifies observers if the computed value actually changes

#### Example

```luau
local getFirstName, setFirstName = createSignal("David")
local getLastName, setLastName = createSignal("Tennant")

local getFullName = createComputed(function(scope)
    return `{getFirstName(scope)} {getLastName(scope)}`
end)

print(getFullName(false)) -- "David Tennant"

setFirstName("Matt")
print(getFullName(false)) -- "Matt Tennant"
```

---

### createEffect

Creates a reactive side effect that automatically re-runs when dependencies change.

```luau
function createEffect(effect: (scope) -> ()): dispose
```

#### Parameters

- **effect**: A function containing the side effect. Receives a `scope` parameter for tracking dependencies

#### Returns

- **dispose**: `() -> ()` - Function to stop the effect and clean up

#### Behavior

- **Eager evaluation**: Runs immediately on creation
- **Automatic re-runs**: Re-executes whenever dependencies change
- **Automatic cleanup**: Old subscriptions are cleaned up before re-running
- **Batched updates**: Multiple changes within a batch only trigger one re-run

> **Important**: You MUST store a strong reference to the `dispose` function for the effect to be guaranteed to re-run. Not storing a strong reference means the effect is liable to be garbage collected.

#### Example

```luau
local getName, setName = createSignal("Alice")

local dispose = createEffect(function(scope)
    print("Hello,", getName(scope))
end)
-- Prints: Hello, Alice

setName("Bob")
-- Prints: Hello, Bob

dispose() -- Stop the effect
```

## Scope Parameter

The `scope` parameter enables automatic dependency tracking. When you pass `scope` to a getter inside an effect or computed, the reactive system registers a dependency on that signal. When the signal later changes, all registered dependents are scheduled to update.

```luau
local getValue, setValue = createSignal(10)

-- With scope: tracks dependency
createEffect(function(scope)
    print(getValue(scope)) -- This effect will re-run when value changes
end)

-- Without scope (false or nil): no tracking
createEffect(function(scope)
    print(getValue(false)) -- This effect will NEVER re-run
end)
```

Use `false` or `nil` when you want to "peek" at a value without subscribing to changes, or when reading values outside of reactive contexts.
