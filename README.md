# mise-skillrig

A [mise](https://mise.jdx.dev) **backend plugin** that installs a
[skillrig](https://github.com/skillrig) origin's backing CLIs as
**independently-versioned mise tools** — addressed `skillrig:<owner>/<repo>/<bin>`.

```toml
# consumer mise.toml — each backing CLI co-installs as its own tool
"skillrig:my-org/my-skills/jira"   = "latest"   # -> jira 1.7.0
"skillrig:my-org/my-skills/tfc"    = "0.0.6"
"skillrig:my-org/my-skills/awsinv" = "latest"
```

## Why a plugin (and not the stock `github` backend)

A skillrig origin is a **co-located monorepo**: one repo ships an org's agent
skills *and* the private CLIs those skills require, each released on its own
version stream. mise's stock `github` backend keys a tool by `owner/repo` and
tracks **one** version per repo, so N tool entries from one repo **collapse into
one install** — you cannot co-install more than one binary from a monorepo
([details](#background)).

A backend plugin's tool identity is `plugin:tool`, not `owner/repo`, so N
binaries from one repo become N **distinct** tools. And because this plugin owns
version **listing** (`BackendListVersions`), it can resolve release streams that
native mise structurally cannot — see [tag schemes](#tag-schemes).

## Install

Requires **mise ≥ 2026.4.12**.

Custom backends are gated behind mise's experimental flag, so enable it once:

```sh
mise settings experimental=true        # or: export MISE_EXPERIMENTAL=1
```

Then install the plugin (public repo — no auth needed for the plugin itself):

```sh
mise plugin install skillrig https://github.com/skillrig/mise-skillrig
# pin a version:  ...mise-skillrig#v0.1.0
# update later:   mise plugin update skillrig
```

The name you install it as (`skillrig`) is the backend string you then address
tools with (`skillrig:…`).

## Addressing tools

```
skillrig:<owner>/<repo>/<bin>[@<version>]
```

- `<owner>/<repo>` is the GitHub **coordinate** of the origin (where releases are
  fetched from). It is taken from the address, **not** from any `origin` field
  inside the repo — that field is an identity label and may legitimately differ
  from the hosting coordinate (templates, forks, mirrors).
- `<bin>` is the backing CLI (the binary name).

A bare `skillrig:<bin>` form also works if you supply the coordinate out of band:

```toml
[tools."skillrig:jira"]
version = "latest"
origin  = "my-org/my-skills"   # or set SKILLRIG_ORIGIN in the environment
```

## Auth (private origins)

mise resolves a GitHub token via `MISE_GITHUB_TOKEN` → `GITHUB_API_TOKEN` →
`GITHUB_TOKEN` → `credential_command` → `gh`. mise **cannot** read a `gh` token
stored in the OS keyring (the common macOS case), so for a private origin set one
explicitly:

```sh
export MISE_GITHUB_TOKEN=$(gh auth token)
```

The plugin adds no new credential surface; it only reads a token to authenticate
GitHub API + asset downloads.

## How it resolves a tool

Driven by the skillrig origin-template's **goreleaser convention** (no per-consumer
config, no `asset_pattern` boilerplate):

| Step | Source |
|---|---|
| versions | repo tags belonging to the binary's stream (see below) |
| release  | GitHub release for the resolved tag |
| asset    | `<bin>_<version>_<os>_<arch>.tar.gz` |
| checksum | per-tool `<bin>_checksums.txt` (sha256, **verified** — mise does not verify custom backends) |
| PATH     | the extracted binary, normalized to `<install>/bin/<bin>` |

It also performs a best-effort **convention-version gate**: if the origin
publishes an `index.json`, its `skillrigConvention` must be one this plugin
understands (currently `1`); the `origin` *name* is never checked.

### Tag schemes

A binary's stream is selected from the repo's tags by either scheme:

- **build-metadata** (active on strict-semver origins): `<core>+<bin>` — e.g.
  `1.7.0+jira`. SemVer 2.0.0 says build metadata is ignored for precedence, so
  native mise collapses these; this plugin filters on the `+<bin>` suffix.
- **prefix**: `<bin>-v<core>` — e.g. `jira-v1.7.0`.

`latest` resolves to the newest version **within the binary's stream**.

## Development

The `test` task needs a standalone Lua 5.x on `PATH` (`brew install lua` or
`apt-get install lua5.4`); or run it through mise with `mise x lua@5.4 -- lua test/run.lua`.
Lua is deliberately not a mise tool here — mise builds it from the often-unreachable
lua.org, so CI installs it from the OS instead.

```sh
mise run test     # offline unit tests (pure logic; no network)
mise run lint     # stylua + lua-language-server + actionlint via hk
mise run ci       # lint + test (what CI runs)
mise run e2e      # live: link plugin, then ls-remote/install/exec a real tool
```

Local plugin testing:

```sh
mise plugin link --force skillrig .
mise cache clear
export MISE_GITHUB_TOKEN=$(gh auth token)
mise ls-remote skillrig:my-org/my-skills/tfc
```

## Background

This plugin is the implementation of skillrig's "declare + verify, mise installs"
contract for backing CLIs. Design references:
[RFC 0001](https://github.com/skillrig/cli/blob/main/docs/rfcs/0001-mise-skillrig-backend.md)
and the origin-side `docs/BINARY-DISTRIBUTION.md`. v1 is checksum-only;
treeSha/attestation binding is a planned follow-up.

## License

MIT
