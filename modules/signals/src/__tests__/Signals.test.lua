local Root = script:FindFirstAncestor("Signals")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local SignalsScheduler = require(Packages.SignalsScheduler)
local batch = SignalsScheduler.batch

local Signals = require(script.Parent.Parent.Signals)
local createSignal = Signals.createSignal
local createComputed = Signals.createComputed
local createEffect = Signals.createEffect

local RUNS = 10

it("should execute an effect only once with no dependencies", function()
	local count = 0

	local dispose = createEffect(function(_scope)
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)

	dispose()

	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
end)

it("should be fine to call dispose multiple times", function()
	local count = 0

	local dispose = createEffect(function(_scope)
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)

	dispose()

	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)

	dispose()

	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
end)

it("should execute an effect when a dependency changes", function()
	local count = 0
	local get, set = createSignal(0)

	local dispose = createEffect(function(scope)
		get(scope)
		count += 1
	end) -- effect should fire once

	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)
	task.wait()
	expect(count).toEqual(1)

	set(1) -- effect should fire again

	task.wait()
	expect(count).toEqual(2)
	task.wait()
	expect(count).toEqual(2)
	task.wait()
	expect(count).toEqual(2)

	set(2) -- effect should fire once more

	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)

	set(2) -- effect should not fire if source did not change

	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)

	dispose() -- dispose should not change value

	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)

	set(3) -- should be a no-op after being disposed

	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)
	task.wait()
	expect(count).toEqual(3)
end)

it("should support dynamic/changing dependencies", function()
	local countA, countB = 0, 0
	local getToggle, setToggle = createSignal(true)
	local getA, setA = createSignal(0)
	local getB, setB = createSignal(0)

	local dispose = createEffect(function(scope)
		if getToggle(scope) then
			countA += 1
			getA(scope)
		else
			countB += 1
			getB(scope)
		end
	end) -- effect should fire once

	task.wait()
	expect(countA).toEqual(1)
	expect(countB).toEqual(0)
	task.wait()
	expect(countA).toEqual(1)
	expect(countB).toEqual(0)
	task.wait()
	expect(countA).toEqual(1)
	expect(countB).toEqual(0)

	setA(1) -- should re-run effect

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(0)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(0)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(0)

	setB(1) -- should not re-run effect

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(0)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(0)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(0)

	setToggle(false) -- should re-run effect

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(1)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(1)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(1)

	setA(2) -- should not re-run effect

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(1)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(1)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(1)

	setB(2) -- should re-run effect

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)

	dispose() -- should not re-run effect

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)

	setA(3) -- should not re-run effect after being disposed

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)

	setB(3) -- should not re-run effect after being disposed

	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
	task.wait()
	expect(countA).toEqual(2)
	expect(countB).toEqual(2)
end)

it("should execute effects once per state update for simple graphs", function()
	local sum = 0

	local getA, setA = createSignal(1)
	local getB, setB = createSignal(2)
	local getC, setC = createSignal(3)

	for i = 1, RUNS do
		local function getPadding()
			return 39 * (i - 1)
		end

		task.wait()
		expect(sum).toEqual(0 + getPadding())

		local dispose1 = createEffect(function(scope)
			sum = sum + getA(scope)
		end)
		local dispose2 = createEffect(function(scope)
			sum = sum + getA(scope)
		end)
		local dispose3 = createEffect(function(scope)
			sum = sum + getA(scope)
		end)

		task.wait()
		expect(sum).toEqual(3 + getPadding())

		local dispose4 = createEffect(function(scope)
			sum = sum + getB(scope)
		end)
		local dispose5 = createEffect(function(scope)
			sum = sum + getB(scope)
		end)
		local dispose6 = createEffect(function(scope)
			sum = sum + getB(scope)
		end)

		task.wait()
		expect(sum).toEqual(9 + getPadding())

		local dispose7 = createEffect(function(scope)
			sum = sum + getC(scope)
		end)
		local dispose8 = createEffect(function(scope)
			sum = sum + getC(scope)
		end)
		local dispose9 = createEffect(function(scope)
			sum = sum + getC(scope)
		end)

		task.wait()
		expect(sum).toEqual(18 + getPadding())

		setA(getB(false))
		task.wait()
		expect(sum).toEqual(24 + getPadding())

		setB(getC(false))
		task.wait()
		expect(sum).toEqual(33 + getPadding())

		setC(getA(false))
		task.wait()
		expect(sum).toEqual(39 + getPadding())

		dispose1()
		dispose2()
		dispose3()
		dispose4()
		dispose5()
		dispose6()
		dispose7()
		dispose8()
		dispose9()

		task.wait()
		expect(sum).toEqual(39 + getPadding())

		setA(1)
		setB(2)
		setC(3)

		task.wait()
		expect(sum).toEqual(39 + getPadding())
	end

	task.wait()
	expect(sum).toBe(39 * RUNS)
end)

