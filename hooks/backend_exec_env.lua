--- BackendExecEnv: put the installed binary's dir on PATH. BackendInstall
--- normalizes every tool into install_path/bin/<bin>, so this stays trivial.
--- Docs: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv
local file = require("file")

function PLUGIN:BackendExecEnv(ctx)
    return {
        env_vars = {
            { key = "PATH", value = file.join_path(ctx.install_path, "bin") },
        },
    }
end
