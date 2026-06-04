-- Minimal offline test runner for the pure plugin logic (address/stream/checksum).
-- Run from the repo root:  lua test/run.lua   (or: mise run test)
-- No mise modules / network required.

package.path = "./?.lua;" .. package.path

local count, failures = 0, 0

local function eq(actual, expected, msg)
    count = count + 1
    if actual ~= expected then
        failures = failures + 1
        print(
            string.format(
                "  FAIL: %s\n    expected: %s\n    got:      %s",
                msg or "",
                tostring(expected),
                tostring(actual)
            )
        )
    end
end

local function truthy(v, msg)
    eq(v and true or false, true, msg)
end

local function falsy(v, msg)
    eq(v and true or false, false, msg)
end

-- expose to test files
_G.eq, _G.truthy, _G.falsy = eq, truthy, falsy

for _, f in ipairs({ "test/address_test.lua", "test/stream_test.lua", "test/checksum_test.lua", "test/origin_test.lua" }) do
    print("== " .. f)
    dofile(f)
end

print(string.format("\n%d checks, %d failures", count, failures))
os.exit(failures == 0 and 0 or 1)
