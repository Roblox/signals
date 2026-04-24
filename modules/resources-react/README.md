# resources-react

React hooks for consuming disposable resources within component lifecycles.

## Overview

`resources-react` bridges the `resources` package with React, automatically constructing resources when a component mounts and disposing them on unmount. When the resource identity changes, the previous resource is disposed and a new one is created.

## API Reference

### useResource

Binds a resource's lifecycle to the calling component.

```luau
function useResource<T>(resource: resource<(), (T)>): T?
```

#### Parameters

- **resource**: A zero-argument resource factory (a function that returns `(dispose, T)`).

#### Returns

- The value produced by the resource, or `nil` before the resource has been constructed and after it has been disposed.

#### Behavior

- The resource is constructed during a layout effect and disposed when the component unmounts.
- If a different `resource` function is passed on a subsequent render, the previous resource is disposed and the new one is constructed.
- If the same `resource` reference is passed across re-renders, it is **not** reconstructed.

#### Example

```luau
local React = require(Packages.React)
local Resources = require(Packages.Resources)
local ResourcesReact = require(Packages.ResourcesReact)
local createResource = Resources.createResource
local useResource = ResourcesReact.useResource

local function createDataStream()
    return createResource(function(own)
        local connection = DataSource:Subscribe()
        own(function()
            connection:Disconnect()
        end)
        return connection
    end)
end

local function StreamViewer()
    local stream = useResource(createDataStream)

    if stream == nil then
        return nil
    end

    return React.createElement("TextLabel", {
        Text = stream:GetLatestValue(),
    })
end
```

#### Combining with createCachedResource

Use `createCachedResource` to share a single resource instance across multiple components:

```luau
local Resources = require(Packages.Resources)
local createCachedResource = Resources.createCachedResource

local sharedResource = createCachedResource(createDataStream)

local function ComponentA()
    local stream = useResource(sharedResource)
    -- ...
end

local function ComponentB()
    local stream = useResource(sharedResource)
    -- Same underlying instance as ComponentA
end
```
