# org-plugins — packaging Claude org plugins into a macOS `.pkg`

A worked example of how an org admin bundles a set of [organization plugins](https://claude.com/docs/cowork/3p/extensions#organization-plugins-admin)
for Cowork (3P) and ships them to a fleet of Macs as a single signed installer.

The fictional **Acme Corp** ships two plugins:

| Plugin | `installationPreference` | What it adds |
|---|---|---|
| [`acme-security-review`](./acme-security-review) | `required` | A `/acme-secreview` command, a `security-reviewer` subagent, and a `PreToolUse` hook that blocks agents from writing to secrets files. |
| [`acme-handbook`](./acme-handbook) | `auto_install` | Two skills (coding standards, incident runbook) and a read-only `acme-vault` MCP server for fetching approved config at runtime. |

## Layout

Each plugin is a directory at the root of this folder. `build-pkg.sh` lives
alongside them and is **not** packaged — the build only picks up directories that
contain `.claude-plugin/plugin.json`.

```
org-plugins/
├── build-pkg.sh                 # the installer builder (not packaged)
├── acme-security-review/
│   ├── .claude-plugin/plugin.json
│   ├── version.json
│   ├── agents/security-reviewer.md
│   ├── commands/acme-secreview.md
│   └── hooks/{hooks.json,block-secrets-write.sh}
└── acme-handbook/
    ├── .claude-plugin/plugin.json
    ├── version.json
    ├── .mcp.json
    └── skills/{coding-standards,incident-runbook}/SKILL.md
```

Each plugin **must** contain `.claude-plugin/plugin.json` or Cowork ignores the
directory. `version.json` lets Cowork detect updates and re-sync on next launch.

## Build the installer

> Requires macOS with the Xcode Command Line Tools (`pkgbuild`, `productsign`, `ditto`).

```bash
# Unsigned, version inferred from git tag or today's date
./build-pkg.sh

# Pin a version
VERSION=1.2.0 ./build-pkg.sh

# Sign for distribution (then notarize separately)
SIGN_IDENTITY="Developer ID Installer: Acme Corp (TEAMID)" ./build-pkg.sh
```

The script stages each plugin into the system location Cowork scans —
`/Library/Application Support/Claude/org-plugins/<plugin>/` — strips macOS
resource-fork cruft (`ditto --noextattr --norsrc`, so `pkgbuild` doesn't
synthesize `._*` AppleDouble files), then runs `pkgbuild`. Output lands in
`dist/acme-org-plugins-<version>.pkg`.

## Install / distribute

```bash
# Local test install (writes under /Library — needs sudo)
sudo installer -pkg dist/acme-org-plugins-1.0.0.pkg -target /

# Inspect the payload
pkgutil --payload-files dist/acme-org-plugins-1.0.0.pkg
```

> Note: `pkgutil --payload-files` lists raw cpio members, which include `._*`
> AppleDouble *headers*. These are not extracted as real files — `installer`
> merges them back into POSIX metadata. The installed tree is clean.

For a fleet, upload the `.pkg` to your MDM (Jamf, Kandji, Intune for Mac) as a
managed install. To roll out an update: change plugin contents, bump the
`version` in both `plugin.json` and `version.json`, rebuild, and re-deploy —
Cowork re-syncs on next launch. `installationPreference` decides activation:
`required` and `auto_install` activate without user action; `available` waits for
the user to enable it.
