--- Authenticated GitHub API access for the skillrig backend.
---
--- Token resolution mirrors mise's own github precedence (env first), so a
--- private origin works once `MISE_GITHUB_TOKEN`/`GITHUB_TOKEN` is set (the
--- documented keyring-404 fix: `export MISE_GITHUB_TOKEN=$(gh auth token)`).
--- We set the Authorization header explicitly rather than relying on mise's
--- auto-injection, so private `/tags`, `/releases`, and asset downloads all
--- authenticate deterministically.
---
--- I/O module: loaded by hooks at runtime (requires mise's http/json), never by
--- the offline unit tests.

local http = require("http")
local json = require("json")

local github = {}

local API = "https://api.github.com"

local function token()
    return os.getenv("MISE_GITHUB_TOKEN") or os.getenv("GITHUB_API_TOKEN") or os.getenv("GITHUB_TOKEN")
end

--- Standard headers; `accept` overrides the default JSON Accept (e.g. octet-stream for assets).
local function headers(accept)
    local h = {
        ["Accept"] = accept or "application/vnd.github+json",
        ["User-Agent"] = "mise-skillrig",
        ["X-GitHub-Api-Version"] = "2022-11-28",
    }
    local t = token()
    if t and t ~= "" then
        h["Authorization"] = "Bearer " .. t
    end
    return h
end

local function get_json(url)
    local resp, err = http.get({ url = url, headers = headers() })
    if err then
        error("skillrig: GET " .. url .. " failed: " .. tostring(err))
    end
    if resp.status_code == 404 then
        error(
            "skillrig: 404 from "
                .. url
                .. " -- private origin without a token? export MISE_GITHUB_TOKEN=$(gh auth token)"
        )
    end
    if resp.status_code < 200 or resp.status_code >= 300 then
        error("skillrig: GitHub returned status " .. tostring(resp.status_code) .. " for " .. url)
    end
    local ok, data = pcall(json.decode, resp.body)
    if not ok then
        error("skillrig: could not parse JSON from " .. url)
    end
    return data
end

--- List every tag name in the repo (paginated). Caps at 10 pages (1000 tags).
--- @return string[]
function github.list_tags(owner, repo)
    local names = {}
    local PER_PAGE, MAX_PAGES = 100, 10
    for page = 1, MAX_PAGES do
        local url = API .. "/repos/" .. owner .. "/" .. repo .. "/tags?per_page=" .. PER_PAGE .. "&page=" .. page
        local data = get_json(url)
        if type(data) ~= "table" or #data == 0 then
            break
        end
        for _, t in ipairs(data) do
            names[#names + 1] = t.name
        end
        if #data < PER_PAGE then
            break
        end
        if page == MAX_PAGES then
            print(
                "skillrig: tag listing hit the " .. (PER_PAGE * MAX_PAGES) .. "-tag cap; older versions may be omitted"
            )
        end
    end
    return names
end

-- Percent-encode the bits of a tag that break a URL path. `+` is the important
-- one (build-metadata streams); `.`/`-`/alnum are path-safe.
local function encode_tag(tag)
    return (tag:gsub("[^%w%.%-_~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

--- Fetch + decode the origin's `index.json` via the contents API (auto-uses the
--- default branch when `ref` is nil; carries auth for private repos). Returns
--- the decoded table, or nil if the origin publishes no index (404). Network/
--- auth errors other than 404 propagate.
--- @return table|nil
function github.get_index(owner, repo, ref)
    local url = API .. "/repos/" .. owner .. "/" .. repo .. "/contents/index.json"
    if ref and ref ~= "" then
        url = url .. "?ref=" .. encode_tag(ref)
    end
    local resp, err = http.get({ url = url, headers = headers("application/vnd.github.raw") })
    if err then
        error("skillrig: GET " .. url .. " failed: " .. tostring(err))
    end
    if resp.status_code == 404 then
        return nil
    end
    if resp.status_code < 200 or resp.status_code >= 300 then
        error("skillrig: GitHub returned status " .. tostring(resp.status_code) .. " for " .. url)
    end
    local ok, data = pcall(json.decode, resp.body)
    if not ok then
        error("skillrig: could not parse index.json from " .. url)
    end
    return data
end

--- Fetch a release by its exact tag name.
function github.release_by_tag(owner, repo, tag)
    local url = API .. "/repos/" .. owner .. "/" .. repo .. "/releases/tags/" .. encode_tag(tag)
    return get_json(url)
end

--- Find an asset by exact file name in a release object.
function github.find_asset(release, name)
    for _, a in ipairs(release.assets or {}) do
        if a.name == name then
            return a
        end
    end
    return nil
end

--- Download a release asset to `dest`. Uses the asset API URL with an
--- octet-stream Accept so private-repo downloads authenticate and redirect to
--- the signed blob URL correctly.
--- @param asset table the asset object from a release (`.url`, `.name`)
--- @param dest string destination file path
function github.download_asset(asset, dest)
    local err = http.download_file({
        url = asset.url,
        headers = headers("application/octet-stream"),
    }, dest)
    if err then
        error("skillrig: download of " .. asset.name .. " failed: " .. tostring(err))
    end
    return dest
end

return github
