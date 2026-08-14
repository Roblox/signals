--[[
	This file carries the additions Blox made while it was running a copy of Signals,
	brought back here so there is one implementation rather than two. Each one is
	marked BLOX with the reason it exists, so a reviewer can take them separately.

	1. `peek(value)` reads without subscribing, by passing an explicit `false` scope,
	   and passes a plain value straight through. Callers that hold "a value or a
	   getter" do not have to find out which.
	2. `isGetter` / `isCallable`, so a caller can tell a reactive value from a plain
	   one. `isGetter` is only a function test: getters are plain functions here, and
	   an earlier attempt at making them callable tables to be certain cost an
	   allocation per signal for a question that is rarely load-bearing.
	3. `createEffect` takes an optional `scheduleWork`, so an effect can defer its
	   re-evaluation to a scheduler other than this one -- Blox hands it a frame
	   budget. When one is given the *first* run is deferred too, so mount work is
	   budgeted alongside every later re-run rather than jumping the queue.
	4. An effect body may return a cleanup function, run before the next evaluation
	   and again on disposal. signals-experimental has `onDisposed`, which is a
	   scope-registration trick rather than the ergonomic form.
	5. `debugName` on signals, computeds and effects, and an internals flag, so a
	   profiler or an inspector has something to name.
	6. `createInternalSource`, a signal whose setter notifies without flushing, for
	   values a runtime drives itself part-way through a pass of its own.
	7. Reporting for a read that named no scope. `false` says "do not subscribe" and
	   is honoured in silence; nothing at all subscribes nothing, which reads
	   correctly once and then never updates. That is the quietest failure here, so
	   it is worth being able to ask about it.

	Diagnostics reach this file through `setHooks` and `configure` rather than a
	direct dependency, so nothing here knows about the runtime using it.
]]

local Packages = script.Parent.Parent
local SignalsScheduler = require(Packages.SignalsScheduler)
local batch = SignalsScheduler.batch
local flush = SignalsScheduler.flush
local schedule = SignalsScheduler.schedule

local callUserSpace = require(script.Parent.callUserSpace)

export type getter<T> = (scope | false | nil) -> T
export type setter<T> = (update<T>) -> ()
export type update<T> = ((previous: T) -> T) | T
export type equals<T> = (current: T, incoming: T) -> boolean
export type dispose = () -> ()
export type work = () -> ()

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
	BLOX 5 and 7: diagnostics, supplied by the host rather than required.

	Bound as upvalues rather than read out of a table per call, so a hook that is not
	installed costs the same as it did when it was a constant.
]]
local function noop() end
local function noopReturningZero()
	return 0
end

export type Hooks = {
	onSignalSet: (() -> ())?,
	onSignalNotify: ((count: number) -> ())?,
	beginComputedEval: (() -> number)?,
	endComputedEval: ((startedAt: number) -> ())?,
	beginEffectRun: (() -> number)?,
	endEffectRun: ((startedAt: number, debugName: string?) -> ())?,
}

export type Config = {
	-- Attaches a `debugState` table to each signal and computed, for an inspector to
	-- read. Off by default: it is an allocation per source.
	showInternals: boolean?,
	-- Reports a read that named no scope. See BLOX 7.
	warnScopelessReads: boolean?,
	-- Where a report goes. Defaults to `warn`.
	report: ((message: string) -> ())?,
}

local onSignalSet: () -> () = noop
local onSignalNotify: (count: number) -> () = noop
local beginComputedEval: () -> number = noopReturningZero
local endComputedEval: (startedAt: number) -> () = noop
local beginEffectRun: () -> number = noopReturningZero
local endEffectRun: (startedAt: number, debugName: string?) -> () = noop

local function setHooks(hooks: Hooks?)
	local given: any = if hooks ~= nil then hooks else {}
	onSignalSet = given.onSignalSet or noop
	onSignalNotify = given.onSignalNotify or noop
	beginComputedEval = given.beginComputedEval or noopReturningZero
	endComputedEval = given.endComputedEval or noop
	beginEffectRun = given.beginEffectRun or noopReturningZero
	endEffectRun = given.endEffectRun or noop