it("should execute effects once per state update for complex graphs (with effect batching enabled)", function()
	local sum = 0

	local getA, setA = createSignal(1)
	local getB, setB = createSignal(2)
	local getC, setC = createSignal(3)

	local getD = createComputed(function(scope)
		return getA(scope) + getB(scope) + getC(scope)
	end)
	local getE = createComputed(function(scope)
		return getA(scope) + getB(scope) + getC(scope) + getD(scope)
	end)
	local getF = createComputed(function(scope)
		return getA(scope) + getB(scope) + getC(scope) + getD(scope) + getE(scope)
	end)
	local getG = createComputed(function(scope)
		return getE(scope) + getF(scope)
	end)
	local getH = createComputed(function(scope)
		return getF(scope) + getG(scope)
	end)
	local getI = createComputed(function(scope)
		return getF(scope) + getG(scope) + getA(scope)
	end)
	local getJ = createComputed(function(scope)
		return getF(scope) + getH(scope) + getD(scope) + getI(scope)
	end) -- J = 151

	for i = 1, RUNS do
		local function getPadding()
			return ((3 * 151) + (3 * 177)) * (i - 1)
		end

		local dispose1 = createEffect(function(scope)
			sum = sum + getJ(scope)
		end)
		local dispose2 = createEffect(function(scope)
			sum = sum + getJ(scope)
		end)
		local dispose3 = createEffect(function(scope)
			sum = sum + getJ(scope)
		end)

		task.wait()
		expect(sum).toEqual((3 * 151) + getPadding())

		batch(function()
			setA(getB(false)) -- J = 177
			setB(getC(false)) -- J = 202
			setC(getA(false)) -- J = 177
		end)

		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + getPadding())

		dispose1()
		dispose2()
		dispose3()

		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + getPadding())

		batch(function()
			setA(1)
			setB(2)
			setC(3)
		end)

		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + getPadding())
	end

	task.wait()
	expect(sum).toEqual(((3 * 151) + (3 * 177)) * RUNS)
end)

it("should execute effects once per state update for complex graphs", function()
	local sum = 0

	local getA, setA = createSignal(1)
	local getB, setB = createSignal(2)
	local getC, setC = createSignal(3)

	local getD = createComputed(function(scope)
		return getA(scope) + getB(scope) + getC(scope)
	end)
	local getE = createComputed(function(scope)
		return getA(scope) + getB(scope) + getC(scope) + getD(scope)
	end)
	local getF = createComputed(function(scope)
		return getA(scope) + getB(scope) + getC(scope) + getD(scope) + getE(scope)
	end)
	local getG = createComputed(function(scope)
		return getE(scope) + getF(scope)
	end)
	local getH = createComputed(function(scope)
		return getF(scope) + getG(scope)
	end)
	local getI = createComputed(function(scope)
		return getF(scope) + getG(scope) + getA(scope)
	end)
	local getJ = createComputed(function(scope)
		return getF(scope) + getH(scope) + getD(scope) + getI(scope)
	end) -- J = 151

	for i = 1, RUNS do
		local function getPadding()
			return ((3 * 151) + (3 * 177) + (3 * 202) + (3 * 177)) * (i - 1)
		end

		local dispose1 = createEffect(function(scope)
			sum = sum + getJ(scope)
		end)
		local dispose2 = createEffect(function(scope)
			sum = sum + getJ(scope)
		end)
		local dispose3 = createEffect(function(scope)
			sum = sum + getJ(scope)
		end)

		task.wait()
		expect(sum).toEqual((3 * 151) + getPadding())

		setA(getB(false)) -- J = 177
		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + getPadding())

		setB(getC(false)) -- J = 202
		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + (3 * 202) + getPadding())

		setC(getA(false)) -- J = 177
		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + (3 * 202) + (3 * 177) + getPadding())

		dispose1()
		dispose2()
		dispose3()

		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + (3 * 202) + (3 * 177) + getPadding())

		setA(1)
		setB(2)
		setC(3)

		task.wait()
		expect(sum).toEqual((3 * 151) + (3 * 177) + (3 * 202) + (3 * 177) + getPadding())
	end

	task.wait()
	expect(sum).toEqual(((3 * 151) + (3 * 177) + (3 * 202) + (3 * 177)) * RUNS)
