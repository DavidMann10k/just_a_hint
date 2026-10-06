# Release review — 0.7.8 RC4

Target: Forever beta 1.60.1 / build 70235 / interface 16001.

Activation defaults on and runs at login once native controls are available and combat has ended. Saved opt-outs and unfinished restoration remain disabled. Native UI modules load without opening or selecting a quest.

The native quest list and objective counts remain visible on the right. Its questPOI setting suppresses guidance buttons; quest clicks still open native map details. The addon reads tracker availability and visibility without changing frame parents, layout, collapse state, quest items or handlers. Restore returns saved guidance settings, persists the opt-out and retains failed restoration data for retry.

The requested arrow reveals over 0.18 seconds, holds at screen center for 0.25 seconds and travels to the minimap over about 0.91 seconds, 25% slower than before. One gold ring peaks during the hold and follows the arrow as it fades; the arrow-pulse preference controls it. Fixtures cover the dwell, slower path, ring tracking, preference independence and landing handoff. Native timing and appearance remain pending.

Nearby location pins render at 12 screen units. The README includes the illustrated usage guide and a branding banner; source archives preserve screenshots and branding assets as binary files.

Arrival clears a visible requested bearing before playing one built-in minimap ping and two green minimap pulses. The effects respect the existing sound and minimap-pulse preferences. They add no quest detail and cannot replay after interruption. Fixtures cover pulse count and duration, sound selection and unavailability, point and region arrivals, quiet cleanup, moved/scaled minimaps and restored gold request feedback. The user auditioned and selected the minimap ping; arrival rendering on the target client remains pending.

Behavioral fixtures cover startup, lazy loading, combat deferral, upgrade/reload, opt-out, visible quest content, new rows, native quest-click delegation, guidance-button settings and restoration. Native acceptance remains pending for the supported client, including repeated map opening, combat, quest-item access and other UI addons. See [client checks](CLIENT_TEST_PLAN.md).

Runtime and TOC versions match the release profile. The runtime file list is unchanged; `/reload` loads this update. Runtime ZIPs contain declared addon files and the license; source ZIPs exclude local config, captures and backups. Tagged publication checks the bundle before publishing the prerelease.
