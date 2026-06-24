local Packages = script.Parent.Parent
local React = require(Packages.React)
local Signals = require(Packages.Signals)

local useSignalState = require(script.Parent.useSignalState)

--[[
	connectSignals(mapSignalsToProps)(Component)

	Connects a component to Signals state with correct re-render semantics. A plain function
	component that reads signals re-renders on TWO triggers: (a) a signal it reads changes, or
	(b) its parent re-renders (React re-invokes every child by default). connectSignals keeps (a)
	and eliminates the wasteful part of (b), by combining three things:

	  1. SUBSCRIBE   — runs `mapSignalsToProps(scope)`, auto-tracking whatever getters it reads,
	                   and re-renders the component when those tracked values change.
	  2. DERIVE+BAIL — wraps the mapping in `createComputed(..., shallowEqual)`, so when signals
	                   tick but the derived props are shallow-equal, the computed keeps the previous
	                   table reference and suppresses the update (no re-render, stable reference).
	  3. BOUNDARY    — wraps the component in `React.memo`, so when a parent re-renders with
	                   shallow-equal own-props, React skips this component and its entire subtree.
	                   The subscription alone cannot do this: a function component re-renders
	                   whenever its parent does, regardless of its signals.

	Net behavior: the component re-renders only when its derived signal props change OR its own
	props change — never merely because an ancestor re-rendered with unchanged props.

	`mapSignalsToProps`: (scope) -> { [string]: any }
	  - Read getters via `getter(scope)` so the computed tracks them.
	  - Return DERIVED STATE only. Do not create callbacks/functions here: the mapping re-runs on
	    every signal change, so a fresh function each run defeats the shallow-equal bail. Create
	    stable callbacks once (outside) and pass them as own-props instead.
	  - Reads signals only, not own-props. Own-props are merged in afterward and take precedence on
	    key collisions.

	Usage:
	  local connectSignals = require(Packages.SignalsReact).connectSignals
	  local View = connectSignals(function(scope)
	      return { pageName = getCurrentPageName(scope), isVisible = getIsVisible(scope) }
	  end)(function(props) ... end)
]]

local function shallowEqual(a: { [any]: any }, b: { [any]: any }): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

type MapSignalsToProps = (scope: Signals.scope) -> { [string]: any }

local function connectSignals(mapSignalsToProps: MapSignalsToProps)
	return function<P>(component: React.ComponentType<P>): React.ComponentType<P>
		local function Connected(ownProps: P)
			-- (2) derive+bail: per-mount computed, shallow-equal so signal noise that
			-- doesn't change the derived props neither re-renders nor changes the reference.
			local signalPropsGetter = React.useMemo(function()
				return Signals.createComputed(function(scope)
					return mapSignalsToProps(scope)
				end, shallowEqual)
			end, {})

			-- (1) subscribe: re-renders ONLY when the computed actually changes.
			local signalProps = useSignalState(signalPropsGetter)

			local merged: { [string]: any } = table.clone(signalProps :: any)
			for key, value in ownProps :: any do
				merged[key] = value
			end

			return React.createElement(component, merged :: any)
		end

		-- (3) boundary: bail parent->child cascades on shallow-equal ownProps.
		return React.memo(Connected) :: any
	end
end

return connectSignals
