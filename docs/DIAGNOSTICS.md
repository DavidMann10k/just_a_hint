# Diagnostic addon

Enable **Just a Hint: Diagnostics** in the addon list. Start with:

```sh
python dev.py deploy --addon JustAHintDiagnostics
```

The diagnostic remains separate from the reader. Restore the reader's guidance controls before a new normal-versus-disabled diagnostic comparison.

Diagnostic **0.0.7** adds `/jahdiag ui` to inspect the native Map & Quest Log before integrating Hint. With the map open, the command captures known quest-frame paths, visibility, protection, dimensions and selected-quest getters, then opens a short copyable report. It does not select a quest, change settings or request guidance. Missing frames and failed reads are recorded separately; finding a frame does not establish safe integration. This inspection can run with Just a Hint active. See the [native interface checks](CLIENT_TEST_PLAN.md#diagnostic-feasibility).

Diagnostic **0.0.8** adds `/jahdiag button`, an explicit display-only placement experiment. Manually open a quest's native details first, then run the command. It requests a disabled Hint button just below Track/Untrack, anchored from an addon-owned UIParent control; native buttons, rewards, handlers and shared functions remain untouched. It does not open/select quests or request assistance. `/jahdiag clear`, map/detail closure, map changes, combat, quest updates and zoning clear the experiment; it never resumes automatically. `native-button` captures remain visually unverified until inspected. The disabled-button experiment remains in the diagnostic package. The player addon automatically attaches its normal Hint control; retired `/jah button` and `/jah native` commands are absent. Historical integration successes and restrictions are recorded in [API findings](../API_FINDINGS.md).

```text
/jahdiag build
/jahdiag list
/jahdiag scan normal
/reload
```

Then import the actual client captures:

```sh
python dev.py evidence
```

This safely reads JSON carried inside SavedVariables without executing Lua. Raw records and a summary appear in ignored `.jah/evidence.json` and `.jah/feasibility.json`. A successful function call or numeric destination remains distinct from a useful destination or visibly correct area.

For accepted outdoor, delivery, and multiple-objective quests, use IDs from `list`:

```text
/jahdiag probe QUEST_ID normal outdoor
```

Use `delivery` or `multi` for the other categories. To test an area without looking up quest IDs, open the relevant world map and run `/jahdiag area`. The picker reads your current log; click **Show area: quest name** to request that quest's preview. Opening, paging, or refreshing the picker does not draw anything. Picker requests use category `unclassified`; record the quest type as a tester note. `/jahdiag area disabled` selects the disabled-guidance test label without changing game settings.

For a known, currently accepted ID, the explicit command is also available. Compare the map before and during the requested preview, then clear it:

```text
/jahdiag area QUEST_ID normal outdoor
/jahdiag clear
/jahdiag observe AREA_CAPTURE_ID visible only the requested region appeared
```

An area request opens a movable comparison panel with **Show area**, **Hide area**, **Quests**, and **Copy results**. The diagnostic requests a strong native fill and border. Use Show/Hide on the same map to compare; the panel reports if the preview clears because the quest log, map, or canvas changed. Each area request also captures quest/map data and render dimensions, so a separate scan is optional. Closing the comparison panel clears its preview. If a quest leaves your log before a request, drawing is refused; **Quests** opens a fresh list.

Diagnostic 0.0.6 adds **Check region data** (or `/jahdiag region`) to an active preview. It samples the native area's hit-test with the region hidden, drawn, then hidden again, and records a `region-probe`. `draw-dependent-hit` means this query responded to drawing the requested region; it does not prove visibility or a generally reliable availability check. `no-hit-unknown` cannot distinguish a missing region from a small or unloaded one. Other results preserve errors or inconclusive controls. Diagnostic checks run only when requested. These captures are separate from the playable addon’s bounded region query. See the [region-query experiment](CLIENT_TEST_PLAN.md#diagnostic-feasibility).

Native captures now confirm four repeatable `draw-dependent-hit` results for one quest with ordinary map objectives off: matching samples appeared only while its region was drawn. A second quest, tested because no shading appeared, returned `no-hit-unknown` despite cached quest data and a valid native map point. This supports the query experiment without establishing that a missed sample proves absence; automatic detection of missing regions remains unresolved.

Observations can be `visible`, `none`, or `other-quests`. Use the area capture ID displayed in the panel; clearing events have their own records. Successful draw calls remain `call-ok-unverified`; observations are separate records. Repeat the probes and comparisons with `disabled` after manually disabling ordinary guidance using controls verified in the actual beta. Record those controls and restore their original settings afterward. The diagnostic reads settings and quest data; it does not select quests, supertrack them, set waypoints, or provide spoiler suppression.

For a temporary comparison with Blizzard's quest frames hidden, first confirm that the **same quest and stage** has a visible area under normal settings. With `questPOI=1` and the map open, run `/jahdiag isolate`, then choose that quest in the picker. The test hides only Blizzard's quest pins and quest-area frame, leaving settings unchanged. Compare Hide/Show without changing maps. **Restore Blizzard map**, `/jahdiag restore`, or closing the diagnostic panel ends the test. Map closure/changes, quest updates, combat, and native quest-frame redisplay also end it. This is a disposable map comparison, not the product's spoiler guard; incomplete template access fails explicitly. Capture its `isolation` and `isolation-ended` records alongside visual results.

`/jahdiag export [CAPTURE_ID]` opens copyable text; `report [CAPTURE_ID]` prints it. `/jahdiag note TEXT` records context. The last 100 captures persist per character and flush on reload/logout. Native previews never persist and clear on map closure, map/canvas changes, quest-log updates, zoning, and reload. Diagnostic coordinates can spoil the quest being tested.

Follow the [client test plan](CLIENT_TEST_PLAN.md) and enter both successes and failures in [API_FINDINGS.md](../API_FINDINGS.md). Source inspection and fixture tests do not establish in-game feasibility.


## Multi-site region experiment (0.0.9)

For a quest such as Encroachment with several separated patches, use `/jah clear`, open the world map, run `/jahdiag area disabled`, and select the quest. Press **Check region data**, leave the same map open until the result appears, then `/reload` to save. The playable addon is unchanged. The diagnostic has no new runtime files, so a reload discovers the update.

The comparison now samples four phases: undrawn, visibly drawn, drawn with fill and border alpha zero, then undrawn again. It restores the same authorized visible preview after completion; cancellation never revives a cleared preview. It records all matching normalized grid coordinates, returned objective counts, and a current quest probe. The 33 × 33 grid is bounded to 64 native queries per frame. Coordinates are approximate samples, not exact region boundaries, and objective counts are not objective identifiers.

`transparent-drawn-hit` means matching queries returned data during zero-alpha drawing with clean undrawn controls. It does not prove visual invisibility; observe whether the diagnostic's shading disappears during the transparent phase and returns afterward. `transparent-no-hit-unknown` is inconclusive. Existing `draw-dependent-hit` and `no-hit-unknown` retain their original meanings. A later comparison after finishing one objective can test whether native geometry changes; do not infer that geometry represents only unfinished objectives before that test.

## Closed-map cold query (0.0.10)

After `/reload`, run `/jah start` if needed, `/jah clear`, and `/jahdiag clear`. Keep the world map closed and run `/jahdiag silent 837` out of combat for Encroachment. Wait for **Invisible closed-map check** to finish, note the result and whether any map, region, or pin appeared, then `/reload` to save. No visible preview is required. The diagnostic has no new runtime files; reload is sufficient.

This explicit experiment uses a dedicated QuestPOIFrame parented to UIParent with opacity, fill alpha and border alpha all zero before its first DrawBlob. It never requests visible drawing or opens, selects, or reparents Blizzard UI. It compares undrawn/transparent-drawn/undrawn grid samples on the player's current map, with fixed recorded frame dimensions 1002 × 668. The same 33 × 33 grid and 64-call frame limit apply. The dedicated frame has never visibly drawn a quest, even on repeated requests. Any flash must be recorded separately; requested zero opacity is not a visual verdict.

`closed-map-transparent-hit` establishes matching samples with clean undrawn controls in this frame setup. `no-hit-unknown` remains inconclusive; errors and malformed data are preserved. Opening the world map, combat, player-map changes, quest updates, entering the world, or `/jahdiag clear` cancels the experiment. Finish/error/cancellation undraws and hides only the owned frame, with no restoration of visible previews or persistent query state. Saved `silent-region-probe` records are included in the evidence summary's `silentRegionProbes` separately from visible-area evidence. The player addon is unchanged.
