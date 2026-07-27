# Tahoe Tiling Checklist

Run this checklist on the supported Apple-silicon Mac. Record the exact macOS build and relevant `Desktop & Dock > Windows` settings.

| Native action | Drag available | Shortcut/menu available | Notes |
|---|---|---|---|
| Left half | [ ] | [ ] | |
| Right half | [ ] | [ ] | |
| Fill visible desktop | [ ] | [ ] | Distinguish from fullscreen Space |
| Corner quarters | [ ] | [ ] | Test all corners |
| Thirds | [ ] | [ ] | Record exact variants |
| Two-thirds | [ ] | [ ] | Record exact variants |
| Three-quarters | [ ] | [ ] | |
| Center without resize | [ ] | [ ] | |
| Move to next display | [ ] | [ ] | |
| Restore previous frame | [ ] | [ ] | |
| Layout preview | [ ] | [ ] | Record trigger and delay |

## Variants

- Repeat edge and corner drags with `Option` held.
- Repeat with tiling margins enabled and disabled.
- Check top-edge behavior below the menu bar and beside a notch.
- Check a shared edge between displays and a free outer edge.
- Repeat with `Displays have separate Spaces` enabled and disabled.
- Record whether Stage Manager or a fullscreen Space changes any result.

## Decision

- Mark AltTab+ actions that duplicate Tahoe outside the explicit modifier-drag session as out of scope.
- Keep Thirds, Two-Thirds, custom zones, Center, display moves, or Restore only where this matrix shows a product-relevant gap.
- Re-run after every supported macOS major update before enabling new snapping behavior.
