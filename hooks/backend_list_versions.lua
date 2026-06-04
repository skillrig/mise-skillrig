--- BackendListVersions: the load-bearing hook.
--- Owns version listing, which is exactly why native mise can't consume
--- build-metadata streams. Lists the origin's tags, keeps only those belonging
--- to this binary's stream, and returns clean semver cores ascending.
--- Docs: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions
local address = require("lib/address")
local stream = require("lib/stream")
local github = require("lib/github")
local origin = require("lib/origin")

function PLUGIN:BackendListVersions(ctx)
    local a = address.parse(ctx)
    -- Best-effort convention gate (we check skillrigConvention, NOT the origin
    -- name, which is an identity label that may differ from the coordinate).
    origin.assert_supported(github.get_index(a.owner, a.repo, a.ref))
    local tags = github.list_tags(a.owner, a.repo)
    local versions = stream.stream_versions(tags, a.bin)
    stream.sort_asc(versions)
    return { versions = versions }
end
