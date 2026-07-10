# Open Source Preflight

Run this checklist before publishing releases from this fork.

- [ ] Confirm the bundle identifier is fork-specific.
- [ ] Confirm Sparkle does not point at the original AltTab appcast.
- [ ] Confirm AppCenter and Feedback tokens are empty or owned by this fork.
- [ ] Search for accidental credentials: `rg -n "token|secret|password|private|BEGIN .*KEY" .`
- [ ] Review GitHub Actions secrets and permissions.
- [ ] Decide whether release builds should be self-signed, Developer ID signed, or notarized.
- [ ] Confirm the README points to this fork, not the upstream project.
- [ ] Confirm privacy docs match the services actually enabled.
- [ ] Enable Dependabot if you want automated dependency alerts.
- [ ] Enable branch protection on `main` if more than one person will push.
