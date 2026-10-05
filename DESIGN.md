# Just a Hint — current design

Just a Hint is a restrained quest tracker: more specific hints as you get closer, but only when you ask. Its purpose is to keep your brain engaged with, and immersed in, the game world.

Reading a quest is not a request for navigation. Getting close is not a request for a more detailed hint. Only an explicit Hint request authorizes disclosure; arrival removes assistance.

## Reading and controls

Just a Hint activates on login by default. It hides Blizzard's objective tracker and suppresses automatic navigation, map objectives and minimap quest markers. Blizzard's Map & Quest Log remains the quest reader; the addon attaches Hint below Track/Untrack in confirmed native details. Acceptance, reading and hover produce no guidance. Cross-map destinations omit Hint.

Startup loads native map and tracker modules without opening or selecting a quest. Missing controls defer activation until a later load/world event; combat defers activation until combat ends. An existing saved opt-out or unfinished restoration remains disabled. `/jah` opens Settings. Gold hint markers identify the current request in the native quest list.

NativeTracker reparents the objective tracker under an addon-owned hidden frame outside combat. This keeps native Show calls invisible during combat while preserving handlers, events, anchors and the tracker's own shown state. The hidden parent retains UIParent dimensions. Restoration returns the original parent unless another addon has taken ownership. Parent snapshots are session-local; reload reconstructs native frames. Failed restoration retains the snapshot for retry.

Native details use Hint/Clear Hint as one toggle. Clear appears only for the displayed quest's currently visible owned guidance with ready data. Missing usable destinations omit Hint; explicit uncached data disables it as loading. Passive availability refresh never requests assistance. One activation control shows Start Just a Hint, Restore Blizzard guidance or Retry restoration. Combat disables it, and the service independently refuses combat mutations. Failed restoration must be retried before a new activation; other characters' saved recovery does not block this character.

## Hint policy

| Situation | Behavior |
| --- | --- |
| Accept, read or hover | No guidance. |
| Hint far away on the current map | One minimap-rim bearing; no destination pin or route. |
| Arrival | Arrow disappears; nothing replaces it. Walking away cannot restart it. |
| Hint nearby, including the first request | Native search area, or a built-in marker at the native coordinate if a region is unconfirmed. |
| Read B while A has guidance | Preserve A; disclose nothing for B. |
| Hint for B | Replace A, including when B's data is unavailable. |
| Ordinary count progress | Preserve the request. |
| New stage, completion, removal, zoning, reload or restoration | Clear; no next objective or turn-in hint starts. |
| Completed quest awaiting turn-in | Eligible for a new explicit request if current native destination data is useful. |
| Close or change an area/marker map | Clear; reopening stays quiet. |

Initial arrival tuning is 150 native world units for one continuous second. Game-yard equivalence is unverified. Missing position/heading, clock discontinuities and long update stalls cannot count as continuous arrival. Minimap rotation updates every frame; quest/position validation is throttled separately.

A bounded matching-quest hit query confirms a native region. It cannot prove absence: a small or loading region can yield a point fallback. No substitute polygon or circle is manufactured, and the native point does not promise an exact NPC position. Cross-map or ambiguous native destinations are unavailable. A map-indicator/entrance is not silently treated as a local objective.

## Feedback and persistence

An explicitly rendered bearing can close the native map and produce an optional arrow flight from screen center to its minimap-rim position, followed by optional arrow/minimap pulses, sound and plain chat direction with a broad distance phrase. The built-in arrow grows briefly, follows an eased arc with a short trail, shrinks and turns into the live minimap bearing in about one second. An addon-owned, noninteractive overlay follows the minimap's position, effective scale and current bearing. The ordinary arrow is hidden only during flight, and restored on landing, cancellation or animation failure. Flight can be disabled independently of pulses; interruption or a long frame stall ends feedback without replay. No countdown or yard claim is added. Nearby requests use chat: “You're close. Search around here.” for a confirmed region, or “You're close. Look around the marked spot.” for a point. No captions below the map remain. Reading, arrival, redraws, ordinary progress and clearing produce no new feedback. Duplicate chat messages are suppressed for ten seconds.

Persist activation, feedback settings and guidance-restoration snapshots. Hints and animation state remain session-local. Restore returns the native tracker and saved map/minimap settings, persists the opt-out and retains failed writes for retry. Other characters restore their minimap snapshots on login. `/jah start` explicitly re-enables the addon.

## Architecture and development

ClientAdapter normalizes guidance preferences; HintData normalizes quest progress, native destinations and comparable positions. RegionHints samples native geometry only for explicit requests on an invisible frame; it selects the nearest confirmed interior point and retains all samples for arrival, with a direct player-position hit query. Samples are approximate, and misses use the existing native point fallback. The selected region point stays fixed until clearing. HintController owns proximity and arrival policy without a client dependency. Hints validates lifecycle and owns a single request. QuestArea, MinimapBearing and HintFeedback render only that request. NativeQuestPane observes native UI; NativeHintMarkers owns status overlays; SettingsPanel and StatusReport own settings/support dialogs. GuidanceGuard applies and restores scoped guidance controls.

Player commands are `/jah`, `settings`, `start`, `restore`, `clear` and `status`. Developer experiments use the separate JustAHintDiagnostics addon.

The Python-standard-library pipeline builds deterministic runtime/source archives, validates hashes, installs one addon with rollback backups and prepares local preview candidates. No backend, API key, mandatory quest database, Questie/TomTom dependency or AI model is involved. Routes, automatic quest selection/acceptance/turn-in, exact-target escalation and broad client support are outside this version.

See [client checks](docs/CLIENT_TEST_PLAN.md), [API findings](API_FINDINGS.md) and [release review](docs/RELEASE_REVIEW.md). Native observations establish only the tested build and cases; fixtures cannot prove protected-action safety, rendering or destination usefulness.
