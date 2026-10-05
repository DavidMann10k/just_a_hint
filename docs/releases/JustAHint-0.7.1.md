# Just a Hint 0.7.1 preview

Target: Forever beta 1.60.1 / build 70205 / interface 16001. Native validation remains partial.

## Requested arrow animation

A successful far-away Hint now reveals a large gold arrow at screen center. It grows briefly, sweeps along a curved path with a short trail, shrinks and turns into the live minimap bearing in about one second. Enabled gold arrow/minimap ripples follow its landing. The flight follows current bearing and minimap geometry, uses built-in artwork and accepts no mouse input.

The new **Fly the requested arrow to the minimap** setting is enabled by default. Disable it for an immediate minimap arrow. Chat, sound and each pulse remain independent. Cancellation or unavailable animation geometry restores the ordinary bearing without replaying feedback. Reading, arrival and clearing start no animation; nearby area/point requests retain chat-only feedback.

The region-aware request, point fallback, sticky arrival and native Hint/Clear Hint behavior from 0.7.0 are retained.

## Evidence and limits

On 2026-10-05 the tester confirmed **“animation is good.”** This is a positive native observation for the installed animation update. The local client installation identifies build 70205; no paired GetBuildInfo capture, quest/stage or UI/minimap scale was supplied. Earlier quest-playtest observations were recorded on build 70009. These observations do not establish complete final-build compatibility.

Automated validation covers tooling, Lua 5.1 behavior, animation trajectory and handoff, moved/scaled minimaps, independent settings, cancellation and renderer failures. Fixtures do not execute Blizzard's renderer or prove secure-action compatibility.

Remaining native checks include animation interruption and unusual scales/positions; region loading and nearest-site usefulness; arrival at alternative sites and fresh-session availability; tracker/list ownership markers and quest items; combat, zoning and broader maps; turn-in usefulness; and final settings, reload and restoration regressions. Region samples remain approximate and can miss small/loading regions; a point fallback does not prove that a region is absent.

## Install or update

Install `JustAHint.zip` using the bundled `INSTALL.md`. Updating from 0.7.0 does not change the runtime file list: after replacing the installed files, `/reload` loads this update. First installation or an update from 0.6.0 or earlier requires a full client restart.

Run `/jah start` out of combat, read quests in Blizzard's normal Map & Quest Log and request Hint when wanted. `/jah` opens Settings; `/jah status` supplies a support report. Before disabling or uninstalling, run `/jah restore` out of combat on each activated character and retry any restoration failure.
