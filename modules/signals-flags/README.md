# signals-flags

Feature flags for the Signals framework.

## Overview

`signals-flags` defines Roblox Fast Flags used to gate experimental behavior across Signals packages. Flags are defined once in this package and consumed by other packages (e.g. `signals-react`) to switch between implementations at runtime.

## Adding Flags

Define new flags in `src/init.lua` using `game:DefineFastFlag`. Each flag is wrapped in `xpcall` so the module still loads outside of Roblox (the flag defaults to `true` in non-Roblox and/or non-priveledged environments).
