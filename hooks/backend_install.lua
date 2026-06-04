--- BackendInstall: resolve the stream tag, download the asset, checksum-verify
--- (mise does NOT verify for custom backends), extract, and normalize the
--- executable into install_path/bin/<bin>.
--- Docs: https://mise.jdx.dev/backend-plugin-development.html#backendinstall
local address = require("lib/address")
local stream = require("lib/stream")
local github = require("lib/github")
local origin = require("lib/origin")
local checksum = require("lib/checksum")
local file = require("file")
local cmd = require("cmd")
local archiver = require("archiver")

local function shquote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function PLUGIN:BackendInstall(ctx)
    local a = address.parse(ctx)
    local version = ctx.version
    if not version or version == "" then
        error("skillrig: version cannot be empty")
    end
    local install_path = ctx.install_path
    if not install_path or install_path == "" then
        error("skillrig: install_path cannot be empty")
    end

    -- Where to stage downloads. Prefer mise's download_path; otherwise a temp
    -- subdir we clean up (it never holds the final binary).
    local download_path, cleanup = ctx.download_path, false
    if not download_path or download_path == "" then
        download_path = file.join_path(install_path, ".skillrig-dl")
        cleanup = true
    end
    cmd.exec("mkdir -p " .. shquote(download_path))

    -- Best-effort convention gate (skillrigConvention only; origin name ignored).
    origin.assert_supported(github.get_index(a.owner, a.repo, a.ref))

    -- Resolve the exact tag for this stream + version (no v-prefix/scheme guessing).
    local tags = github.list_tags(a.owner, a.repo)
    local tag = stream.find_tag(tags, a.bin, version)
    if not tag then
        error("skillrig: no release tag for " .. a.bin .. "@" .. version .. " in " .. a.origin)
    end
    local release = github.release_by_tag(a.owner, a.repo, tag)

    -- Pick + download the platform asset.
    local plat = stream.platform()
    local asset_name = stream.asset_name(a.bin, version, plat.os, plat.arch)
    local asset = github.find_asset(release, asset_name)
    if not asset then
        error(
            "skillrig: release "
                .. tag
                .. " has no asset "
                .. asset_name
                .. " (os="
                .. plat.os
                .. " arch="
                .. plat.arch
                .. ")"
        )
    end
    local archive_path = file.join_path(download_path, asset_name)
    github.download_asset(asset, archive_path)

    -- Checksum-verify against the per-tool checksums file.
    local sums_name = stream.checksums_name(a.bin)
    local sums_asset = github.find_asset(release, sums_name)
    if not sums_asset then
        error("skillrig: release " .. tag .. " has no checksums file " .. sums_name)
    end
    local sums_path = file.join_path(download_path, sums_name)
    github.download_asset(sums_asset, sums_path)
    local sums_text = file.read(sums_path)
    if not sums_text or sums_text == "" then
        error("skillrig: could not read downloaded checksums file " .. sums_name)
    end
    local ok, msg = checksum.verify_hash(sums_text, asset_name, checksum.sha256_file(archive_path))
    if not ok then
        error("skillrig: " .. msg)
    end

    -- Extract, then ensure install_path/bin/<bin> exists and is executable.
    cmd.exec("mkdir -p " .. shquote(install_path))
    local xerr = archiver.decompress(archive_path, install_path)
    if xerr then
        error("skillrig: failed to extract " .. asset_name .. ": " .. tostring(xerr))
    end

    local bin_dir = file.join_path(install_path, "bin")
    local target = file.join_path(bin_dir, a.bin)
    if not file.exists(target) then
        cmd.exec("mkdir -p " .. shquote(bin_dir))
        -- Common goreleaser layout: the binary sits at the archive root.
        local root = file.join_path(install_path, a.bin)
        local found = file.exists(root) and root or nil
        if not found then
            -- Otherwise locate it (one deterministic match; -print -quit avoids a
            -- pipe + SIGPIPE, which cmd.exec would surface as a nonzero exit).
            local out =
                cmd.exec("find " .. shquote(install_path) .. " -type f -name " .. shquote(a.bin) .. " -print -quit")
            out = (out or ""):gsub("%s+$", "")
            if out ~= "" then
                found = out
            end
        end
        if not found then
            error("skillrig: extracted archive contains no executable named '" .. a.bin .. "'")
        end
        if found ~= target then
            cmd.exec("mv " .. shquote(found) .. " " .. shquote(target))
        end
    end
    cmd.exec("chmod +x " .. shquote(target))

    if cleanup then
        cmd.exec("rm -rf " .. shquote(download_path))
    end
    return {}
end
