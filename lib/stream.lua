--- Per-binary release-stream logic, driven by the skillrig origin-template's
--- goreleaser CONVENTION (there is no `[[binaries]]` metadata block to read).
---
--- Tag schemes (a binary's stream is selected by one of these):
---   * build-metadata (ACTIVE on strict-semver origins): `<core>+<bin>`,
---     optional leading `v` -- e.g. `1.7.0+jira`. The build metadata is the
---     bare binary name. Native mise cannot resolve these (SemVer 2.0.0 ignores
---     build metadata for precedence); this plugin can, because it owns listing.
---   * prefix (the "proper" scheme where org rulesets allow it): `<bin>-v<core>`
---     -- e.g. `jira-v1.7.0`.
---
--- Asset/checksum names come from goreleaser's defaults used by the template:
---   asset     = `<bin>_<core>_<os>_<arch>.tar.gz`   (`.Version` is clean semver)
---   checksums = `<bin>_checksums.txt`                (PER-TOOL, not shared)
---
--- This module is PURE. `platform()` takes an optional runtime table so it is
--- testable without the mise-injected `RUNTIME` global.

local stream = {}

-- Escape Lua pattern magic chars so a binary name like `aws-inventory` is matched literally.
local function lpat(s)
    return (s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

--- Return the clean semver core if `tag` belongs to `bin`'s stream, else nil.
--- @param tag string
--- @param bin string
--- @return string|nil core
function stream.match(tag, bin)
    -- build-metadata scheme: <core>+<build>, where build EXACTLY names the binary
    -- (core must be semver-like: digit-led). Exact match avoids `jira` swallowing
    -- `1.0.0+jira.cli` or `1.0.0+jira-cli`.
    local core, build = tag:match("^v?(.-)%+(.+)$")
    if core and build and core:match("^%d") and build == bin then
        return core
    end

    -- prefix scheme: <bin>-v<core>. Core is plain semver (digit-led, NO build
    -- metadata), so `jira` never swallows a `jira-cli-v*` tag and a stray `+meta`
    -- is not folded into the version. Reached as a fall-through, so a build-metadata
    -- tag for another stream does not short-circuit prefix detection.
    local pcore = tag:match("^" .. lpat(bin) .. "%-v?(%d[%w%.%-]*)$")
    if pcore then
        return pcore
    end

    return nil
end

--- All clean version cores belonging to `bin`'s stream (deduped, unsorted).
--- @param tags string[]
--- @param bin string
--- @return string[]
function stream.stream_versions(tags, bin)
    local seen, out = {}, {}
    for _, tag in ipairs(tags) do
        local core = stream.match(tag, bin)
        if core and not seen[core] then
            seen[core] = true
            out[#out + 1] = core
        end
    end
    return out
end

--- The exact original tag whose stream is `bin` and whose core == `version`.
--- Lets BackendInstall reconstruct the real tag without guessing v-prefix/scheme.
--- @param tags string[]
--- @param bin string
--- @param version string
--- @return string|nil tag
function stream.find_tag(tags, bin, version)
    for _, tag in ipairs(tags) do
        if stream.match(tag, bin) == version then
            return tag
        end
    end
    return nil
end

--- goreleaser archive name for a binary/version/platform.
function stream.asset_name(bin, version, os_, arch)
    return bin .. "_" .. version .. "_" .. os_ .. "_" .. arch .. ".tar.gz"
end

--- Per-tool checksum file name.
function stream.checksums_name(bin)
    return bin .. "_checksums.txt"
end

-- Map mise RUNTIME tokens to goreleaser goos/goarch tokens.
-- v1 targets Linux + macOS only: the install hook uses POSIX shell utilities and
-- assets are `.tar.gz`. Windows (goreleaser emits `.zip`, no chmod/find/mv) is a
-- non-goal -- we fail fast with a clear message rather than crash mid-install.
local OS_MAP = { linux = "linux", darwin = "darwin" }
local ARCH_MAP = { amd64 = "amd64", arm64 = "arm64", x64 = "amd64", x86_64 = "amd64", aarch64 = "arm64" }

--- @param runtime table|nil defaults to the global RUNTIME
--- @return table { os, arch }
function stream.platform(runtime)
    local rt = runtime or RUNTIME
    local os_ = OS_MAP[rt.osType]
    if not os_ then
        error("skillrig: unsupported OS '" .. tostring(rt.osType) .. "' (this plugin supports linux and macOS)")
    end
    return {
        os = os_,
        arch = ARCH_MAP[rt.archType] or rt.archType,
    }
end

-- Pure SemVer comparator: numeric dotted core, then pre-release per SemVer 2.0.0 §11.
local function split_dot(s)
    local out = {}
    for part in (s .. "."):gmatch("([^.]*)%.") do
        out[#out + 1] = part
    end
    return out
end

local function core_parts(v)
    local core = v:match("^([^%-+]+)") or v
    local pre = v:match("^[^%-+]*%-([^+]+)") -- pre-release, build metadata stripped
    local nums = {}
    for n in core:gmatch("%d+") do
        nums[#nums + 1] = tonumber(n)
    end
    return nums, pre
end

-- Compare pre-release strings (§11): identifiers split on '.', numeric compared
-- numerically, numeric < alphanumeric, fewer fields < more. Absent pre-release
-- (a normal release) outranks any pre-release. Returns -1 / 0 / 1.
local function cmp_pre(pa, pb)
    if pa == pb then
        return 0
    end
    if not pa then
        return 1
    end
    if not pb then
        return -1
    end
    local ta, tb = split_dot(pa), split_dot(pb)
    for i = 1, math.max(#ta, #tb) do
        local x, y = ta[i], tb[i]
        if x == nil then
            return -1
        end
        if y == nil then
            return 1
        end
        local nx, ny = tonumber(x), tonumber(y)
        if nx and ny then
            if nx ~= ny then
                return nx < ny and -1 or 1
            end
        elseif nx then
            return -1
        elseif ny then
            return 1
        elseif x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

local function less(a, b)
    local na, pa = core_parts(a)
    local nb, pb = core_parts(b)
    for i = 1, math.max(#na, #nb) do
        local x, y = na[i] or 0, nb[i] or 0
        if x ~= y then
            return x < y
        end
    end
    return cmp_pre(pa, pb) < 0
end

--- Sort version cores ascending (oldest -> newest). Sorts in place and returns it.
--- @param versions string[]
--- @return string[]
function stream.sort_asc(versions)
    table.sort(versions, less)
    return versions
end

return stream
