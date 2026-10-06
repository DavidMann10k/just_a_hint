# Release review — 1.0.0

Target: Forever beta 1.60.1 / build 70235 / interface 16001.

Activation defaults on and runs at login once native controls are available and combat has ended. Saved opt-outs and unfinished restoration remain disabled. Native UI modules load without opening or selecting a quest.

The native quest list and objective counts remain visible on the right. Its questPOI setting suppresses guidance buttons; quest clicks still open native map details. The addon reads tracker availability and visibility without changing frame parents, layout, collapse state, quest items or handlers. Restore returns saved guidance settings, persists the opt-out and retains failed restoration data for retry.

The requested arrow reveals over 0.18 seconds, holds at screen center for 0.25 seconds and travels to the minimap over about 0.91 seconds, 25% slower than before. One gold ring peaks during the hold and follows the arrow as it fades; the arrow-pulse preference controls it. Fixtures cover the dwell, slower path, ring tracking, preference independence and landing handoff. The user accepted the revised native animation in RC4 on 2026-10-06.

Nearby location pins render at 12 screen units. The README includes the illustrated usage guide and a branding banner; source archives preserve screenshots and branding assets as binary files.

Arrival clears a visible requested bearing before playing one built-in minimap ping and two green minimap pulses. The effects respect the existing sound and minimap-pulse preferences. They add no quest detail and cannot replay after interruption. Fixtures cover pulse count and duration, sound selection and unavailability, point and region arrivals, quiet cleanup, moved/scaled minimaps and restored gold request feedback. The user selected the minimap ping and accepted arrival feedback in the RC4 client pass.

Behavioral fixtures cover startup, lazy loading, combat deferral, upgrade/reload, opt-out, visible quest content, new rows, native quest-click delegation, guidance-button settings and restoration. The user reported “Everything is green” for RC4 and authorized the full release on 2026-10-06. Native acceptance is recorded from that user report on the current Forever installation; automated checks remain separate evidence. The [client checks](CLIENT_TEST_PLAN.md) remain the regression plan for future changes and client builds.

Runtime and TOC versions match the release profile. The runtime file list is unchanged; `/reload` loads this update. Runtime ZIPs contain declared addon files and the license; source ZIPs exclude local config, captures and backups. Runtime behavior matches the accepted RC4; only the runtime and TOC version change for 1.0.0. Tagged publication checks the bundle before publishing the stable release.
