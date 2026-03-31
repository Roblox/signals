local Root = script:FindFirstAncestor("SignalsReact")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local ReactRoblox = require(Packages.Dev.ReactRoblox)

local React = require(Packages.React)

local Signals = require(Packages.Signals)
local createSignal = Signals.createSignal
local createComputed = Signals.createComputed

local useSignalBinding = require(script.Parent.Parent.useSignalBinding)

it("should not re-render when the signal value changes", function()
	local renderCount = 0

	local getSignal, setSignal = createSignal("hello")

	local function mockComponent(props: { get: Signals.getter<string> })
		renderCount += 1
		local binding = useSignalBinding(props.get)
		return React.createElement("TextLabel", {
			Text = binding,
		})
	end

	local container = Instance.new("Folder")
	local root = ReactRoblox.createRoot(container)

	ReactRoblox.act(function()
		root:render(React.createElement(mockComponent, { get = getSignal }))
	end)

	local label = container:FindFirstChildWhichIsA("TextLabel")
	expect(label).never.toBeNil()
	assert(label, "should be non-nil")

	expect(renderCount).toEqual(2)
	expect(label.Text).toEqual("hello")

	ReactRoblox.act(function()
		setSignal("world")
		task.wait()
	end)

	expect(renderCount).toEqual(2)
	expect(label.Text).toEqual("world")

	ReactRoblox.act(function()
		setSignal("hi")
		task.wait()
	end)

	expect(renderCount).toEqual(2)
	expect(label.Text).toEqual("hi")

	local getDerived = createComputed(function(scope)
		return getSignal(scope)
	end)

	ReactRoblox.act(function()
		root:render(React.createElement(mockComponent, { get = getDerived }))
	end)

	expect(renderCount).toEqual(4)
	expect(label.Text).toEqual("hi")

	ReactRoblox.act(function()
		setSignal("bye")
		task.wait()
	end)

	expect(renderCount).toEqual(4)
	expect(label.Text).toEqual("bye")

	root:unmount()
	container:Destroy()
end)
