local Packages = script.Parent.Parent
local SignalsScheduler = require(Packages.SignalsScheduler)
local flush = SignalsScheduler.flush
local schedule = SignalsScheduler.schedule

local callUserSpace = require(script.Parent.callUserSpace)

export type getter<T> = (scope | false | nil) -> T
export type setter<T> = (update<T>) -> ()
export type update<T> = ((previous: T) -> T) | T
export type equals<T> = (current: T, incoming: T) -> boolean
export type dispose = () -> ()

-- The "scope" function is used by a source (signals and computeds) to register itself with
-- an observer (computeds and effects) when the source is read
export type scope = (source) -> observer

-- The "source" function is used by an observer to:
-- 1. Ask the source to update, then return its latest version
--		() -> number
-- 2. Rettach an observer to the source
--		(observer) -> ()
-- 3. Remove an observer from the source
--		(observer, true) -> ()
type source = (observer?, true?) -> number

-- The "observer" function is used by a source to notify the observer that one of its sources may be stale
type observer = () -> ()

--[[
	Diagnostics are configured by the host rather than compiled in, because what
	counts as a problem depends on the runtime driving these signals, and none of
	it should cost anything when it has not been asked for.
]]
export type Config = {
	-- Attaches a `debugState` table to each signal and computed, for an inspector to
	-- read. Off by default: it is an allocation per source.
	showInternals: boolean?,
	-- Reports a read that named no scope.
	warnScopelessReads: boolean?,
	-- Where a report goes. Defaults to `warn`.
	report: ((message: string) -> ())?,
}

local showInternals = false
local warnScopelessReads = false
local report: (message: string) -> () = function(message: string)
	warn(message)
end

local function configure(options: Config)
	if options.showInternals ~= nil then
		showInternals = options.showInternals
	end
	if options.warnScopelessReads ~= nil then
		warnScopelessReads = options.warnScopelessReads
	end
	if options.report ~= nil then
		report = options.report
	end
end

type set<T> = { [T]: true? }
local WeakSetMetatable = table.freeze({ __mode = "k" })
local function createWeakSet<T>(set: set<T>)
	return (setmetatable(set, WeakSetMetatable) :: unknown) :: set<T>
end

local function defaultEquals<T>(current: T, incoming: T)
	return current == incoming
end

--[[
	Reports a read that named no scope, so nothing re-runs when the value changes.

	Deduplicated by call site, because the reads worth finding are the ones inside
	an effect that runs constantly. `debug.traceback` is far too expensive to pay
	per read, which is why none of this happens unless it has been asked for.
]]
local reportedScopelessReads: { [string]: true } = {}

local function reportScopelessRead()
	local where = debug.traceback("", 3)
	if reportedScopelessReads[where] == nil then
		reportedScopelessReads[where] = true
		report(`Signals: a source was read without naming a scope, so nothing re-runs when it changes:{where}`)
	end
end

local function handleError(ok: boolean, ...)
	if not ok then
		local err = (...)
		error(err)
	end
end

local function handleScopeValidation<Ts...>(kill: () -> (), ok: boolean, ...: Ts...): Ts...
	kill()
	handleError(ok, ...)
	return ...
end

local function callUserSpaceWithScopeValidation<Ts...>(fn: (scope) -> Ts..., scope: scope): Ts...
	local isAlive = true

	local function wrappedScope(source: source)
		if not isAlive then
			error("attempted to use scope beyond scope's lifetime")
		end
		return scope(source)
	end

	local function kill()
		isAlive = false
	end

	return handleScopeValidation(kill, pcall(callUserSpace, fn, wrappedScope))
end

local validationEnabled = _G.__SIGNALS_VALIDATION_ENABLED__ or _G.__DEV__
local callUserSpaceWithScope = if validationEnabled then callUserSpaceWithScopeValidation else callUserSpace :: never

local function createSignal<T>(initial: (() -> T) | T, equals: equals<T>?, debugName: string?): (getter<T>, setter<T>)
	local isInitialized = false
	local version = 0

	local value: T
	local observers: set<observer>

	local isEqual: equals<T> = if equals ~= nil then equals else defaultEquals
	local debugState: any = if showInternals then { name = debugName, version = 0, value = initial } else nil

	local function ensureInitialized()
		if not isInitialized then
			isInitialized = true
			value = if typeof(initial) == "function" then callUserSpace(initial) else initial
			version = os.clock()
			observers = createWeakSet({})
			if debugState then
				debugState.version = version
				debugState.value = value
				debugState.observers = observers
			end
		end
	end

	local function source(childObserver: observer?, delete: true?)
		if childObserver ~= nil then
			if delete then
				observers[childObserver] = nil
			else
				observers[childObserver] = true
			end
			return 0
		else
			return version
		end
	end

	local function connectToScope(requestor: scope | false | nil)
		if requestor then
			local childObserver = requestor(source)
			observers[childObserver] = true
		elseif requestor == nil and warnScopelessReads then
			-- `false` is a deliberate untracked read. Omitting the argument entirely
			-- is the mistake worth reporting.
			reportScopelessRead()
		end
	end

	local function notifyObservers()
		for childObserver in observers do
			childObserver()
		end
		table.clear(observers)
	end

	local function getter(requestor: scope | false | nil): T
		ensureInitialized()
		connectToScope(requestor)
		return value
	end

	local function setter(update: update<T>)
		ensureInitialized()
		local newValue = if typeof(update) == "function" then callUserSpace(update, value) else update
		if not callUserSpace(isEqual, value, newValue) then
			value = newValue
			version = os.clock()
			if debugState then
				debugState.version = version
				debugState.value = value
			end
			notifyObservers()
			flush()
		end
	end

	return getter, setter
