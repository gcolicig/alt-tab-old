# TODO: Support-, Update- und Crash-UI entfernen

Stand: 2026-07-10

Ziel: Die Fork-App soll keine UI mehr fuer Support-Spenden, manuelle Update-Pruefung, Update-Policy-Auswahl, Feedback-Versand oder Crash-Report-Policy anzeigen. Auto-Updates und Crash-Reporting bleiben fuer den Fork standardmaessig deaktiviert bzw. optional.

## Umsetzbarkeit

Umsetzbar mit geringem Risiko. Die sichtbaren Elemente sitzen an wenigen zentralen Stellen:

- Settings-Seitenleiste: `src/ui/settings-window/SettingsWindow.swift`
- General-Tab: `src/ui/settings-window/tabs/GeneralTab.swift`
- Menubar-Icon-Menue: `src/ui/Menubar.swift`
- About-Dialog, optional fuer Konsistenz: `src/ui/settings-window/tabs/AboutTab.swift`

Es ist keine groessere Architekturarbeit noetig. Wichtig ist aber, nicht nur Buttons zu verstecken, sondern Layout, Settings-Suche und Default-Policies sauber mitzudenken.

## Gewuenschte Entfernung

- [ ] `Support this project` Button in der Settings-Seitenleiste entfernen.
- [ ] `Check for updates now...` Button im General-Tab entfernen.
- [ ] `Updates policy` Auswahl im General-Tab entfernen.
- [ ] `Crash reports policy` Auswahl im General-Tab entfernen.
- [ ] Menubar-Icon-Menue: `Check for updates...` entfernen.
- [ ] Menubar-Icon-Menue: `Send feedback...` entfernen.
- [ ] Menubar-Icon-Menue: `Support this project` entfernen.

## Konkrete Code-Fundstellen

### Settings-Seitenleiste

Datei: `src/ui/settings-window/SettingsWindow.swift`

- `supportButton` wird als Property ueber `AboutTab.makeSupportProjectButton()` erstellt.
- `setupSidebar()` ruft `setupSupportButton(sidebarContainer)` auf.
- `setupSidebarTable()` verankert die Sidebar-Liste aktuell unten am `supportButton`.
- `setupSupportButton()` fuegt den Button in die Seitenleiste ein.

TODO:

- [ ] `supportButton` Property entfernen.
- [ ] `setupSupportButton(...)` entfernen.
- [ ] Aufruf in `setupSidebar()` entfernen.
- [ ] Constraint fuer `sidebarScrollView.bottomAnchor` von `supportButton.topAnchor` auf `resetButton.topAnchor` umhaengen.
- [ ] Abstand so setzen, dass `Reset settings...` und `Quit AltTab` weiterhin sauber stehen.

### General-Tab

Datei: `src/ui/settings-window/tabs/GeneralTab.swift`

Betroffene Stellen:

- `updatesPolicyDropdown`
- `crashPolicyDropdown`
- Erstellung von `updatesPolicy`
- Erstellung von `crashPolicy`
- `table.addRow(updatesPolicy)`
- `table.addRow(crashPolicy)`
- `checkForUpdates` Button
- `StackView([exportButton, importButton, checkForUpdates], .horizontal)`
- `refreshControlsFromPreferences()` aktualisiert beide Dropdowns.
- `checkForUpdatesNow(_:)` ruft Sparkle direkt auf.

TODO:

- [ ] `updatesPolicyDropdown` entfernen, falls keine UI mehr darauf zugreift.
- [ ] `crashPolicyDropdown` entfernen oder optional behalten, falls `AppCenterCrashes` es noch fuer eine Ask-UI aktualisiert.
- [ ] `updatesPolicy` Row entfernen.
- [ ] `crashPolicy` Row entfernen.
- [ ] `table.addNewTable()` fuer die entfernten Rows pruefen und ggf. entfernen, damit kein leerer Abschnitt bleibt.
- [ ] `checkForUpdates` Button entfernen.
- [ ] Tools-Stack auf `[exportButton, importButton]` reduzieren.
- [ ] `refreshControlsFromPreferences()` um entfernte Dropdowns bereinigen.
- [ ] `checkForUpdatesNow(_:)` nur entfernen, wenn auch keine andere Stelle sie mehr nutzt.

