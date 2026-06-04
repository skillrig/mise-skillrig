-- Tests for lib/address.lua (pure). Globals eq/truthy/falsy come from run.lua.
local address = require("lib/address")

-- Embedded-origin form: <owner>/<repo>/<bin>
local a = address.parse({ tool = "my-org/my-skills/jira" })
eq(a.owner, "my-org", "owner")
eq(a.repo, "my-skills", "repo")
eq(a.origin, "my-org/my-skills", "origin")
eq(a.bin, "jira", "bin")

-- Dashed binary name survives the split.
local d = address.parse({ tool = "foo-org-sports/local-devops-scripts/aws-inventory" })
eq(d.origin, "foo-org-sports/local-devops-scripts", "dashed origin")
eq(d.bin, "aws-inventory", "dashed bin")

-- Too-deep path: origin would be 3 segments -> rejected.
falsy(pcall(address.parse, { tool = "a/b/c/jira" }), "three-segment origin errors")

-- `owner/repo` with no binary segment -> origin "owner" is invalid -> error.
falsy(pcall(address.parse, { tool = "owner/repo" }), "missing bin segment errors")

-- Bare tool + per-tool option origin.
local b = address.parse({ tool = "jira", options = { origin = "my-org/my-skills" } })
eq(b.origin, "my-org/my-skills", "bare tool + option origin")
eq(b.bin, "jira", "bare tool bin")

-- Optional ref passes through.
local r = address.parse({ tool = "my-org/my-skills/jira", options = { ref = "main" } })
eq(r.ref, "main", "ref passthrough")

-- Empty tool errors.
falsy(pcall(address.parse, { tool = "" }), "empty tool errors")

-- Reject '.'/'..' segments (would manipulate the API URL path).
falsy(pcall(address.parse, { tool = "../x/jira" }), "dot-dot owner rejected")
falsy(pcall(address.parse, { tool = "my-org/my-skills/.." }), "dot-dot bin rejected")

-- Reject a binary name carrying whitespace / unexpected chars.
falsy(pcall(address.parse, { tool = "jira x", options = { origin = "my-org/my-skills" } }), "whitespace bin rejected")