end

local function createComputed<T>(computed: (scope) -> T, equals: equals<T>?, debugName: string?): getter<T>
	local isInitialized = false
	local isStale = false
	local cachedVersion = 0
	local absoluteVersion = 0

	-- Naming a computed is far more common than giving it a comparison, so a string
	-- in the second position is taken as the name.
	if typeof(equals) == "string" then
		debugName = equals :: any
		equals = nil
	end

	local value: T
	local sources: set<source>
	local observers: set<observer>

	local isEqual: equals<T> = if equals ~= nil then equals else defaultEquals
	local debugState: any = if showInternals then { name = debugName, version = 0 } else nil

	local function notifyObservers()
		for childObserver in observers do
			childObserver()
		end
		table.clear(observers)
	end

	local function observer()
		if not isStale then
			isStale = true
			notifyObservers()
		end
	end

	local function scope(parentSource: source)
		sources[parentSource] = true
		return observer
	end

	local function ensureInitialized()
		if not isInitialized then
			isInitialized = true
			observers = createWeakSet({})
			sources = {}
			value = callUserSpaceWithScope(computed, scope)
			absoluteVersion = os.clock()
			cachedVersion = absoluteVersion
			if debugState then
				debugState.version = absoluteVersion
				debugState.value = value
			end
		end
	end

	local function disconnectSources()
		for parentSource in sources do
			parentSource(observer, true)
		end
		table.clear(sources)
	end

	local function flushNotifications()
		if isStale then
			isStale = false
			for parentSource in sources do
				local newVersion = parentSource()
				if newVersion > absoluteVersion then
					disconnectSources()
					local newValue = callUserSpaceWithScope(computed, scope)
					absoluteVersion = os.clock()
					if not callUserSpace(isEqual, value, newValue) then
						value = newValue
						cachedVersion = absoluteVersion
						if debugState then
							debugState.version = absoluteVersion
							debugState.value = value
						end
					end
					return
				end
			end
			for parentSource in sources do
				parentSource(observer)
			end
		end
	end

	local function source(childObserver: observer?, delete: true?)
		if childObserver ~= nil then
			if delete then
				observers[childObserver] = nil
			else
				observers[childObserver] = true
			end
			return 0
		else
			flushNotifications()
			return cachedVersion
		end
	end

	local function connectToScope(requestor: scope | false | nil)
		if requestor then
			local childObserver = requestor(source)
			observers[childObserver] = true
		elseif requestor == nil and warnScopelessReads then
			-- `false` is a deliberate untracked read. Omitting the argument entirely
			-- is the mistake worth reporting.
			reportScopelessRead()
		end
	end

	local function getter(requestor: scope | false | nil): T
		ensureInitialized()
		flushNotifications()
		connectToScope(requestor)
		return value
	end

	return getter
end

local function createEffect(effect: (scope) -> ()): dispose
	local isScheduled = false
	local isDisposed = false
	local version = 0

	local sources: set<source> = {}

	local observer: observer

	local function disconnectSources()
		for source in sources do
			source(observer, true)
		end
		table.clear(sources)
	end

	local function dispose()
		isDisposed = true
		disconnectSources()
	end

	local function scope(parentSource: source)
		sources[parentSource] = true
		return observer
	end

	local function processNotification()
		if not isDisposed then
			isScheduled = false
			for parentSource in sources do
				local newVersion = parentSource()
				if newVersion > version then
					disconnectSources()
					callUserSpaceWithScope(effect, scope)
					version = os.clock()
					return
				end
			end
			for parentSource in sources do
				parentSource(observer)
			end
		end
	end

	function observer()
		if not isDisposed then
			if not isScheduled then
				isScheduled = true
				schedule(processNotification)
			end
		end
	end

	callUserSpaceWithScope(effect, scope)
	version = os.clock()

	return dispose
end

return {
	createSignal = createSignal,
	createComputed = createComputed,
	createEffect = createEffect,

	configure = configure,
}
