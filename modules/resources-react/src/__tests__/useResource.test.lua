local Root = script:FindFirstAncestor("ResourcesReact")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local describe = JestGlobals.describe
local ReactRoblox = require(Packages.Dev.ReactRoblox)

local React = require(Packages.React)

local Resources = require(Packages.Resources)
local createResource = Resources.createResource

local useResource = require(script.Parent.Parent.useResource)

describe("useResource", function()
	it("should create and dispose resource with component lifecycle", function()
		local constructCount = 0
		local disposeCount = 0

		local function createTestResource()
			return createResource(function(own)
				constructCount += 1
				own(function()
					disposeCount += 1
				end)
			end)
		end

		local function TestComponent()
			useResource(createTestResource)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(0)

		ReactRoblox.act(function()
			root:unmount()
		end)

		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(1)

		container:Destroy()
	end)

	it("should pass arguments to resource", function()
		local capturedArgs = nil

		local function TestComponent()
			local function createTestResource()
				return createResource(function()
					capturedArgs = { 1, 2, 3 }
				end)
			end

			useResource(createTestResource)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(capturedArgs).toEqual({ 1, 2, 3 })

		ReactRoblox.act(function()
			root:unmount()
		end)

		container:Destroy()
	end)

	it("should not recreate resource when dependencies stay the same", function()
		local constructCount = 0
		local disposeCount = 0

		local function createTestResource()
			return createResource(function(own)
				constructCount += 1
				own(function()
					disposeCount += 1
				end)
			end)
		end

		local function TestComponent()
			useResource(createTestResource)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(0)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(0)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(0)

		ReactRoblox.act(function()
			root:unmount()
		end)

		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(1)

		container:Destroy()
	end)

	it("should handle resources with no arguments", function()
		local constructCount = 0

		local function createTestResource()
			return createResource(function()
				constructCount += 1
			end)
		end

		local function TestComponent()
			useResource(createTestResource)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(constructCount).toBe(1)

		ReactRoblox.act(function()
			root:unmount()
		end)

		container:Destroy()
	end)

	it("should handle nested resources", function()
		local innerConstructCount = 0
		local innerDisposeCount = 0
		local outerConstructCount = 0
		local outerDisposeCount = 0

		local function createInnerResource()
			return createResource(function(own)
				innerConstructCount += 1
				own(function()
					innerDisposeCount += 1
				end)
			end)
		end

		local function createOuterResource()
			return createResource(function(own)
				outerConstructCount += 1
				own(createInnerResource())
				own(function()
					outerDisposeCount += 1
				end)
			end)
		end

		local function TestComponent()
			useResource(createOuterResource)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(innerConstructCount).toBe(1)
		expect(outerConstructCount).toBe(1)
		expect(innerDisposeCount).toBe(0)
		expect(outerDisposeCount).toBe(0)

		ReactRoblox.act(function()
			root:unmount()
		end)

		expect(innerConstructCount).toBe(1)
		expect(outerConstructCount).toBe(1)
		expect(innerDisposeCount).toBe(1)
		expect(outerDisposeCount).toBe(1)

		container:Destroy()
	end)

	it("should handle multiple components using same resource", function()
		local constructCount = 0
		local disposeCount = 0

		local function createTestResource()
			return createResource(function(own)
				constructCount += 1
				own(function()
					disposeCount += 1
				end)
			end)
		end

		local function TestComponent()
			useResource(createTestResource)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement("Folder", {}, {
				Child1 = React.createElement(TestComponent),
				Child2 = React.createElement(TestComponent),
				Child3 = React.createElement(TestComponent),
			}))
		end)

		expect(constructCount).toBe(3)
		expect(disposeCount).toBe(0)

		ReactRoblox.act(function()
			root:unmount()
		end)

		expect(constructCount).toBe(3)
		expect(disposeCount).toBe(3)

		container:Destroy()
	end)

	it("should handle resource changes with different resource objects", function()
		local resource1ConstructCount = 0
		local resource1DisposeCount = 0
		local resource2ConstructCount = 0
		local resource2DisposeCount = 0

		local function createResource1()
			return createResource(function(own)
				resource1ConstructCount += 1
				own(function()
					resource1DisposeCount += 1
				end)
			end)
		end

		local function createResource2()
			return createResource(function(own)
				resource2ConstructCount += 1
				own(function()
					resource2DisposeCount += 1
				end)
			end)
		end

		local function TestComponent(props)
			useResource(props.resourceFactory)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent, { resourceFactory = createResource1 }))
		end)

		expect(resource1ConstructCount).toBe(1)
		expect(resource1DisposeCount).toBe(0)
		expect(resource2ConstructCount).toBe(0)
		expect(resource2DisposeCount).toBe(0)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent, { resourceFactory = createResource2 }))
		end)

		expect(resource1ConstructCount).toBe(1)
		expect(resource1DisposeCount).toBe(1)
		expect(resource2ConstructCount).toBe(1)
		expect(resource2DisposeCount).toBe(0)

		ReactRoblox.act(function()
			root:unmount()
		end)

		expect(resource1ConstructCount).toBe(1)
		expect(resource1DisposeCount).toBe(1)
		expect(resource2ConstructCount).toBe(1)
		expect(resource2DisposeCount).toBe(1)

		container:Destroy()
	end)

	it("should work with nil arguments", function()
		local constructCount = 0

		local function createTestResource()
			return createResource(function()
				constructCount += 1
			end)
		end

		local function TestComponent()
			useResource(createTestResource)
			return nil
		end

		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(TestComponent))
		end)

		expect(constructCount).toBe(1)

		ReactRoblox.act(function()
			root:unmount()
		end)

		container:Destroy()
	end)
end)
