--- sha256 verification against the origin's per-tool `<bin>_checksums.txt`.
--- mise does NOT checksum-verify for custom backends, so the plugin must.
---
--- parse/expected/verify_hash are PURE (offline-testable). sha256_file shells
--- out (lazy `require("cmd")`) and tolerates Linux `sha256sum` vs macOS
--- `shasum -a 256`.

local checksum = {}

--- Parse a checksums file body into { [filename] = lowercase_hash }.
--- Accepts `<hash>  <file>`, `<hash> <file>`, and the `*<file>` binary marker.
--- @param text string
--- @return table<string,string>
function checksum.parse(text)
    local out = {}
    for line in text:gmatch("[^\r\n]+") do
        local hash, name = line:match("^(%x+)%s+%*?(.-)%s*$")
        if hash and name and name ~= "" then
            out[name] = hash:lower()
        end
    end
    return out
end

--- Expected hash for a file name, or nil.
function checksum.expected(text, name)
    return checksum.parse(text)[name]
end

--- Pure verification: compare an already-computed hash to the file's entry.
--- @return boolean ok, string|nil message
function checksum.verify_hash(text, name, actual)
    local expected = checksum.expected(text, name)
    if not expected then
        return false, "no checksum entry for " .. name
    end
    if expected:lower() ~= (actual or ""):lower() then
        return false,
            "checksum mismatch for " .. name .. " (expected " .. expected .. ", got " .. tostring(actual) .. ")"
    end
    return true
end

local function shquote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

--- Compute a file's sha256 (lowercase hex) via sha256sum or shasum -a 256.
--- @param path string
--- @return string
function checksum.sha256_file(path)
    local cmd = require("cmd")
    local p = shquote(path)
    local out
    local ok = pcall(function()
        out = cmd.exec("sha256sum " .. p)
    end)
    if not ok or not out or out == "" then
        ok = pcall(function()
            out = cmd.exec("shasum -a 256 " .. p)
        end)
    end
    if not ok or not out then
        error("skillrig: neither `sha256sum` nor `shasum` is available to verify " .. path)
    end
    local hash = out:match("^(%x+)")
    if not hash then
        error("skillrig: could not parse a sha256 from checksum tool output: " .. out)
    end
    return hash:lower()
end

return checksum
