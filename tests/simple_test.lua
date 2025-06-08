-- tests/simple_test.lua

-- Original Python: print(not False or False)

local result = not false or false
print(result) -- Expected output: true

-- To make it slightly more like a "test", we can add an assertion
-- This would require a simple assertion function if not using a framework.

--[[
-- Example of a simple assert (can be in a helper file)
local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("Assertion failed: %s. Expected %s, got %s", message or "", tostring(expected), tostring(actual)))
    else
        print(string.format("Assertion passed: %s", message or ""))
    end
end

assert_equal(result, true, "Boolean logic test (not false or false)")
]]

-- For now, just the print to match the original script's behavior.
