-- Tests for lib/stream.lua (pure). Globals eq/truthy/falsy come from run.lua.
local stream = require("lib/stream")

-- build-metadata scheme (the active one)
eq(stream.match("1.7.0+jira", "jira"), "1.7.0", "build-metadata match")
eq(stream.match("v1.7.0+jira", "jira"), "1.7.0", "build-metadata match (leading v)")
eq(stream.match("0.0.6+tfc", "jira"), nil, "other stream -> nil")
eq(stream.match("1.0.0+jira-cli", "jira"), nil, "jira does not match +jira-cli skill stream")
eq(stream.match("1.0.0+jira.cli", "jira"), nil, "exact build match: jira does not swallow +jira.cli")

-- prefix scheme (the dormant 'proper' one)
eq(stream.match("jira-v1.7.0", "jira"), "1.7.0", "prefix match")
eq(stream.match("jira-1.7.0", "jira"), "1.7.0", "prefix match (no v)")
eq(stream.match("jira-cli-v1.0.0", "jira"), nil, "prefix does not swallow jira-cli-v*")
eq(stream.match("aws-inventory-v1.0.0", "aws-inventory"), "1.0.0", "prefix with dashed bin")
eq(stream.match("jira-v1.7.0+meta", "jira"), nil, "prefix tag carrying +build metadata is not folded")

-- a build-metadata tag for ANOTHER stream must not short-circuit prefix detection
eq(stream.match("0.1.0+tfc", "jira"), nil, "other build-metadata stream -> nil")

-- non-stream tags
eq(stream.match("1.7.0", "jira"), nil, "bare semver -> nil")

-- stream_versions + sort (numeric, not lexical)
local tags = { "0.0.6+tfc", "1.7.0+jira", "1.10.0+jira", "1.2.0+jira", "2.0.0+awsinv" }
local v = stream.stream_versions(tags, "jira")
stream.sort_asc(v)
eq(table.concat(v, ","), "1.2.0,1.7.0,1.10.0", "jira versions filtered + sorted ascending")
eq(#stream.stream_versions(tags, "ddinv"), 0, "no versions for absent stream")

-- find_tag returns the exact original tag
eq(stream.find_tag(tags, "jira", "1.7.0"), "1.7.0+jira", "find_tag exact")
eq(stream.find_tag(tags, "jira", "9.9.9"), nil, "find_tag missing")

-- asset + checksum naming (goreleaser convention)
eq(stream.asset_name("jira", "1.7.0", "linux", "amd64"), "jira_1.7.0_linux_amd64.tar.gz", "asset name")
eq(stream.checksums_name("jira"), "jira_checksums.txt", "per-tool checksums name")

-- platform passthrough + arch aliases
local p = stream.platform({ osType = "linux", archType = "amd64" })
eq(p.os, "linux", "platform os")
eq(p.arch, "amd64", "platform arch")
eq(stream.platform({ osType = "darwin", archType = "aarch64" }).arch, "arm64", "arch alias aarch64->arm64")
falsy(pcall(stream.platform, { osType = "windows", archType = "amd64" }), "windows fails fast (unsupported)")

-- pre-release ranks below its release
local vv = { "1.0.0", "1.0.0-rc.1", "0.9.0" }
stream.sort_asc(vv)
eq(table.concat(vv, ","), "0.9.0,1.0.0-rc.1,1.0.0", "pre-release ordering")

-- numeric pre-release identifiers compare numerically, not lexically (SemVer §11)
local vp = { "1.0.0-rc.10", "1.0.0-rc.2", "1.0.0-rc.1" }
stream.sort_asc(vp)
eq(table.concat(vp, ","), "1.0.0-rc.1,1.0.0-rc.2,1.0.0-rc.10", "numeric pre-release ids")

-- alphanumeric > numeric identifier; fewer fields < more
local vp2 = { "1.0.0-alpha.1", "1.0.0-alpha", "1.0.0-1" }
stream.sort_asc(vp2)
eq(table.concat(vp2, ","), "1.0.0-1,1.0.0-alpha,1.0.0-alpha.1", "pre-release identifier precedence")
