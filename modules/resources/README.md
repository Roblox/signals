# resources

Primitives for managing owned, disposable resources in Luau.

## Overview

`resources` provides a structured way to create values that have associated cleanup logic. A resource factory function receives an `own` helper that tracks child disposables, and returns a `dispose` function along with the produced values. When `dispose` is called, all owned children are torn down in reverse order.

## API Reference

### createResource

Creates a disposable resource with automatic ownership tracking.

```luau
function createResource<T...>(resourceFn: (own) -> T...): (dispose, T...)
```

#### Parameters

- **resourceFn**: A factory function that receives an `own` helper and returns one or more values. Use `own` to register child disposables that should be cleaned up when the resource is disposed.

#### Returns

A tuple of `(dispose, T...)`:
- **dispose**: `() -> ()` — Tears down the resource and all owned children in reverse registration order. Safe to call multiple times (only the first call has effect).
- **T...**: The values returned by `resourceFn`.

If `resourceFn` throws, all already-registered children are disposed before the error propagates.

#### Example

```luau
local Resources = require(Packages.Resources)
local createResource = Resources.createResource

local dispose, connection = createResource(function(own)
    local conn = RunService.Heartbeat:Connect(function(dt)
        print("tick", dt)
    end)
    own(function()
        conn:Disconnect()
    end)
    return conn
end)

-- Later, clean up:
dispose()
```

#### Nested resources

Child resources can be composed using `own`, which passes through return values:

```luau
local dispose, value = createResource(function(own)
    local inner = own(createResource(function(_)
        return "inner"
    end))
    return "outer-" .. inner
end)

print(value) -- "outer-inner"
dispose()    -- Disposes outer, then inner
```

---

### createCachedResource

Wraps a zero-argument resource factory with reference-counted caching. The underlying resource is constructed on the first call and shared across all callers. It is only disposed once every caller has released their reference.

```luau
function createCachedResource<T>(resource: resource<(), (T)>): resource<(), (T)>
```

#### Parameters

- **resource**: A zero-argument resource factory (a function that returns `(dispose, T)`).

#### Returns

A new resource factory with the same signature. Each call increments an internal reference count and returns a per-caller `dispose` function. The underlying resource is constructed lazily on the first call and reused for subsequent calls. When all callers have disposed, the underlying resource is torn down and will be reconstructed on the next call.

#### Example

```luau
local Resources = require(Packages.Resources)
local createResource = Resources.createResource
local createCachedResource = Resources.createCachedResource

local sharedConfig = createCachedResource(function()
    return createResource(function(own)
        local data = HttpService:JSONDecode(readConfigFile())
        own(function()
            print("Config released")
        end)
        return data
    end)
end)

-- Multiple consumers share the same instance
local dispose1, config = sharedConfig()
local dispose2, config = sharedConfig() -- Same object, no reconstruction

dispose1()  -- Config still alive (one reference remaining)
dispose2()  -- Now fully disposed, prints "Config released"
```

## Types

```luau
type own = <T...>(dispose, T...) -> T...
type dispose = () -> ()
type resource<A..., R...> = (A...) -> (dispose, R...)
```
