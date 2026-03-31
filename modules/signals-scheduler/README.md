# signals-scheduler

Low-level scheduling utilities for batching and managing reactive updates.

## Overview

`signals-scheduler` provides the scheduling primitives that power Signals' reactivity. While typically used internally by other Signals packages, it can be used directly for advanced use cases requiring control over update batching and scheduling.

For most use cases, prefer `SignalsExperimental.batch()` over using this package directly.

## How It Works

When multiple signals change, effects should ideally run only once after all changes complete. The scheduler manages this by batching updates:

1. Signal changes notify observers (effects)
2. Effects are scheduled (added to a continuation queue)
3. Queue is processed at the end of the batch
4. Effects run and see consistent state

## API Reference

### batch

Batches multiple operations into a single update cycle.

```luau
function batch(fn: () -> ()): ()
```

Executes `fn` immediately, collects all scheduled work during execution, then runs it after `fn` completes. Nested `batch` calls are automatically merged.

> **Note**: Batches don't cross async boundaries. Only synchronous updates within the batch are grouped.

#### Example

```luau
local Signals = require(Packages.Signals)
local SignalsScheduler = require(Packages.SignalsScheduler)

local getA, setA = Signals.createSignal(1)
local getB, setB = Signals.createSignal(2)

Signals.createEffect(function(scope)
    print(`A: {getA(scope)}, B: {getB(scope)}`)
end)

SignalsScheduler.batch(function()
    setA(10)
    setB(20)
end)
-- Prints: A: 10, B: 20 (once, not twice)
```

---

### flush

Flushes all pending scheduled work immediately.

```luau
function flush(): ()
```

---

### schedule

Schedules work to run after the current batch completes.

```luau
function schedule(work: () -> ()): ()
```

Adds `work` to the continuation queue.
