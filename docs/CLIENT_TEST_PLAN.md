# Client acceptance checks

Test the installed version on the exact client build. Record Pass / Fail / Not available, quest/stage and what visibly happened. `/jah status` supplies a copyable report. Record exact errors and relevant other quest/UI addons. Never count a fixture result as a client observation.

## Reading and native integration

- Accept, read and hover quests with Just a Hint active: no quest markers, areas or arrows appear before Hint.
- Repeat native tracker/quest-log opening and quest switching: no blocked-action popup. Standard rewards, Abandon/Share/Track, modifier clicks and quest-item buttons remain usable.
- For a quest on another map, Hint is omitted. Entering the zone starts nothing; usable local data can make Hint available.
- There is no standalone reader or fallback. Missing native controls report unavailability without replacing tracker handlers.

## Direction and arrival

- A far-away objective Hint may show Loading hint… while invisibly sampling; no region, marker, flash, sound or feedback appears during preparation. Reading and hovering never start sampling.
- On a multi-site quest, the arrow chooses a useful nearest confirmed location and stays fixed while moving between sites. Arrival at another valid site dismisses it after the dwell and reveals nothing automatically.
- Completing all objectives for one site removes that site on a fresh request. Count increases alone preserve the current request.
- Clear, replacement, stage change, zoning, restoration and reload during loading cannot finish an old request. Native completion must not close a different quest opened meanwhile.
- Point-only quests still use native point direction and nearby marker behavior; completed turn-in requests skip objective-region sampling.

- Hint far away closes the map and renders one arrow without a destination pin, route or countdown.
- With arrow flight enabled, the arrow grows at screen center, sweeps to its minimap-rim position with a short trail, then produces the enabled landing pulses. No duplicate stationary arrow remains during flight. Try different UI/minimap scales and positions, and turn during flight to check the handoff.
- Clear, replace, zone, restore or lose valid data during flight: the overlay ends and cannot replay. Hide the minimap during flight and show it again: no stranded center arrow or new feedback remains. A long frame stall ends the animation with the ordinary bearing restored if still valid.
- Rotate with fixed and rotating minimaps: bearing is correct and smooth. Chat direction is useful for the quest.
- Arrival removes the arrow, reveals nothing else and stays off when walking away. A fresh far-away request can show it again.
- Read B while A's arrow is active: preserve A. Hint for B replaces A; unavailable B clears A without acquiring help later.

## Nearby area and marker

- Hint near a quest with a known native region reveals only its region. Confirm region preference after the marker fallback update.
- Hint near a point-only quest shows a native marker with point-specific chat. Clear Hint removes it without closing the map or producing feedback.
- Close/reopen or change the map: the request stays cleared. Resizing/zooming an authorized display preserves it without replaying feedback.
- Ordinary count increases preserve guidance. Finishing the objective clears it without a turn-in pin or arrow.

## Completed quests and lifecycle

- A completed accepted quest can receive newly requested turn-in direction when far, or a useful area/point when nearby.
- Verify it uses the current turn-in destination, not the former objective. Hand-in clears it without another quest's guidance.
- Zoning, removal, stage/destination changes, restoration and reload clear assistance without resurrection.
- Missing/loading data hides unreliable assistance; data arrival never initiates a failed request automatically.

## Settings and activation toggle

- `/jah` and `/jah settings` open the same Settings dialog with five feedback checkboxes, no quest list, tabs or reader-mode option. Check label fit and the activation control at smaller UI scales.
- Start Just a Hint becomes Restore Blizzard guidance after success. Restore clears the hint and returns saved guidance settings. Combat disables the control; a failed restoration offers Retry restoration.
- Reload resumes active/inactive settings but never a hint. Original guidance recovery and other characters' minimap snapshots survive.
- A status report opens without opening Settings or a quest reader. Closing Settings never closes or selects a quest in Blizzard's UI.

## Presentation and coverage

- Independently disable arrow flight, chat, sound and each pulse. Disabling flight keeps the immediate minimap arrow and any enabled pulses. Disabling flight mid-animation restores the minimap arrow immediately. Preferences survive reload; explicit enabled bearing feedback is perceptible.
- Nearby area/point feedback is chat only; no map caption, sound or pulse. Arrival/read/clear never starts feedback.
- Check combat, tracker quest items, caves, instances, transport steps and multiple-objective quests as available. Missing support is different from a wrong destination or error.
- Run `/jah restore` on each activated character before disabling/uninstalling; verify ordinary Blizzard guidance returns.

## Diagnostic feasibility

Use the separate [diagnostic addon](DIAGNOSTICS.md) only for explicit development comparisons. Test accepted outdoor, delivery/turn-in and multiple-objective quests under normal and disabled guidance. Compare the same quest/stage with Show/Hide. A successful DrawBlob call is not visible-region proof; a missed region query is not absence proof. Reload/logout saves captures before `python dev.py evidence`. Preserve failures and restore changed guidance controls. Historical observations are in [API findings](../API_FINDINGS.md).

## Native hint markers

Request A, then inspect the right-hand tracker and Blizzard's quest list: a gold arrow marks A when its guidance is visible. Read B without requesting a hint: A retains it. Request B: ownership moves to B if assistance renders, or clears if unavailable. Clear, arrive, restore or reload: no stale marker remains. Scroll native rows off-screen, collapse the tracker, change quests/stages and reopen the map: markers must not remain on hidden or recycled rows. Check text spacing, existing native icons and quest-item clicks. Missing marker support must not break existing Hint behavior. `/jah status` records marker count/errors.