Hinweis: Wenn der Menubar-Menuepunkt ebenfalls entfernt ist, kann `GeneralTab.checkForUpdatesNow(_:)` wahrscheinlich entfallen. Danach pruefen, ob `import Sparkle` in `GeneralTab.swift` noch gebraucht wird.

### Menubar-Icon-Menue

Datei: `src/ui/Menubar.swift`

Zu entfernen:

- `addMenuItem(NSLocalizedString("Check for updates...", ...), #selector(App.checkForUpdatesNow), ...)`
- `addMenuItem(NSLocalizedString("Send feedback...", ...), #selector(App.showFeedbackPanel), ...)`
- `addMenuItem(NSLocalizedString("Support this project", ...), App.supportProjectAction, ...)`

TODO:

- [ ] Die drei Menuepunkte entfernen.
- [ ] Separatoren danach pruefen, damit keine doppelten oder leeren Gruppen entstehen.
- [ ] Erwartetes Menue danach: Show, Settings, Check permissions, About, Debug tools, Quit.

### Optional: About-Dialog

Datei: `src/ui/settings-window/tabs/AboutTab.swift`

Der About-Dialog erstellt ebenfalls einen `Support this project` Button:

- `let supportProject = makeSupportProjectButton()`
- `let rows = [[appInfo], [supportProject]]`
- `makeSupportProjectButton()`

TODO:

- [ ] Entscheiden, ob der Support-Button auch im About-Dialog entfernt werden soll.
- [ ] Falls ja: `rows` auf `[[appInfo]]` reduzieren.
- [ ] `makeSupportProjectButton()` entfernen, falls danach keine andere Stelle sie braucht.
- [ ] `makeButtonWithIcon(...)` nur behalten, wenn weiterhin benoetigt.

Empfehlung: Entfernen, damit die Fork-App keine Spenden-/Support-Aktion des Upstream-Projekts mehr anbietet.

## Logik- und Default-Policy-Pruefung

Die UI-Entfernung allein reicht fuer eine saubere Fork-Variante fast aus. Zusaetzlich pruefen:

- [ ] `Preferences.defaults` setzt `updatePolicy` dauerhaft auf `manual`.
- [ ] `Preferences.defaults` setzt `crashPolicy` fuer den Fork auf `never`, nicht `ask`.
- [ ] `PreferencesEvents.applyUpdatePolicyPreference()` startet keine periodischen Checks.
- [ ] `AppCenterCrashes` sendet ohne eigenen AppCenter-Secret nichts.
- [ ] Importierte Settings koennen keine ungewollten Update- oder Crash-Policies reaktivieren, oder sie werden beim Start normalisiert.

## Such- und Lokalisierungsreste

Nach der Entfernung aus UI-Code:

- [ ] `rg "Support this project|Check for updates|Updates policy|Crash reports policy|Send feedback"` ausfuehren.
- [ ] Treffer in docs/web nur separat bewerten; App-UI-Treffer sollten verschwunden sein.
- [ ] Settings-Suche testen: Suche nach `update`, `crash`, `support`, `feedback` sollte keine entfernten UI-Elemente mehr hervorheben.

## Verifikation

- [ ] `git diff --check`
- [ ] `./build.sh`
- [ ] `./build.sh --run`
- [ ] Settings-Fenster visuell pruefen:
  - Seitenleiste ohne `Support this project`
  - General-Tab ohne Update- und Crash-Policy
  - General-Tab nur mit `Export settings...` und `Import settings...`
- [ ] Menubar-Icon-Menue visuell pruefen:
  - kein `Check for updates...`
  - kein `Send feedback...`
  - kein `Support this project`
- [ ] Optional: About-Dialog pruefen, falls dort ebenfalls entfernt.

## Empfohlene Reihenfolge

1. Menubar-Menue bereinigen.
2. General-Tab bereinigen.
3. Settings-Seitenleiste bereinigen und Constraints anpassen.
4. Optional About-Dialog bereinigen.
5. Defaults fuer `crashPolicy` und `updatePolicy` pruefen bzw. haerten.
6. Build starten und App visuell testen.
