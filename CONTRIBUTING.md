# Contributing to Signals

<!-- [![Open for community contributions, click to learn more](./.github/assets/open-for-community-contributions.svg)](#todo-devforum-post) -->

Thanks for your interest in contributing! This document covers how to set up the project locally, run checks, and submit changes.

## Ways to Contribute

- **Bug Reports:** Open a [GitHub Issue](https://github.com/Roblox/signals/issues/new) with a clear description and reproduction steps.
- **Feature Requests:** Open an issue with your idea and rationale.
- **Code Contributions:** Clone this repository, create a branch, and submit a PR (see below for PR guidelines).

## Repository Structure

The repository is a [Wally](https://wally.run/) workspace. Source code lives under `modules/`, with each package containing its own `src/` directory and tests at `src/__tests__/`.

```
modules/
  signals/              # Core reactive primitives
  signals-scheduler/    # Batch/flush micro-scheduler
  signals-react/        # React integration hooks
  signals-roblox/       # Roblox-specific bindings
  signals-experimental/ # Experimental utilities
  resources/            # Lifetime and scoping primitives
  resources-react/      # React hook for resources
```

Please only make modifications in the directories above. You may notice there are duplicate config files for some of our tooling (e.g. foreman.toml vs foreman-internal.toml, rotriever.toml vs wally.toml, default.project.json vs default.rbxp) as well as some internal specific files (e.g. .lestrc). Repo maintainers use these internal specific files to run the same tests on different tooling. If you want to add or modify any of the repo tooling or packages (e.g. updating foreman.toml or wally.toml), please open an issue and reach out to the maintainers for assistance.

> ![NOTE] You may notice that we depend on some packages (for example, Jest) which are still based on the legacy source-available mirroring process.
> We're in the process of upgrading our dependency graph so that we can more broadly accept Community Contributions throughout all of our dependencies.

## Code Guidelines

All CLI tools are installed via [Foreman](https://github.com/Roblox/foreman) (`foreman install`).

Contributions should follow existing code styling. In support of this, we use the following tools:

- All Luau code should be formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua) and pass [Selene](https://kampfkarren.github.io/selene/) linting.
- Static analysis uses [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp). The full type check can be run locally:

```bash
rojo sourcemap default.project.json -o sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages
wally-package-types --sourcemap sourcemap.json DevPackages
curl -sO https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/master/scripts/globalTypes.d.luau
luau-lsp analyze --defs globalTypes.d.luau --sourcemap sourcemap.json modules
```

Additionally:

1. Every functionality change should come with tests that express the desired behavior of the code being added.
2. Tests live in each module's `src/__tests__/` directory and run in CI via [rocale-cli](https://github.com/Roblox/rocale-cli). See the [rocale-cli repository](https://github.com/Roblox/rocale-cli) for instructions on setting up local test execution.
3. Small, incremental contributions are preferred over sweeping changes.

Running tests locally example
```bash
wally install
export ROBLOX_API_KEY="your generated OCALE api key"
rocale-cli run \
  	--placeId $ROBLOX_PLACE_ID \
  	--universeId $ROBLOX_UNIVERSE_ID \
  	--load.project default.project.json \
  	--script scripts/test.lua \
  	--lua.globals __DEV__=true,__ROACT_17_INLINE_ACT__=true,__ROACT_17_MOCK_SCHEDULER__=true \
  	--verbose
```

## Setting up a Fork

1. Create a fork of the repository using the Github UI
2. Generate an API key for OCALE (skip if you already have this)
	- Create a new experience
	- Go to your newly created experience, click on Places and get your universe and place ID
	- Navigate to the API Keys tab
	- Create a new API key with write access to your experience for `luau-execution-sessions` and `universe-places`
5. On your fork, add these secrets
   - `ROBLOX_API_KEY`
   - `TEST_PLACE_ID`
   - `TEST_UNIVERSE_ID`


## Pull Request Guidelines

When submitting a pull request:

1. Create a feature branch from `main`.
2. Ensure lint, format, and type checks pass before opening a PR.
3. Write a clear PR title that describes the change from a user's perspective.
4. All pull requests must pass the `analyze` and `test` CI workflows before merging.

## Licensing

By providing code in an issue or opening a pull request, you agree to license that code under the MIT License, and indicate that you have the legal right to do so.
