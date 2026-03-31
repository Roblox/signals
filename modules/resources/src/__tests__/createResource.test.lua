local Root = script:FindFirstAncestor("Resources")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local describe = JestGlobals.describe

local createResource = require(script.Parent.Parent.createResource)

describe("createResource", function()
	it("should allow resource to be called directly", function()
		local called = false
		local dispose, value = createResource(function(_)
			called = true
			return "test-value"
		end)

		expect(called).toBe(true)
		expect(value).toBe("test-value")

		dispose()
	end)

	it("should support resources with no arguments", function()
		local dispose, value = createResource(function(_)
			return 42
		end)

		expect(value).toBe(42)

		dispose()
	end)

	it("should support resources with multiple return values", function()
		local dispose, a, b, c = createResource(function(_)
			return 1, 2, 3
		end)

		expect(a).toBe(1)
		expect(b).toBe(2)
		expect(c).toBe(3)

		dispose()
	end)

	it("should call dispose function when root is disposed", function()
		local disposed = false
		local dispose, value = createResource(function(own)
			own(function()
				disposed = true
			end)
			return "value"
		end)

		expect(disposed).toBe(false)
		expect(value).toBe("value")

		dispose()

		expect(disposed).toBe(true)
	end)

	it("should support nested resource usage", function()
		local dispose, value = createResource(function(own)
			local innerValue = own(createResource(function(_)
				return "inner"
			end))
			return "outer-" .. innerValue
		end)

		expect(value).toBe("outer-inner")

		dispose()
	end)

	it("should dispose in reverse order", function()
		local disposeOrder: { string | number } = {}

		local dispose = createResource(function(own)
			own(createResource(function(own2)
				own2(function()
					table.insert(disposeOrder, 1)
				end)
				return "first"
			end))
			own(createResource(function(own2)
				own2(function()
					table.insert(disposeOrder, 2)
				end)
				return "second"
			end))
			own(createResource(function(own2)
				own2(function()
					table.insert(disposeOrder, 3)
				end)
				return "third"
			end))
			own(function()
				table.insert(disposeOrder, "parent")
			end)
		end)

		expect(#disposeOrder).toBe(0)

		dispose()

		expect(disposeOrder).toEqual({ "parent" :: string | number, 3, 2, 1 })
	end)

	it("should handle string errors during disposal", function()
		local dispose = createResource(function(own)
			own(function()
				error("table error")
			end)
		end)

		expect(function()
			dispose()
		end).toThrow("table error")
	end)

	it("should handle non-string errors during disposal", function()
		local tableError = { message = "table error" }
		local dispose = createResource(function(own)
			own(function()
				error(tableError)
			end)
		end)

		expect(function()
			dispose()
		end).toThrow(tostring(tableError))
	end)

	it("should handle multiple non-string errors during disposal", function()
		local tableError = { message = "table error" }
		local functionError = function() end
		local dispose = createResource(function(own)
			own(function()
				error(functionError)
			end)
			own(function()
				error(tableError)
			end)
			own(function()
				error(true)
			end)
		end)

		expect(function()
			dispose()
		end).toThrow(`{tostring(true)}\n{tostring(tableError)}\n{tostring(functionError)}`)
	end)
end)
