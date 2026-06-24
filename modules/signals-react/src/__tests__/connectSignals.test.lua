local Root = script:FindFirstAncestor("SignalsReact")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local ReactRoblox = require(Packages.Dev.ReactRoblox)

local React = require(Packages.React)

local Signals = require(Packages.Signals)
local createSignal = Signals.createSignal

local connectSignals = require(script.Parent.Parent.connectSignals)
local useSignalState = require(script.Parent.Parent.useSignalState)

it("re-renders on derived-prop change, bails on parent re-render and no-op signal ticks", function()
	-- Drives the connected child's derived props.
	local getChildValue, setChildValue = createSignal("a")
	-- Drives ONLY the parent's re-render, never the child's props.
	local getParentTick, setParentTick = createSignal(0)

	local childRenders = 0
	local lastValue = nil
	local lastLabel = nil

	local Child = connectSignals(function(scope)
		return { value = getChildValue(scope) }
	end)(function(props: { value: string, label: string })
		childRenders += 1
		lastValue = props.value
		lastLabel = props.label
	end)

	-- Parent subscribes to getParentTick so it re-renders on tick, but always passes a
	-- shallow-equal own-prop table to Child.
	local function Parent()
		useSignalState(getParentTick)
		return React.createElement(Child, { label = "const" })
	end

	local container = Instance.new("Folder")
	local root = ReactRoblox.createRoot(container)

	ReactRoblox.act(function()
		root:render(React.createElement(Parent))
	end)

	expect(childRenders > 0).toEqual(true)
	expect(lastValue).toEqual("a")
	expect(lastLabel).toEqual("const")

	-- (3) BOUNDARY: parent re-renders, but Child own-props are shallow-equal and its signal
	-- is unchanged -> React.memo bails, Child does NOT re-render.
	local beforeParentTick = childRenders
	ReactRoblox.act(function()
		setParentTick(1)
		task.wait()
	end)
	expect(childRenders).toEqual(beforeParentTick)

	-- (1) SUBSCRIBE: a tracked signal changes the derived props -> Child re-renders.
	local beforeChange = childRenders
	ReactRoblox.act(function()
		setChildValue("b")
		task.wait()
	end)
	expect(childRenders > beforeChange).toEqual(true)
	expect(lastValue).toEqual("b")

	-- (2) DERIVE+BAIL: signal ticks to the SAME value -> derived props are shallow-equal,
	-- the computed keeps the previous reference, Child does NOT re-render.
	local beforeNoop = childRenders
	ReactRoblox.act(function()
		setChildValue("b")
		task.wait()
	end)
	expect(childRenders).toEqual(beforeNoop)

	root:unmount()
	container:Destroy()
end)
