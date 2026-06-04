--- Tool-address parsing for the skillrig backend.
---
--- A consumer addresses a backing CLI as `skillrig:<owner>/<repo>/<bin>`, so
--- `ctx.tool` arrives as `<owner>/<repo>/<bin>` (three+ `/`-separated segments).
--- The trailing segment is the binary; everything before it is the origin repo
--- in GitHub `owner/repo` grammar. As a convenience, a bare `ctx.tool` (no `/`)
--- is also accepted when the origin is supplied out-of-band via the per-tool
--- `origin` option or the `SKILLRIG_ORIGIN` env var.
---
--- This module is PURE (no I/O) so it is unit-testable offline; pass a plain
--- table `{ tool = ..., options = ... }` in tests.

local address = {}

-- `owner/repo` grammar (mirrors skillrig/cli internal/config/origin.go).
local OWNER_REPO = "^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$"
-- Binary name grammar; keeps a tool name out of shell commands / asset paths if
-- it carries whitespace or unexpected characters.
local BIN = "^[A-Za-z0-9._-]+$"

-- "." / ".." would manipulate the GitHub API URL path.
local function is_dot(s)
    return s == "." or s == ".."
end

--- Split "a/b/c/bin" into origin "a/b/c" and bin "bin".
--- @param tool string
--- @return string|nil origin, string|nil bin
local function split_last(tool)
    local origin, bin = tool:match("^(.+)/([^/]+)$")
    return origin, bin
end

--- Parse a backend context into its origin coordinate + binary name.
--- @param ctx table { tool: string, options?: table }
--- @return table { owner, repo, bin, origin, ref }
function address.parse(ctx)
    local tool = ctx and ctx.tool
    if not tool or tool == "" then
        error("skillrig: tool name cannot be empty")
    end

    local options = (ctx and ctx.options) or {}
    local origin, bin

    if tool:find("/", 1, true) then
        -- Embedded-origin form: <owner>/<repo>[/...]/<bin>
        origin, bin = split_last(tool)
    else
        -- Bare-tool form: origin comes from options/env.
        bin = tool
        origin = options.origin or os.getenv("SKILLRIG_ORIGIN")
    end

    if not origin or origin == "" then
        error(
            "skillrig: no origin for tool '"
                .. tool
                .. "'. Address it as `skillrig:<owner>/<repo>/"
                .. tool
                .. "`, or set the per-tool `origin` option / SKILLRIG_ORIGIN env."
        )
    end

    if not origin:match(OWNER_REPO) then
        error("skillrig: origin '" .. origin .. "' is not OWNER/REPO (got from tool '" .. tool .. "')")
    end

    if not bin or bin == "" then
        error("skillrig: could not parse a binary name from tool '" .. tool .. "'")
    end
    if is_dot(bin) or not bin:match(BIN) then
        error("skillrig: invalid binary name '" .. bin .. "' (expected [A-Za-z0-9._-], not '.'/'..')")
    end

    local owner, repo = origin:match("^([^/]+)/([^/]+)$")
    if is_dot(owner) or is_dot(repo) then
        error("skillrig: origin '" .. origin .. "' must not contain '.' or '..' segments")
    end
    return {
        owner = owner,
        repo = repo,
        origin = origin,
        bin = bin,
        ref = options.ref, -- optional; only used for origin metadata reads
    }
end

return address
