-- Tests for lib/origin.lua convention gating (pure). Globals from run.lua.
local origin = require("lib/origin")

-- Supported convention passes.
truthy(pcall(origin.assert_supported, { skillrigConvention = 1, origin = "anything/at-all" }), "convention 1 supported")

-- The origin NAME is irrelevant -- a placeholder name must NOT fail the gate.
truthy(
    pcall(origin.assert_supported, { skillrigConvention = 1, origin = "foo-org-sports/local-devops-scripts" }),
    "placeholder origin name does not fail the gate"
)

-- Unsupported (future) convention fails clearly.
falsy(pcall(origin.assert_supported, { skillrigConvention = 2 }), "future convention rejected")

-- Absent index / absent field are tolerated (tags remain source of truth).
truthy(pcall(origin.assert_supported, nil), "nil index tolerated")
truthy(pcall(origin.assert_supported, { origin = "x/y" }), "index without convention field tolerated")