end)

-- From: https://fluff.blog/2024/07/14/glitches-in-dynamic-reactive-graphs.html
it("should correctly handle processing updates for dynamic graphs", function()
	local getHasSubGraph, setHasSubGraph = createSignal(true)

	local getOuter = createComputed(function(scope): Signals.getter<boolean>?
		if getHasSubGraph(scope) then
			return createComputed(function(innerScope)
				return getHasSubGraph(innerScope)
			end)
		else
			return nil
		end
	end)

	local outerIsNil = 0
	local innerIsTrue = 0
	local innerIsFalse = 0

	local dispose = createEffect(function(scope)
		local getInner = getOuter(scope)
		if getInner == nil then
			outerIsNil += 1
		else
			if getInner(false) then
				innerIsTrue += 1
			else
				innerIsFalse += 1
			end
		end
	end)

	task.wait()
	expect(outerIsNil).toEqual(0)
	expect(innerIsTrue).toEqual(1)
	expect(innerIsFalse).toEqual(0)

	setHasSubGraph(false)

	task.wait()
	expect(outerIsNil).toEqual(1)
	expect(innerIsTrue).toEqual(1)
	expect(innerIsFalse).toEqual(0)

	dispose()

	task.wait()
	expect(outerIsNil).toEqual(1)
	expect(innerIsTrue).toEqual(1)
	expect(innerIsFalse).toEqual(0)
end)

it("should support nested ephemeral signals", function()
	local getOuterEnabled, setOuterEnabled = createSignal(false)

	local getEnabled = createComputed(function(scope)
		local getInnerEnabled = createComputed(function(innerScope)
			return getOuterEnabled(innerScope)
		end)
		return getInnerEnabled(scope)
	end)

	expect(getEnabled(false)).toEqual(false)

	task.wait()
	task.wait()
	task.wait()

	setOuterEnabled(true)
	task.wait()

	expect(getEnabled(false)).toEqual(true)
end)

it("should not compute until first read", function()
	local getSignal, setSignal = createSignal(1)
	local computeCount = 0

	local getComputed = createComputed(function(scope)
		computeCount += 1
		return getSignal(scope) * 2
	end)

	expect(computeCount).toEqual(0) -- not computed until it is read

	setSignal(2)
	task.wait()
	expect(computeCount).toEqual(0) -- still not read

	local value = getComputed(false) -- now it computes as the getter reads it
	expect(computeCount).toEqual(1)
	expect(value).toEqual(4)
end)

it("should handle setting signals inside effects", function()
	local getSignalA, setSignalA = createSignal(0)
	local getSignalB, setSignalB = createSignal(0)
	local effectACount = 0
	local effectBCount = 0

	local dispose2 = createEffect(function(scope)
		getSignalB(scope)
		effectBCount += 1
	end)

	local dispose1 = createEffect(function(scope)
		local val = getSignalA(scope)
		effectACount += 1
		if val > 0 then
			setSignalB(val * 2)
		end
	end)

	task.wait()
	expect(effectACount).toEqual(1)
	expect(effectBCount).toEqual(1)

	setSignalA(5)
	task.wait()
	expect(getSignalB(false)).toEqual(10)
	expect(effectACount).toEqual(2)
	expect(effectBCount).toEqual(2)

	dispose1()
	dispose2()
end)

it("should support chained signal updates across effects", function()
	local getA, setA = createSignal(0)
	local getB, setB = createSignal(0)
	local getC, setC = createSignal(0)

	local dispose1 = createEffect(function(scope)
		local val = getA(scope)
		if val > 0 then
			setB(val + 1)
		end
	end)

	local dispose2 = createEffect(function(scope)
		local val = getB(scope)
		if val > 0 then
			setC(val + 1)
		end
	end)

	task.wait()
	expect(getA(false)).toEqual(0)
	expect(getB(false)).toEqual(0)
	expect(getC(false)).toEqual(0)

	setA(1)
	task.wait()
	expect(getA(false)).toEqual(1)
	expect(getB(false)).toEqual(2)
	expect(getC(false)).toEqual(3)

	dispose1()
	dispose2()
end)