end

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

-- BLOX 2: getters are plain functions, so this cannot tell a getter from any other
-- function. Callers rely on position rather than on the value's shape.
local function isGetter(value: any): boolean
	return type(value) == "function"
end

local function isCallable(value: any): boolean
	if type(value) == "function" then
		return true
	end
	if type(value) == "table" then
		local mt = getmetatable(value)
		return mt ~= nil and typeof(mt.__call) == "function"
	end
	return false
end

-- BLOX 1: reads without subscribing, whatever it is handed.
local function peek(value: any): any
	if type(value) == "function" then
		return value(false)
	end
	return value
end

--[[
	BLOX 7: reports a read that named no scope.

	Deduplicated by call site, because the reads that matter are the ones inside an
	effect that runs constantly. `debug.traceback` is far too expensive to pay per
	read, which is why none of this happens unless it has been asked for.
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

local function createSignal<T>(
	initial: (() -> T) | T,
	equals: equals<T>?,
	debugName: string?
): (getter<T>, setter<T>)
	local isInitialized = false
	local version = 0

	local value: any
	local observers: set<observer>

	local isEqual: equals<any> = if equals ~= nil then equals else defaultEquals
	local debugState: any = if showInternals then { name = debugName, version = 0, value = initial } else nil

	local function ensureInitialized()
		if not isInitialized then
			isInitialized = true
			-- BLOX 1: a getter as the initial value is peeked rather than stored, so
			-- `createSignal(someGetter)` seeds from it instead of nesting it.
			value = if isGetter(initial)
				then peek(initial)
				else if typeof(initial) == "function" then callUserSpace(initial :: any) else initial
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
			if childObserver ~= nil then
				observers[childObserver] = true
			end
		elseif requestor == nil and warnScopelessReads then
			reportScopelessRead()
		end
	end

	local function notifyObservers()
		local count = 0
		for childObserver in observers do
			childObserver()
			count += 1
		end
		onSignalNotify(count)
		table.clear(observers)
	end

	local function getter(requestor: scope | false | nil): any
		ensureInitialized()
		connectToScope(requestor)
		return value
	end

	local function setter(update: update<any>)
		ensureInitialized()
		-- BLOX 1: a getter as the update is peeked, matching the initial-value case.
		local newValue = if isGetter(update)
			then peek(update)
			elseif typeof(update) == "function" then callUserSpace(update :: any, value)
			else update
		if not callUserSpace(isEqual, value, newValue) then
			onSignalSet()
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

	return getter :: any, setter :: any
end

--[=[
	BLOX 6: a signal whose setter notifies without flushing.

	A runtime drives these itself -- a list row's index part-way through a reconcile --
	where flushing would run effects against a half-updated list. The notification
	still lands; it is drained by whatever batch encloses the pass.
]=]
local function createInternalSource(initial: any): (getter<any>, setter<any>)
	local version = os.clock()
	local value = initial
	local observers: set<observer> = createWeakSet({})

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

	local function getter(requestor: scope | false | nil): any
		if requestor then
			local childObserver = requestor(source)
			if childObserver ~= nil then
				observers[childObserver] = true
			end
		elseif requestor == nil and warnScopelessReads then
			reportScopelessRead()
		end
		return value
	end

	local function setter(newValue: any)
		if value ~= newValue then
			value = newValue
			version = os.clock()
			for childObserver in observers do
				childObserver()
			end
			table.clear(observers)
		end
	end

	return getter :: any, setter :: any
end

local function createComputed<T>(computed: (scope) -> T, equals: equals<T>?, debugName: string?): getter<T>
	local isInitialized = false
	local isStale = false
	local cachedVersion = 0
	local absoluteVersion = 0

	-- BLOX 5: naming a computed is the common reason to pass a second argument, so a
	-- string in the equals position is taken as the debug name.
	if typeof(equals) == "string" then
		debugName = equals :: any
		equals = nil
	end

	local value: any
	local sources: set<source>
	local observers: set<observer>

	local isEqual: equals<any> = if equals ~= nil then equals else defaultEquals
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

	local function evaluate(): any
		local startedAt = beginComputedEval()
		local result = callUserSpaceWithScope(computed, scope)
		endComputedEval(startedAt)
		return result
	end

	local function ensureInitialized()
		if not isInitialized then
			isInitialized = true
			observers = createWeakSet({})
			sources = {}
			value = evaluate()
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
					local newValue = evaluate()
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
			-- Nothing actually moved, so re-attach and keep the cached value.
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
			if childObserver ~= nil then
				observers[childObserver] = true
			end
		elseif requestor == nil and warnScopelessReads then
			reportScopelessRead()
		end
	end

	local function getter(requestor: scope | false | nil): any
		ensureInitialized()
		flushNotifications()
		connectToScope(requestor)
		return value
	end

	return getter :: any
end

local function createEffect(effect: (scope) -> (), scheduleWork: ((work) -> ())?, debugName: string?): dispose
	local isInitialized = false
	local isScheduled = false
	local isDisposed = false
	local version = 0
	local cleanup: (() -> ())? = nil

	local sources: set<source> = {}

	local observer: observer

	-- BLOX 4: cleanup returned from the body.
	local function runCleanup()
		if cleanup then
			local fn = cleanup
			cleanup = nil
			-- Swallowed so a bad cleanup cannot stop the effect re-running, but
			-- reported, because it is otherwise a completely silent failure.
			local ok, err = pcall(fn)
			if not ok then
				report(`Signals: effect cleanup error{if debugName then ` in '{debugName}'` else ""}: {err}`)
			end
		end
	end

	local function disconnectSources()
		for source in sources do
			source(observer, true)
		end
		table.clear(sources)
	end

	local function dispose()
		isDisposed = true
		runCleanup()
		disconnectSources()
	end

	local function scope(parentSource: source)
		sources[parentSource] = true
		return observer
	end

	local function runEffect()
		runCleanup()
		local startedAt = beginEffectRun()
		local result = callUserSpaceWithScope(effect, scope)
		endEffectRun(startedAt, debugName)
		if typeof(result) == "function" then
			cleanup = result
		end
	end

	local function processNotification()
		if isDisposed then
			return
		end
		isScheduled = false
		if not isInitialized then
			runEffect()
			version = os.clock()
			isInitialized = true
			return
		end
		for parentSource in sources do
			local newVersion = parentSource()
			if newVersion > version then
				disconnectSources()
				runEffect()
				version = os.clock()
				return
			end
		end
		-- Nothing moved, so re-attach and skip the body.
		for parentSource in sources do
			parentSource(observer)
		end
	end

	observer = function()
		if not isDisposed and not isScheduled then
			isScheduled = true
			-- BLOX 3: an external scheduler when one was given.
			if scheduleWork then
				scheduleWork(processNotification)
			else
				schedule(processNotification)
			end
		end
	end

	-- BLOX 3: with a scheduler the first run is deferred too, so mount work lands in
	-- the same budget as every later re-run.
	if scheduleWork then
		isScheduled = true
		scheduleWork(processNotification)
	else
		runEffect()
		version = os.clock()
		isInitialized = true
	end

	return dispose
end

return {
	createSignal = createSignal,
	createComputed = createComputed,
	createEffect = createEffect,

	createInternalSource = createInternalSource,
	isCallable = isCallable,
	isGetter = isGetter,
	peek = peek,

	-- Re-exported so a consumer that batches does not need a second dependency just
	-- to reach the scheduler this file already uses.
	batch = batch,
	flush = flush,
	schedule = schedule,

	setHooks = setHooks,
	configure = configure,
}
