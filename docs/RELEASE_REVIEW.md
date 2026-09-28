# Cleanup review — 0.5.9 preview

| Finding | Resolution |
| --- | --- |
| Retired `/jah native`, manual `/jah button`, undocumented `/jah read ID` | Removed from the player dispatcher and help. |
| Native opener no-op and reading-probe shim | Removed; native opening stays Blizzard-owned. |
| Probe frame name, prototype messages and stale feedback comment | Replaced with current control names and behavior. |
| Separate Start and Restore controls | One Start / Restore / Retry restoration control, disabled in combat. |
| Stale status notes after reload | Runtime notes reset; preferences, recovery and restriction evidence remain. |
| Constructing a status report opens an empty reader | Reader starts hidden and opens only for requested content. |
| Old design/prototype acceptance instructions | Current design and client checklist replace them; history remains in API_FINDINGS.md. |
| Separate diagnostics, captures and developer artifacts | Kept outside the player ZIP; diagnostics have an independent package. |

Retain `/jah status` for support and `/jah clear` as a documented way to clear assistance. Native observer, fallback reader, region hit query, restriction monitoring and restoration snapshots remain necessary runtime behavior. A region query is not an orphaned diagnostic probe: it chooses the authorized region/point presentation.

Do not erase old SavedVariables wholesale or delete rollback backups during cleanup. They contain recovery and evidence. The 0.5.5 cross-zone experiment is retired from runtime; its historical notes remain useful provenance. Prior release notes and candidate artifacts are version history, not shipped player functionality.

The candidate remains a preview for Forever 1.60.1 / build 70009 / interface 16001. Full automated checks gate preparation; inspect RELEASE_NOTES.md for pending native checks. Hosted CI is prepared but not run here, and publication is a separate step.

## 0.6.0 superseding scope

The user removes the previously retained standalone reader. QuestReader.lua, TrackerIntegration.lua and prose-reader adapter functions are deleted from the player package. Reader-mode preferences and UI are retired; SettingsPanel and StatusReport are independent addon-owned dialogs. NativeHintMarkers provides read-only observation with noninteractive overlays on the native quest list/tracker. There is no fallback quest reader and no click-handler replacement. Older rows above describe the 0.5.9 review, not retained 0.6.0 runtime behavior. Native placement remains pending client verification.
