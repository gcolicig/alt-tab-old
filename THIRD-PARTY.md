# Third-Party Provenance

This register records sources reviewed while developing AltTab+. It distinguishes behavioral research and independent reimplementation from copied code.

| Source | Revision reviewed | Retrieved | License | Use | Target files | Attribution |
|---|---|---|---|---|---|---|
| https://github.com/mikker/LeaderKey | `16bcb307dcc5309fbc3a00fe398d913e1f7ddc51` | 2026-07-26 | MIT | A: behavior and architecture reviewed | n/a | n/a |
| https://github.com/mikker/FlickRing | `b8578988637319d8d7ab38985659fcde2512f7ef` | 2026-07-26 | MIT | A: behavior and architecture reviewed | n/a | n/a |
| https://github.com/mikker/Moves | `8e8b619802426e7a32012f6aa93f5322541cad2a` | 2026-07-26 | MIT | A: behavior and architecture reviewed | n/a | n/a |
| https://github.com/n0an/hyperkey | `d0625e719bf784c05057dbcdfac1b86e92863d74` | 2026-07-26 | MIT | A: physical Caps Lock detection and event-routing architecture reviewed | n/a | n/a |
| https://github.com/linearmouse/linearmouse | `3d9ba49fedf5537df65403540582b02d24a188e7` | 2026-07-27 | MIT | A: configuration model, pointer settings, and device ownership behavior reviewed | n/a | n/a |
| https://github.com/mikusnuz/nudge | `1da2890965b73299a2b0344231c4945ac74f6d0f` | 2026-07-27 | MIT | A: snapping behavior, overlay, and layout actions reviewed | n/a | n/a |
| https://github.com/jmgao/metamove | `328279fc04159effacc386a942ee83e776ce52e2` | 2026-07-27 | GPL-2.0-or-later | A: modifier-based move and resize behavior reviewed | n/a | n/a |
| https://github.com/jurplel/InstantSpaceSwitcher | `fd37e7fed62ad862ec6326aa7dac9b7bc6b413e5` | 2026-07-27 | MIT | B: Dock-swipe event sequence and per-display planning independently reimplemented in Swift | `src/logic/spaces/InstantSpaces.swift`, `src/logic/spaces/InstantSpacesTestable.swift`, `src/api-wrappers/private-apis/InstantSpacesPrivateApi.swift` | n/a |
| https://github.com/xiamaz/YabaiIndicator | `e525ef8448a25d33522c9075de420eb585173516` | 2026-07-27 | MIT | B: compact menu-bar presentation and event-driven refresh independently reimplemented with AppKit | `src/ui/Menubar.swift`, `src/logic/events/SpacesEvents.swift`, `src/logic/events/ScreensEvents.swift` | n/a |
| https://github.com/royalbhati/HopTab | `b2bf2899207d23c4de92ef6bd17487d7e4cd2987` | 2026-07-27 | MIT | A: profiles, space binding, and session flow reviewed | n/a | n/a |

No source code from these repositories has been copied into AltTab+. Any future algorithmic reimplementation or code reuse must update this register before merge.
