# signals-experimental

Experimental APIs and advanced patterns for Signals.

## Overview

`signals-experimental` provides experimental and advanced utilities that extend Signals with additional patterns. These APIs are less stable than core Signals but offer powerful abstractions for complex reactive scenarios.

> **Warning**: APIs in this package are experimental and may change in future versions.

## API Reference

### createProxy

Creates a reactive proxy that tracks individual properties as signals.

```luau
function createProxy<T>(initial: T): proxy<T>
```

#### Parameters

- **initial**: Initial table/object to create proxy from

#### Returns

- **proxy**: A reactive proxy object with special behavior

#### Type Definition

```luau
type proxy<T> = typeof(setmetatable({}, {} :: { 
    __call: (unknown, scope?) -> readonly<T> 
})) & T
```

The proxy has two modes:

- **Direct access (writable):** Access and modify properties directly (`proxy.key = value`). Individual properties are tracked as signals.
- **Called with scope (read-only):** Call with scope (`proxy(scope)`) to get a read-only reactive snapshot that tracks accessed properties as dependencies.

#### Example

```luau
local SignalsExperimental = require(Packages.SignalsExperimental)
local Signals = require(Packages.Signals)

local proxy = SignalsExperimental.createProxy({
    name = "Alice",
    score = 0
})

-- Direct writes
proxy.name = "Bob"
proxy.score = 100

-- Reactive reads
local dispose = Signals.createEffect(function(scope)
    local state = proxy(scope)
    print(`{state.name}: {state.score}`)
end)
-- Prints: Bob: 100

proxy.score = 200
-- Prints: Bob: 200

dispose()
```

Properties can be added dynamically (`proxy.newKey = value`) and removed by setting `nil`. Iterating over `proxy(scope)` in an effect tracks all properties.

---

### createReducer

Creates a computed value using a reducer pattern that accumulates state over time.

```luau
function createReducer<T>(
    reducer: (scope, previous: T) -> T,
    initial: (() -> T) | T
): getter<T>
```

#### Parameters

- **reducer**: Function that takes current state and returns new state, with access to `scope` for dependency tracking
- **initial**: Initial state value or function that returns initial state

#### Returns

- **getter**: Signal getter that returns the accumulated state

#### Example

```luau
local Signals = require(Packages.Signals)
local SignalsExperimental = require(Packages.SignalsExperimental)

local getValue, setValue = Signals.createSignal(1)

local getSum = SignalsExperimental.createReducer(function(scope, previous)
    return previous + getValue(scope)
end, 0)

print(getSum(false)) -- 1 (0 + 1)

setValue(5)
print(getSum(false)) -- 6 (1 + 5)

setValue(10)
print(getSum(false)) -- 16 (6 + 10)
```

---

### onDisposed

Registers a disposal callback that runs when an effect's scope is disposed.

```luau
function onDisposed(scope: scope, callback: () -> ()): ()
```

#### Parameters

- **scope**: The current scope (from effect or computed)
- **callback**: Callback to run when scope is disposed

Callbacks run when the effect re-runs or is finally disposed, in reverse order of registration.

#### Example

```luau
local Signals = require(Packages.Signals)
local SignalsExperimental = require(Packages.SignalsExperimental)

local getValue, setValue = Signals.createSignal(1)

local dispose = Signals.createEffect(function(scope)
    local value = getValue(scope)
    
    print(`Effect running with value: {value}`)
    
    SignalsExperimental.onDisposed(scope, function()
        print(`Cleaning up value: {value}`)
    end)
end)
-- Prints: Effect running with value: 1

setValue(2)
-- Prints: Cleaning up value: 1
-- Prints: Effect running with value: 2

dispose()
-- Prints: Cleaning up value: 2
```

---

### batch

Batches multiple signal updates into a single notification cycle.

```luau
function batch(fn: () -> ()): ()
```

#### Parameters

- **fn**: Function containing signal updates to batch

Groups multiple signal updates together so effects only run once after all updates complete. Nested batches are automatically merged.

#### Example

```luau
local SignalsExperimental = require(Packages.SignalsExperimental)
local Signals = require(Packages.Signals)

local getA, setA = Signals.createSignal(1)
local getB, setB = Signals.createSignal(2)

Signals.createEffect(function(scope)
    print(`A: {getA(scope)}, B: {getB(scope)}`)
end)
-- Prints: A: 1, B: 2

-- Without batch: two notifications
setA(10)
-- Prints: A: 10, B: 2
setB(20)
-- Prints: A: 10, B: 20

-- With batch: one notification
SignalsExperimental.batch(function()
    setA(100)
    setB(200)
end)
-- Prints: A: 100, B: 200 (only once)
```
