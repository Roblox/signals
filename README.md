# signals

[![ci](https://github.com/Roblox/signals/actions/workflows/ci.yml/badge.svg)](https://github.com/Roblox/signals/actions/workflows/ci.yml)
[![Get it on Creator Store](./.github/assets/link-creator-store.svg)](https://create.roblox.com/store/asset/71408264115531/Signals)
[![Contributions welcome](./.github/assets/link-contributions.svg)](CONTRIBUTING.md)
[![Wally (external link)](./.github/assets/link-wally.svg)](https://wally.run/package/roblox/signals)

Scalable and minimal reactive programming framework for [Luau](https://luau.org/).

## Overview

Signals provides fine-grained reactivity through a minimal set of primitives that automatically track dependencies and efficiently propagate updates. It enables building reactive systems where only the necessary computations re-run when data changes.

## Motivation

Those with limited experience in reactive programming may find [this article](https://dev.to/ryansolid/a-hands-on-introduction-to-fine-grained-reactivity-3ndf) helpful as a pre-read.

The initial motivation for this library originated with the desire for a performant state management solution. In particular, we sought to move from a global "Redux-like" state towards a distributed "fine-grained" state graph.

## Usage

The core API is very minimal, consisting of three core primitives:

### `createSignal`

```luau
createSignal<T>(initial: (() -> T) | T, equals: equals<T>?): (getter<T>, setter<T>)
```

Creates a queryable and settable value.

* Lazy-initializable with a constructor
* Cacheable with an optional `equals` parameter
* The getter can be provided a `scope` for automatic dependency tracking (see [createComputed](#createComputed) and [createEffect](#createEffect))

```luau
local getFirstName, setFirstName = createSignal("David")
local getLastName, setLastName = createSignal("Tennant")

print(getFirstName(false)) -- prints: David

setFirstName("The")
setLastName("Doctor")

print(`{getFirstName(false)} {getLastName(false)}`) -- prints: The Doctor
```

### `createComputed`

```luau
createComputed<T>(computed: (scope) -> T, equals: equals<T>?): getter<T>
```

Creates a read-only reactive derived value.

* Lazy evaluation (computed updates when value is read)
* Can be used to define "derived" state using signals and other computeds
* The `scope` can be used to automatically and reactively track updates to dependencies

```luau
local getFullName = createComputed(function(scope)
    return `{getFirstName(scope)} {getLastName(scope)}`
end)

print(getFullName(false)) -- prints: The Doctor
```

### `createEffect`

```luau
createEffect(effect: (scope) -> ()): dispose
```

Creates a reactive side effect.

* Eager evaluation
* The `scope` can be used to automatically and reactively track updates to dependencies

```luau
local dispose = createEffect(function(scope)
    print(`Their real name is {getFullName(scope)}`)
end)
-- prints: Their real name is The Doctor

batch(function()
    setFirstName("David")
    setLastName("Tennant")
end)
-- prints: Their real name is David Tennant

dispose()
```

> [!WARNING]
> You MUST store a strong reference to the `dispose` function returned from `createEffect` for the effect to be guaranteed to re-run. Not storing a strong reference to this function means the effect is liable to be garbage collected.

## Implementation

The reactive graph uses a pull-based lazy evaluation model with automatic dependency tracking via the `scope` mechanism. When a getter is called with a `scope`, the source registers itself with the observing computed or effect. Updates propagate through the graph and are coalesced via the scheduler to avoid redundant recomputation.

For more detail on the algorithms, see:
- [Reactive Algorithms](https://github.com/milomg/reactively/blob/main/Reactive-algorithms.md) (Reactively)
- [Monotonic Painting](https://fluff.blog/2024/04/16/monotonic-painting.html)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding standards, and how to submit changes.

## Acknowledgements

This library builds upon the existing work on [reactive programming](https://en.wikipedia.org/wiki/Reactive_programming), particularly drawing inspiration from [S.js](https://github.com/adamhaile/S), [Reactively](https://github.com/milomg/reactively), [Fusion](https://github.com/dphfox/Fusion), and [jotai](https://github.com/pmndrs/jotai).

## License

This project is licensed under the terms of the [MIT license](LICENSE).
