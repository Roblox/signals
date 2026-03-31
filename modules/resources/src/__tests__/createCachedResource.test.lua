local Root = script:FindFirstAncestor("Resources")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local describe = JestGlobals.describe

local createResource = require(script.Parent.Parent.createResource)
local createCachedResource = require(script.Parent.Parent.createCachedResource)

describe("createCachedResource", function()
	it("should create a cached resource that can be used multiple times", function()
		local constructCount = 0
		local disposeCount = 0

		local cachedResource = createCachedResource(function()
			return createResource(function(own)
				constructCount += 1
				own(function()
					disposeCount += 1
				end)
				return "value"
			end)
		end)

		expect(constructCount).toBe(0)
		expect(disposeCount).toBe(0)

		local dispose1, value1 = cachedResource()
		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(0)
		expect(value1).toBe("value")

		local dispose2, value2 = cachedResource()
		expect(constructCount).toBe(1) -- Should not construct again
		expect(disposeCount).toBe(0)
		expect(value2).toBe("value")

		local dispose3, value3 = cachedResource()
		expect(constructCount).toBe(1) -- Should not construct again
		expect(disposeCount).toBe(0)
		expect(value3).toBe("value")

		dispose1()
		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(0) -- Should not dispose yet

		dispose2()
		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(0) -- Should not dispose yet

		dispose3()
		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(1) -- Now it should dispose
	end)

	it("should reconstruct resource after all references are disposed", function()
		local constructCount = 0
		local disposeCount = 0

		local cachedResource = createCachedResource(function()
			return createResource(function(own)
				constructCount += 1
				own(function()
					disposeCount += 1
				end)
				return "value"
			end)
		end)

		local dispose1, value1 = cachedResource()
		expect(constructCount).toBe(1)
		expect(value1).toBe("value")

		dispose1()
		expect(constructCount).toBe(1)
		expect(disposeCount).toBe(1)

		-- Use again after fully disposing
		local dispose2, value2 = cachedResource()
		expect(constructCount).toBe(2) -- Should reconstruct
		expect(disposeCount).toBe(1)
		expect(value2).toBe("value")

		dispose2()
		expect(constructCount).toBe(2)
		expect(disposeCount).toBe(2)
	end)

	it("should handle calling dispose multiple times for same reference", function()
		local constructCount = 0
		local disposeCount = 0

		local cachedResource = createCachedResource(function()
			return createResource(function(own)
				constructCount += 1
				own(function()
					disposeCount += 1
				end)
				return "value"
			end)
		end)

		local dispose1, _ = cachedResource()
		local dispose2, _ = cachedResource()

		expect(constructCount).toBe(1)

		dispose1()
		dispose1()
		dispose1()

		expect(disposeCount).toBe(0) -- Still has one reference

		dispose2()
		expect(disposeCount).toBe(1) -- Now fully disposed
	end)

	it("should dispose when error occurs during construction", function()
		local cachedResource = createCachedResource(function()
			error("construction failed")
		end)

		expect(function()
			cachedResource()
		end).toThrow("construction failed")

		-- After error, references should be 0
		-- A second call should attempt construction again
		expect(function()
			cachedResource()
		end).toThrow("construction failed")
	end)

	it("should maintain consistent value across all references", function()
		local counter = 0

		local cachedResource = createCachedResource(function()
			return createResource(function(_)
				counter += 1
				return counter
			end)
		end)

		local dispose1, value1 = cachedResource()
		local dispose2, value2 = cachedResource()
		local dispose3, value3 = cachedResource()

		expect(value1).toBe(1)
		expect(value2).toBe(1)
		expect(value3).toBe(1)

		dispose1()
		dispose2()
		dispose3()

		-- After reconstruction, counter should be 2
		local dispose4, value4 = cachedResource()
		expect(value4).toBe(2)
		dispose4()
	end)

	it("should support complex resources with nested children", function()
		local childConstructCount = 0
		local childDisposeCount = 0
		local parentConstructCount = 0
		local parentDisposeCount = 0

		local function createChildResource()
			return createResource(function(own)
				childConstructCount += 1
				own(function()
					childDisposeCount += 1
				end)
				return "child"
			end)
		end

		local function createParentResource()
			return createResource(function(own)
				parentConstructCount += 1
				local childValue = own(createChildResource())
				own(function()
					parentDisposeCount += 1
				end)
				return "parent-" .. childValue
			end)
		end

		local cachedResource = createCachedResource(createParentResource)

		local dispose1, value1 = cachedResource()
		expect(value1).toBe("parent-child")
		expect(childConstructCount).toBe(1)
		expect(parentConstructCount).toBe(1)

		local dispose2, value2 = cachedResource()
		expect(value2).toBe("parent-child")
		expect(childConstructCount).toBe(1) -- Should not reconstruct
		expect(parentConstructCount).toBe(1)

		dispose1()
		expect(childDisposeCount).toBe(0)
		expect(parentDisposeCount).toBe(0)

		dispose2()
		expect(childDisposeCount).toBe(1) -- Should dispose child
		expect(parentDisposeCount).toBe(1) -- Should dispose parent
	end)

	it("should handle zero-argument resources", function()
		local constructCount = 0

		local cachedResource = createCachedResource(function()
			return createResource(function(_)
				constructCount += 1
				return "singleton"
			end)
		end)

		local dispose1, value1 = cachedResource()
		local dispose2, value2 = cachedResource()

		expect(constructCount).toBe(1)
		expect(value1).toBe("singleton")
		expect(value2).toBe("singleton")

		dispose1()
		dispose2()

		expect(constructCount).toBe(1)
	end)

	it("should properly clean up value on dispose", function()
		local cachedResource = createCachedResource(function()
			return createResource(function(_)
				return { data = "sensitive" }
			end)
		end)

		local dispose1, value1 = cachedResource()
		expect(value1.data).toBe("sensitive")

		local dispose2, value2 = cachedResource()
		expect(value2.data).toBe("sensitive")

		dispose1()
		dispose2()

		-- After full disposal, getting the resource again should create a new value
		local dispose3, value3 = cachedResource()
		expect(value3.data).toBe("sensitive")
		expect(value3).never.toBe(value1) -- Should be a new table

		dispose3()
	end)

	it("should handle interleaved construction and disposal", function()
		local constructCount = 0
		local disposeCount = 0

		local cachedResource = createCachedResource(function()
			return createResource(function(own)
				constructCount += 1
				own(function()
					disposeCount += 1
				end)
				return constructCount
			end)
		end)

		local dispose1, value1 = cachedResource()
		expect(value1).toBe(1)
		expect(constructCount).toBe(1)

		local dispose2, value2 = cachedResource()
		expect(value2).toBe(1)
		expect(constructCount).toBe(1)

		dispose1()
		expect(disposeCount).toBe(0)

		local dispose3, value3 = cachedResource()
		expect(value3).toBe(1)
		expect(constructCount).toBe(1)

		dispose2()
		expect(disposeCount).toBe(0)

		dispose3()
		expect(disposeCount).toBe(1)

		-- Now fully disposed, should reconstruct
		local dispose4, value4 = cachedResource()
		expect(value4).toBe(2)
		expect(constructCount).toBe(2)

		dispose4()
		expect(disposeCount).toBe(2)
	end)
end)
