# Release review — 0.7.4 preview

Target: Forever beta 1.60.1 / build 70205 / interface 16001.

Activation defaults on and runs at login once native controls are available and combat has ended. Saved opt-outs and unfinished restoration remain disabled. Native UI modules load without opening or selecting a quest.

The native quest list and objective counts remain visible on the right. Its questPOI setting suppresses guidance buttons; quest clicks still open native map details. The addon reads tracker availability and visibility without changing frame parents, layout, collapse state, quest items or handlers. Restore returns saved guidance settings, persists the opt-out and retains failed restoration data for retry.

Nearby location pins render at 12 screen units. The README includes the illustrated usage guide and a branding banner; source archives preserve screenshots and branding assets as binary files.

Behavioral fixtures cover startup, lazy loading, combat deferral, upgrade/reload, opt-out, visible quest content, new rows, native quest-click delegation, guidance-button settings and restoration. Native acceptance remains pending for the supported client, including repeated map opening, combat, quest-item access and other UI addons. See [client checks](CLIENT_TEST_PLAN.md).

Runtime and TOC versions match the release profile. The runtime file list is unchanged; `/reload` loads this update. Runtime ZIPs contain declared addon files and the license; source ZIPs exclude local config, captures and backups. Tagged publication checks the bundle before publishing the prerelease.