it("should handle reading same signal multiple times in one scope", function()
	local getSignal, setSignal = createSignal(1)
	local count = 0

	local dispose = createEffect(function(scope)
		local _a = getSignal(scope)
		local _b = getSignal(scope)
		local _c = getSignal(scope)
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)

	setSignal(2)
	task.wait()
	expect(count).toEqual(2) -- should only run once, not three times

	dispose()
end)

it("should handle multiple effects depending on same computed", function()
	local get, set = createSignal(1)
	local getComputed = createComputed(function(scope)
		return get(scope) * 2
	end)

	local count1, count2, count3 = 0, 0, 0

	local dispose1 = createEffect(function(scope)
		getComputed(scope)
		count1 += 1
	end)

	local dispose2 = createEffect(function(scope)
		getComputed(scope)
		count2 += 1
	end)

	local dispose3 = createEffect(function(scope)
		getComputed(scope)
		count3 += 1
	end)

	task.wait()
	expect(count1).toEqual(1)
	expect(count2).toEqual(1)
	expect(count3).toEqual(1)

	set(5)
	task.wait()
	expect(count1).toEqual(2)
	expect(count2).toEqual(2)
	expect(count3).toEqual(2)

	dispose1()
	dispose2()
	dispose3()
end)

it("should lazily initialize signals with function values", function()
	local initCount = 0

	local get, set = createSignal(function()
		initCount += 1
		return 100
	end)

	expect(initCount).toEqual(0) -- not yet initialized

	local value = get(false)
	expect(value).toEqual(100)
	expect(initCount).toEqual(1) -- initialized

	get(false)
	expect(initCount).toEqual(1) -- should only init once

	set(200)
	expect(get(false)).toEqual(200)
	expect(initCount).toEqual(1)
end)

it("should handle table values with reference equality", function()
	local table1 = { value = 1 }
	local getSignal, setSignal = createSignal(table1)
	local count = 0

	local dispose = createEffect(function(scope)
		getSignal(scope)
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)

	setSignal(table1) -- same reference, should not trigger
	task.wait()
	expect(count).toEqual(1)

	local table2 = { value = 1 } -- different table reference, same contents, should trigger
	setSignal(table2)
	task.wait()
	expect(count).toEqual(2)

	setSignal(table2) -- same reference again, should not trigger
	task.wait()
	expect(count).toEqual(2)

	dispose()
end)

it("should recompute only when dependencies actually change", function()
	local getSignalA, setSignalA = createSignal(1)
	local getSignalB, setSignalB = createSignal(2)
	local computeCount = 0

	local getComputed = createComputed(function(scope)
		computeCount += 1
		return getSignalA(scope) + getSignalB(scope)
	end)

	expect(getComputed(false)).toEqual(3)
	expect(computeCount).toEqual(1)

	setSignalA(1) -- same value, should not recompute
	task.wait()
	expect(computeCount).toEqual(1)

	setSignalB(2) -- same value, should not recompute
	task.wait()
	expect(computeCount).toEqual(1)

	setSignalA(5) -- different value, should recompute
	expect(getComputed(false)).toEqual(7)
	expect(computeCount).toEqual(2)
end)

it("should handle reading signals after all effects are disposed", function()
	local getSignalA, setSignalA = createSignal(1)
	local getSignalB, setSignalB = createSignal(2)
	local count = 0

	local dispose1 = createEffect(function(scope)
		getSignalA(scope)
		count += 1
	end)

	local dispose2 = createEffect(function(scope)
		getSignalB(scope)
		count += 1
	end)

	task.wait()
	expect(count).toEqual(2)

	dispose1()
	dispose2()

	task.wait()
	expect(count).toEqual(2)

	-- signals should still be readable and settable
	expect(getSignalA(false)).toEqual(1)
	expect(getSignalB(false)).toEqual(2)

	setSignalA(10)
	setSignalB(20)

	expect(getSignalA(false)).toEqual(10)
	expect(getSignalB(false)).toEqual(20)

	task.wait()
	expect(count).toEqual(2) -- no phantom effects
end)

it("should handle nested batch calls", function()
	local getA, setA = createSignal(1)
	local getB, setB = createSignal(2)
	local getC, setC = createSignal(3)
	local count = 0

	local dispose = createEffect(function(scope)
		getA(scope)
		getB(scope)
		getC(scope)
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)

	batch(function()
		setA(10)
		batch(function()
			setB(20)
			setC(30)
		end)
	end)

	task.wait()
	expect(count).toEqual(2) -- should only run once for all updates
	expect(getA(false)).toEqual(10)
	expect(getB(false)).toEqual(20)
	expect(getC(false)).toEqual(30)

	dispose()
end)
