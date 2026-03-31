local Signals = require(script.Parent.Parent.Signals)
local createExplicitSignal = Signals.createSignal
local createExplicitComputed = Signals.createComputed
local createExplicitEffect = Signals.createEffect

export type getter<T> = (false | nil) -> T
export type setter<T> = Signals.setter<T>
export type update<T> = Signals.update<T>
export type equals<T> = Signals.equals<T>
export type dispose = Signals.dispose

type scope = Signals.scope

local CurrentScope: scope? = nil

local function handleError(ok: boolean, ...)
	if not ok then
		local err = (...)
		error(err)
	end
end

local function handleResult<Ts...>(previousScope: scope?, ok: boolean, ...: Ts...): Ts...
	CurrentScope = previousScope
	handleError(ok, ...)
	return ...
end

local function createImplicitScopeFn<Ts...>(fn: () -> Ts...)
	local function wrappedFn(scope: scope): Ts...
		local previousScope: scope? = CurrentScope
		CurrentScope = scope
		return handleResult(previousScope, pcall(fn))
	end
	return wrappedFn
end

local function createImplicitGetter<T>(getter: Signals.getter<T>): getter<T>
	local function implicitGetter(untrack: false | nil): T
		return getter(if untrack == false then false else CurrentScope)
	end
	return implicitGetter
end

local function createSignal<T>(initial: (() -> T) | T, equals: equals<T>?): (getter<T>, setter<T>)
	local getter, setter = createExplicitSignal(initial, equals)
	local implicitGetter = createImplicitGetter(getter)
	return implicitGetter, setter
end

local function createComputed<T>(computed: () -> T, equals: equals<T>?): getter<T>
	local implicitComputed = createImplicitScopeFn(computed)
	local getter = createExplicitComputed(implicitComputed, equals)
	local implicitGetter = createImplicitGetter(getter)
	return implicitGetter
end

local function createEffect(effect: () -> ()): dispose
	local implicitEffect = createImplicitScopeFn(effect)
	return createExplicitEffect(implicitEffect)
end

return {
	createSignal = createSignal,
	createComputed = createComputed,
	createEffect = createEffect,
}
