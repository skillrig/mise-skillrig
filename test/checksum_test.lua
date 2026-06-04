-- Tests for lib/checksum.lua pure functions. Globals from run.lua.
local checksum = require("lib/checksum")

-- goreleaser format: "<hash>  <file>" (two spaces)
local body = "abc123  jira_1.7.0_linux_amd64.tar.gz\n" .. "DEF456  jira_1.7.0_darwin_arm64.tar.gz\n"
eq(checksum.expected(body, "jira_1.7.0_linux_amd64.tar.gz"), "abc123", "expected hash")
eq(checksum.expected(body, "jira_1.7.0_darwin_arm64.tar.gz"), "def456", "hash lowercased")
eq(checksum.expected(body, "not-listed.tar.gz"), nil, "missing entry -> nil")

-- binary marker (*) and single-space variant
local body2 = "AABBCC *foo_1.0.0_linux_amd64.tar.gz\n"
eq(checksum.expected(body2, "foo_1.0.0_linux_amd64.tar.gz"), "aabbcc", "binary marker + lowercase")

-- verify_hash is case-insensitive on the hash
truthy((checksum.verify_hash(body, "jira_1.7.0_linux_amd64.tar.gz", "ABC123")), "verify match (case-insensitive)")
falsy((checksum.verify_hash(body, "jira_1.7.0_linux_amd64.tar.gz", "deadbeef")), "verify mismatch")
falsy((checksum.verify_hash(body, "missing.tar.gz", "whatever")), "verify missing entry")

-- mismatch message is informative
local ok, msg = checksum.verify_hash(body, "jira_1.7.0_linux_amd64.tar.gz", "deadbeef")
eq(ok, false, "mismatch returns false")
truthy(msg and msg:find("mismatch"), "mismatch message mentions mismatch")
