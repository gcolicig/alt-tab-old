# Profiles Checklist (Phase 6, stage 1)

Stage one only: a profile groups apps, optionally binds a space, and filters the switcher to its apps. It
never starts, quits, hides, or moves anything. Run on the supported Mac and record the macOS build.

## What automated tests cover

- `SpaceIdentityTests`: UUID ↔ index resolution, a missing UUID resolving to nil (never another space).
- `ProfileTests`: the activation plan — unbound, bound, and lost-binding cases; the model's JSON round trip.

The runtime around them needs a Mac: reading the stable space UUID, the space switch, and the switcher filter.

## Manual steps

1. **Create a profile.** In `Profiles`, give slot 1 a name and two bundle IDs (one per line), e.g.
   `com.apple.dt.Xcode` and `com.googlecode.iterm2`. Assign a shortcut.
2. **Filter on activation.** Press the shortcut: the switcher shows only those apps' windows. Press it again:
   the filter clears and every window is back.
3. **Bind a space.** On the space you want, click `Bind to current space`; the status reads `Bound`. Switch
   away, activate the profile: it returns to the bound space, then filters.
4. **Lost binding is surfaced.** Delete the bound space in Mission Control, reopen settings: the status reads
   `Bound space is gone`. Activate the profile: it does not switch anywhere (only filters), and it never jumps
   to a random space.
5. **A space with no UUID.** Bind while on a fullscreen space if it exposes no UUID: binding stays `Not bound`
   or the space cannot be bound; nothing crashes.
6. **No profile active.** With no profile active, the switcher is unaffected — every window shows as before.
7. **Empty apps.** A profile with a bound space but no apps only switches the space and filters nothing.

## What a failure looks like

The switcher still showing other apps while a profile is active, a lost binding switching to some other
space, or a profile shortcut that does nothing when its slot is filled. The bound space status label is the
first place to look.
