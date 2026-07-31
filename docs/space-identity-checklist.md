# Space Identity Checklist (S-08)

Run this on the supported Apple-silicon Mac. It decides one thing: is the managed-space UUID stable and
unique enough to key persisted Space aliases and profile bindings. Until it passes, aliases and
`Projektprofile`-Space-Bindings stay disabled and the menubar keeps showing plain numbers.

Tool: `swift ai/space-identity-probe.swift`. Snapshots land in
`~/Library/Application Support/AltTabPlusSpaceIdentity` and survive a reboot.

Record the exact macOS build and whether `Desktop & Dock > Mission Control > Displays have separate Spaces`
is on, for every run.

## Finding before the run (2026-07-29, macOS 26.5.1 build 25F80)

A first probe run on the target machine already answers two of the open questions:

- The key set per Space is `ManagedSpaceID, id64, type, uuid`. A `uuid` exists, so aliases have a candidate key.
- **The first Space carries no `uuid`** (index 1, `id64` 1, empty string). Every other Space had one, and none
  was duplicated. So uuid-keyed aliases cannot cover Space 1 as-is. Before S-08 can pass, decide whether that
  Space stays un-aliasable, or whether a documented fallback keys it by position with the alias visibly marked
  as unresolved. Do not fall back to `id64` silently — that is the failure mode S-08 exists to prevent.
- Because the first Space has no uuid, `Current Space` is matched on `id64` in the probe, not on uuid.
- Spaces without a uuid are excluded from every `diff`; the diff output states how many were excluded.
- **`ManagedSpaceID` is not an alternative key.** It held exactly the same value as `id64` for every Space
  (1, 131, 202), so it is session-local in the same way and cannot rescue the Space that has no uuid. The
  probe prints this check on every capture, so a future macOS build that diverges will show up.

That leaves `uuid` as the only identity candidate, and it is absent on the first Space. The steps below
decide whether that is a property of the login Space specifically or of whichever Space sits at position 1 —
step 3 answers it: if the Space that moves into position 1 keeps its uuid, the gap belongs to one particular
Space and an alias simply cannot cover it.

## Preparation

- Create at least four Spaces on the main display, plus two on a second display if one is attached.
- Put one window on each Space. An empty Space bounces the switch back, which muddies later steps
  (see the 2026-07-28 finding in `backlog.md`).
- Note the current `Displays have separate Spaces` value.

## Steps

| # | Step | Command | Expectation |
|---|---|---|---|
| 1 | Baseline | `capture baseline` | Every space has a non-empty uuid, no duplicates. A missing uuid fails S-08 immediately |
| 2 | Switch Spaces a few times natively, return | `capture after-switching` | `diff baseline after-switching`: nothing vanished, nothing appeared, no index change |
| 3 | Reorder Spaces in Mission Control (drag Space 2 behind Space 3) | `capture after-reorder` | `diff baseline after-reorder`: all uuids survived, only `indexOnDisplay` changed |
| 4 | Add one Space in Mission Control | `capture after-create` | Exactly one uuid appeared, none vanished |
| 5 | Delete the Space added in step 4 | `capture after-delete` | Exactly one uuid vanished; it is the one from step 4, and no other uuid changed |
| 6 | Delete a Space that existed at baseline | `capture after-delete-old` | Exactly that uuid vanished; the surviving uuids keep their identity |
| 7 | Log out and back in | `capture after-logout` | `diff baseline after-logout`: surviving Spaces keep their uuid |
| 8 | Full restart | `capture after-restart` | `diff baseline after-restart`: surviving Spaces keep their uuid. **This is the decisive step** |
| 9 | Enter and leave a fullscreen Space | `capture after-fullscreen` | The fullscreen Space appears as its own entry; note its `type` value |
| 10 | Toggle `Displays have separate Spaces`, then restart as macOS demands | `capture after-separate-toggle` | Record whether uuids survive the regrouping; a change here is acceptable but must be documented |
| 11 | Disconnect and reconnect the second display | `capture after-display-replug` | Spaces of that display keep their uuid and return to the same display identifier |

## What each result means

- **uuid survives step 8 and stays unique**: S-08 passes. Aliases and profile bindings may persist against
  the uuid. Note explicitly that `id64` is *not* the key — the probe prints whether the `id64` set changed.
- **uuid survives but `id64` changes**: the expected and desired outcome. It is the whole reason aliases must
  not key on `id64` or on the numeric index.
- **uuid changes on restart, or two Spaces share one uuid, or a uuid is missing**: S-08 fails. Persisted
  aliases and profile Space-bindings stay off; the menubar keeps numbers only, and `2D. Projektprofile`
  cannot bind to a Space.
- **uuid survives everything except the separate-Spaces toggle**: partial pass. Aliases may persist, but the
  toggle must invalidate them visibly rather than silently remapping to a different Space.

## Recording

Keep the snapshot json files. For the write-up in `backlog.md` note per step: macOS build, separate-Spaces
value, display count, and the probe's verdict lines. A failing step is recorded with its diff output, not
summarised.

## Decision

- Enter the outcome under `S-08` in the `Spikes mit Exit-Kriterien` table in `backlog.md` and under `2C`'s
  `Optionale Namen`.
- Re-run this checklist after every supported macOS major update before re-enabling persisted aliases.
