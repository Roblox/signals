# signals-implicit-scope

Implicit scope API for Signals that eliminates the need to pass `scope` parameters explicitly.

## Overview

`signals-implicit-scope` provides an alternative API to core Signals that uses implicit scoping. Instead of passing `scope` to every getter, the scope is automatically managed in the background. This package serves as a reference implementation and mirrors the core Signals API.

**Explicit Scope (core Signals):**
```luau
local Signals = require(Packages.Signals)

local getName, setName = Signals.createSignal("Alice")

Signals.createEffect(function(scope)
    print(getName(scope)) -- Must pass scope explicitly
end)
```

**Implicit Scope (this package):**
```luau
local SignalsImplicitScope = require(Packages.SignalsImplicitScope)

local getName, setName = SignalsImplicitScope.createSignal("Alice")

SignalsImplicitScope.createEffect(function()
    print(getName()) -- Scope is implicit
end)
```

## API Reference

The API mirrors core Signals with one key difference: computed and effect callbacks don't receive a `scope` parameter, and getters don't require `scope` to track dependencies. Pass `false` to a getter to explicitly opt out of tracking.

### createSignal

```luau
function createSignal<T>(
    initial: (() -> T) | T,
    equals: equals<T>?
): (getter<T>, setter<T>)
```

Same as core `createSignal`. Getters use implicit scope when called with `nil` or no argument. Pass `false` to opt out of tracking.

### createComputed

```luau
function createComputed<T>(
    computed: () -> T,
    equals: equals<T>?
): getter<T>
```

Same as core `createComputed`, but the callback receives no `scope` parameter. Dependencies are tracked automatically when signals are read.

### createEffect

```luau
function createEffect(
    effect: () -> ()
): dispose
```

Same as core `createEffect`, but the callback receives no `scope` parameter. Dependencies are tracked automatically when signals are read.

## Example

```luau
local SignalsImplicitScope = require(Packages.SignalsImplicitScope)

local getFirstName, setFirstName = SignalsImplicitScope.createSignal("John")
local getLastName, setLastName = SignalsImplicitScope.createSignal("Doe")

local getFullName = SignalsImplicitScope.createComputed(function()
    return `{getFirstName()} {getLastName()}`
end)

local dispose = SignalsImplicitScope.createEffect(function()
    print(`Name: {getFullName()}`)
end)
-- Prints: Name: John Doe

setFirstName("Jane")
-- Prints: Name: Jane Doe

dispose()
```
