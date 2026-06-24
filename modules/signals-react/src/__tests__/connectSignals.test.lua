local Root = script:FindFirstAncestor("SignalsReact")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local describe = JestGlobals.describe
local ReactRoblox = require(Packages.Dev.ReactRoblox)

local React = require(Packages.React)

local Signals = require(Packages.Signals)
local createSignal = Signals.createSignal

local connectSignals = require(script.Parent.Parent.connectSignals)
local useSignalState = require(script.Parent.Parent.useSignalState)

-- Builds a connected child under a parent that re-renders whenever `getParentTick`
-- changes, while always passing the child a shallow-equal own-prop table. Render
-- counts are tracked by recording the child's `value` prop each render.
local function setup()
	local getValue, setValue = createSignal("a")
	local getParentTick, setParentTick = createSignal(0)

	local rendered: { string } = {}

	local Child = connectSignals(function(scope)
		return { value = getValue(scope) }
	end)(function(props: { value: string, label: string })
		table.insert(rendered, props.value)
	end)

	local function Parent()
		useSignalState(getParentTick)
		return React.createElement(Child, { label = "const" })
	end

	local container = Instance.new("Folder")
	local root = ReactRoblox.createRoot(container)

	ReactRoblox.act(function()
		root:render(React.createElement(Parent))
	end)

	return {
		rendered = rendered,
		setValue = setValue,
		setParentTick = setParentTick,
		cleanup = function()
			root:unmount()
			container:Destroy()
		end,
	}
end

describe("connectSignals", function()
	it("re-renders when a tracked signal changes the derived props", function()
		local h = setup()

		local before = #h.rendered
		ReactRoblox.act(function()
			h.setValue("b")
			task.wait()
		end)

		expect(#h.rendered).toBeGreaterThan(before)
		expect(h.rendered[#h.rendered]).toEqual("b")

		h.cleanup()
	end)

	it("bails when the parent re-renders with shallow-equal own-props", function()
		local h = setup()

		-- Parent re-renders, but the child's own-props are shallow-equal and its
		-- tracked signal is unchanged -> React.memo bails, child does not re-render.
		local before = #h.rendered
		ReactRoblox.act(function()
			h.setParentTick(1)
			task.wait()
		end)

		expect(#h.rendered).toEqual(before)

		h.cleanup()
	end)

	it("bails when a tracked signal ticks to the same value", function()
		local h = setup()

		ReactRoblox.act(function()
			h.setValue("b")
			task.wait()
		end)

		-- Same value again -> derived props are shallow-equal, the computed keeps the
		-- previous reference, child does not re-render.
		local before = #h.rendered
		ReactRoblox.act(function()
			h.setValue("b")
			task.wait()
		end)

		expect(#h.rendered).toEqual(before)

		h.cleanup()
	end)

	it("a connected child bails on a parent re-render where a plain child does not", function()
		-- Read by both children but never changed, so the only re-render trigger in
		-- this test is the parent re-rendering.
		local getValue = createSignal("x")
		local getParentTick, setParentTick = createSignal(0)

		local connectedRenders = 0
		local plainRenders = 0

		local Connected = connectSignals(function(scope)
			return { value = getValue(scope) }
		end)(function()
			connectedRenders += 1
		end)

		-- The pre-connectSignals pattern: a function component that reads a signal via
		-- useSignalState but has no memo boundary, so it re-renders whenever its parent does.
		local function Plain()
			useSignalState(getValue)
			plainRenders += 1
		end

		local function Parent()
			useSignalState(getParentTick)
			return React.createElement("Folder", nil, {
				Connected = React.createElement(Connected, { label = "const" }),
				Plain = React.createElement(Plain, { label = "const" }),
			})
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(Parent))
		end)

		local connectedBefore = connectedRenders
		local plainBefore = plainRenders

		ReactRoblox.act(function()
			setParentTick(1)
			task.wait()
		end)

		expect(plainRenders).toBeGreaterThan(plainBefore)
		expect(connectedRenders).toEqual(connectedBefore)

		root:unmount()
		container:Destroy()
	end)
end)
