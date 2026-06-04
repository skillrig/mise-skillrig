--- Origin convention gating.
---
--- IMPORTANT design choice: the plugin resolves a binary from the GitHub
--- COORDINATE in the tool address (`skillrig:<owner>/<repo>/<bin>`), NOT from
--- the `origin` field inside `.skillrig-origin.toml` / `index.json`. That field
--- is an IDENTITY label (what a consumer records in its lockfile) and can
--- legitimately differ from where the repo is hosted -- e.g. a template not yet
--- renamed (`foo-org-sports/local-devops-scripts`) served from
--- `so0k/skillrig-origin-demo`, or a fork/mirror. So we deliberately do NOT
--- assert `origin == coordinate`.
---
--- What we DO verify is the CONVENTION VERSION: a structural-contract number the
--- plugin understands (skillrig architecture R5e -- "fail clearly against an
--- incompatible origin rather than mis-resolving"). PURE + offline-testable.

local origin = {}

-- Convention numbers this plugin's tag/asset/checksum conventions implement.
origin.SUPPORTED = { [1] = true }

--- Assert the origin's published convention is one we understand.
--- @param index table|nil decoded index.json (nil/absent -> tolerated, no-op)
function origin.assert_supported(index)
    if type(index) ~= "table" then
        return -- no index to check; tags remain the source of truth
    end
    local conv = index.skillrigConvention
    if conv == nil then
        return -- index without the field: tolerate (older/partial origin)
    end
    if not origin.SUPPORTED[conv] then
        local supported = {}
        for k in pairs(origin.SUPPORTED) do
            supported[#supported + 1] = tostring(k)
        end
        table.sort(supported)
        error(
            "skillrig: origin convention "
                .. tostring(conv)
                .. " is not supported by this plugin (supports: "
                .. table.concat(supported, ", ")
                .. "). Upgrade the mise-skillrig plugin."
        )
    end
end

return origin
