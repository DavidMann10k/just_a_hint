# Prepare a preview candidate

Candidate preparation is local and does not install, tag, push or publish anything. Use Python 3.11+ and Lua 5.1/LuaJIT. A game installation is not required.

1. Match the version in the addon's TOC template and Core.lua.
2. Add `docs/releases/ADDON-VERSION.json` and its Markdown release notes. The profile records the target interface, observed client and pending native checks. This pipeline currently accepts previews with partial native validation only.
3. Update player instructions and the changelog; distinguish client observations from fixture tests. Keep private paths and raw captures out of public files.
4. Run:

```text
python dev.py release --version 0.7.4 --interface 16001
```

The interface must agree with the profile. Explicit flags, JAH_INTERFACE or configured interface are accepted; release preparation does not discover a game or infer an unverified target. The command requires all Python and Lua checks to pass, then builds the runtime archive and a reproducible source archive.

Outputs live under `dist/releases/JustAHint-0.7.4-interface16001/`:

| Asset | Purpose |
| --- | --- |
| JustAHint.zip | Installable addon and license. |
| JustAHint.manifest.json | Runtime file hashes, version and target interface. |
| JustAHint.sha256 | Runtime ZIP checksum. |
| JustAHint-0.7.4-source.zip | Public source, tests, tools and docs. |
| INSTALL.md / RELEASE_NOTES.md | Player instructions and known limitations. |
| RELEASE.json | Target and verification record. |
| SHA256SUMS | Checksums for every other candidate asset. |

Text, ZIP ordering, timestamps and permissions normalize across platforms. Local config, saved client data, .jah, .git, editor metadata and dist are excluded from the source archive. Repeating an identical preparation returns the same candidate; differing contents under the same version are refused. Use a new version, or explicitly remove an unpublished local candidate before revising it. Published assets should remain immutable.

On systems with `sha256sum`, run `sha256sum -c SHA256SUMS` from the candidate folder. Windows PowerShell provides `Get-FileHash -Algorithm SHA256`; compare its output to the corresponding entry. Checksums establish integrity, not publisher identity.

## Hosted workflow

`.github/workflows/prepare-release.yml` provides a manually dispatched GitHub Actions job. It runs the same full pipeline on Linux and uploads the candidate as a workflow artifact. It has read-only repository permissions and does not create a public release. The validation workflow separately exercises Python tooling and fixture builds on Windows, macOS and Linux, and Lua behavior on Linux.

These workflow files are prepared locally. Hosted results require an actual GitHub repository and a completed run; do not report them as passed merely because the YAML exists. CI's fictional interface 999999 artifacts are test fixtures, not game packages.

## Before publishing

Review the candidate's notes and checksums, and record remaining playtest cases honestly. Verify native behavior on the exact supported build. Publication is a separate deliberate action; the current preview remains partially verified. Consult [the client test plan](CLIENT_TEST_PLAN.md) and [API findings](../API_FINDINGS.md).

After reviewing the candidate and passing the validation workflow for its commit, deliberately create and push its matching `vVERSION` tag. `.github/workflows/publish-preview.yml` runs the full local pipeline again on that tagged commit, verifies all candidate checksums, uploads the complete bundle to a draft GitHub prerelease, and publishes it only after uploads succeed. The workflow uses GitHub's supplied token; local GitHub CLI sign-in is not required. Local `dev.py release` remains preparation only.

For example, the 0.7.4 publication tag is `v0.7.4`. Published assets remain immutable; do not move an existing release tag or replace published assets. A release in a private repository is available only to people with repository access. Repository visibility is managed separately from publication.
