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

local SignalsFlags = require(Packages.SignalsFlags)
local SignalsReactUseMutableSource = SignalsFlags.SignalsReactUseMutableSource

local useSignalState = require(script.Parent.Parent.useSignalState)

it("should return state synchronously", function()
	local rendered = {}

	local getSignal, setSignal = createSignal(1)

	local function mockComponent(props: { get: Signals.getter<number> })
		local value = useSignalState(props.get)
		table.insert(rendered, value)
	end

	local container = Instance.new("Folder")
	local root = ReactRoblox.createRoot(container)

	ReactRoblox.act(function()
		root:render(React.createElement(mockComponent, { get = getSignal }))
	end)

	expect(#rendered).toEqual(2)
	expect(rendered).toEqual({ 1, 1 })

	ReactRoblox.act(function()
		setSignal(2)
		task.wait()
	end)

	if SignalsReactUseMutableSource then
		expect(#rendered).toEqual(4)
		expect(rendered).toEqual({ 1, 1, 2, 2 })
	else
		expect(#rendered).toEqual(6)
		expect(rendered).toEqual({ 1, 1, 2, 2, 2, 2 })
	end

	ReactRoblox.act(function()
		setSignal(2)
		task.wait()
	end)

	if SignalsReactUseMutableSource then
		expect(#rendered).toEqual(4)
		expect(rendered).toEqual({ 1, 1, 2, 2 })
	else
		expect(#rendered).toEqual(6)
		expect(rendered).toEqual({ 1, 1, 2, 2, 2, 2 })
	end

	local getDerived = createComputed(function(scope)
		return getSignal(scope)
	end)

	ReactRoblox.act(function()
		root:render(React.createElement(mockComponent, { get = getDerived }))
	end)

	if SignalsReactUseMutableSource then
		expect(#rendered).toEqual(6)
		expect(rendered).toEqual({ 1, 1, 2, 2, 2, 2 })
	else
		expect(#rendered).toEqual(8)
		expect(rendered).toEqual({ 1, 1, 2, 2, 2, 2, 2, 2 })
	end

	ReactRoblox.act(function()
		setSignal(3)
		task.wait()
	end)

	if SignalsReactUseMutableSource then
		expect(#rendered).toEqual(8)
		expect(rendered).toEqual({ 1, 1, 2, 2, 2, 2, 3, 3 })
	else
		expect(#rendered).toEqual(12)
		expect(rendered).toEqual({ 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3 })
	end

	root:unmount()
	container:Destroy()
end)
