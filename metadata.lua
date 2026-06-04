-- metadata.lua
-- The `skillrig` mise backend plugin.
-- Docs: https://mise.jdx.dev/backend-plugin-development.html
--
-- Co-installs many backing CLIs from ONE skillrig origin monorepo as N distinct
-- mise tools, addressed `skillrig:<owner>/<repo>/<bin>`. Each binary tracks its
-- own release stream, encoded in semver BUILD METADATA (`<semver>+<bin>`, e.g.
-- `1.7.0+jira`) -- a scheme native mise cannot resolve because SemVer precedence
-- ignores build metadata. This plugin owns version listing, so it can.

PLUGIN = { -- luacheck: ignore
    name = "skillrig",
    version = "0.1.0",
    description = "Install a skillrig origin's backing CLIs as independently-versioned mise tools",
    author = "skillrig",
    homepage = "https://github.com/skillrig/mise-skillrig",
    license = "MIT",
    notes = {
        "Address tools as `skillrig:<owner>/<repo>/<bin>` (e.g. skillrig:my-org/my-skills/jira).",
        "Private origins need a GitHub token: export MISE_GITHUB_TOKEN=$(gh auth token).",
    },
}
