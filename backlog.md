# Backlog: Mac UX Enhancer

Stand: 2026-07-27

Ziel: Ideen aus dem BetterTouchTool-/OSS-Tooling-Verlauf festhalten, damit sie in spaeteren Versionen des AltTab-Forks wieder aufgegriffen werden koennen. Arbeitshypothese: Der Fork kann langfristig zu einem offenen, Windows-naeheren macOS UX Enhancer wachsen.

## Leitidee

AltTab bleibt der Kern fuer Windows-aehnliches Fensterwechseln auf macOS. Darauf koennen optionale UX-Module fuer Window Layouts, Move/Resize, Snapping, Pointer/Scroll und Gesten aufbauen. Die Settings bleiben minimal: neue Bereiche erscheinen als weitere Sidebar-Eintraege und scrollen rechts an den passenden Abschnitt.

## Architekturentscheidung

- Das Produkt bleibt eine integrierte AltTab+-App.
- Window Layouts, Move/Resize und Snapping nutzen neben dem API-Wrapper-Layer auch die vorhandene Fenstererkennung, App-Kompatibilitaetsregeln, Spaces-/Display-Logik, Berechtigungsfuehrung, Shortcut-Infrastruktur, Settings, Diagnose und Panel-Mechanik.
- Pointer/Scroll und Gesten werden innerhalb der App klar von Switcher und AX-Fensterkern getrennt, damit Ausfall oder Deaktivierung eines Moduls den Rest der App nicht beeintraechtigt.
- Eine separate Companion-App ist nicht Teil der Produktarchitektur. Ein Helper-Prozess bleibt als technische Isolierung fuer besonders riskante Input-Pfade moeglich, ohne ein zweites Produkt mit eigenen Settings, Autostart und Nutzerfuehrung zu schaffen.
- Die UX-Module werden fuer AltTab+ entwickelt und nicht als Upstream-PRs geplant. Der Fork traegt seine eigene Roadmap, Identitaet und Distribution.

## Zielplattform

- Ziel: macOS Tahoe auf Apple Silicon.
- Intel-Macs werden bewusst ausgeschlossen.
- Aeltere macOS-Versionen werden bewusst ausgeschlossen.
- Konsequenz: Features und Workarounds werden nicht fuer macOS 15 oder Intel validiert, ausser es entsteht spaeter ein ausdruecklicher Grund.
- Hinweis: Tahoe-only ist ein kurzfristiger Zielzustand, keine dauerhafte Versionsstrategie. macOS 27 ist bereits angekuendigt; vor Release-Fokus klaeren, ob die Policy `N` oder `N und N-1` sein soll.

## Revision 2026-07-26

Diese Revision korrigiert den Vorgaengerstand nach zwei Befunden:

1. Aktuelle macOS-Versionen liefern Tiling nativ: Drag-to-edge, Drag-to-corner, Drag-to-menubar, Option-Modifier beim Drag, `Fn-Control-*` Shortcuts fuer Fill, Center, Halves und Restore, plus Schalter unter Desktop & Dock.
2. Input-Module mit Event Taps, Accessibility-Mutation oder privater Multitouch-API brauchen explizite Runtime-Sicherungen.

Wichtig: Die native Feature-Menge wird nur fuer macOS Tahoe auf Apple Silicon bewertet. Widersprueche zur Feature-Menge von macOS 15 sind fuer diesen Fork nicht entscheidend, weil aeltere macOS-Versionen nicht Zielplattform sind.

## Guide: macOS Spaces

AltTab+ dokumentiert zuerst die vorhandene macOS-Bedienung und stellt eigene Funktionen als optionale Abkuerzung dar:

- Neue Spaces werden in Mission Control angelegt: Mission Control mit `Control+Pfeil hoch`, der Mission-Control-Taste (`F3`, je nach Tastatur gegebenenfalls mit `Fn`) oder der in macOS konfigurierten Trackpad-Geste oeffnen und in der Spaces-Leiste auf `+` klicken.
- Mission Control verwendet standardmaessig einen Drei-Finger-Wisch nach oben; Gesten und Tastaturkuerzel koennen in den Systemeinstellungen geaendert oder deaktiviert sein.
- Zwischen Spaces wechseln: auf dem Trackpad mit drei oder vier Fingern horizontal wischen, auf der Magic Mouse mit zwei Fingern wischen oder `Control+Pfeil links/rechts` verwenden.
- Direkte Spruenge per `Control+Zahl` sind keine verlaessliche `1-0`-Grundannahme. Die Aktionen `Zu Schreibtisch n wechseln` muessen unter `Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Mission Control` vorhanden, aktiviert und konfliktfrei sein.
- Fenster in einen benachbarten Space verschieben: Fenster an den linken oder rechten Bildschirmrand ziehen und kurz halten. Fuer ein beliebiges Ziel Mission Control oeffnen und das Fenster auf den gewuenschten Space ziehen.
- Apps koennen nativ ueber `Control-Klick auf das Dock-Symbol > Optionen > Zuweisen zu` einem Desktop zugeordnet werden.
- Bei mehreren Displays bestimmt `Systemeinstellungen > Schreibtisch & Dock > Mission Control > Displays haben separate Spaces` die Semantik. Aktiviert bedeutet eigene Space-Mengen pro Display; deaktiviert bedeutet eine gemeinsame Space-Umschaltung fuer den gesamten Desktopverbund.
- Der Guide verlinkt die Apple-Dokumentation und veraendert keine macOS-Einstellung automatisch.

Quellen:

- https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac
- https://support.apple.com/guide/mac-help/view-open-windows-and-spaces-mh35798/mac
- https://support.apple.com/guide/mac-help/change-desktop-dock-settings-mchlp1119/mac

## Querschnittsanforderungen

Diese Regeln gelten fuer jedes Modul, das Input-Events liest, Events postet oder Fremdprozess-Fenster mutiert. Einmalige tastaturgesteuerte AX-Aktionen brauchen den AX-Queue-, Timeout-, Filter- und Diagnosepfad. Tap-spezifische Regeln wie Recovery, Circuit Breaker und Panic-Kill-Switch sind Release-Gates fuer das erste Modul mit dauerhaftem Input-Tap, nicht fuer die passiven Window-Layout-Shortcuts.

| ID | Anforderung | Begruendung |
|---|---|---|
| Q-01 | Panic-Kill-Switch: hartkodierter Shortcut deaktiviert alle Input- und AX-Module sofort | Haengender Event-Tap oder Fehlgestenerkennung kann das System schwer bedienbar machen |
| Q-02 | Keine blockierenden AX-Calls im Event-Tap-Callback; AX-Arbeit auf eigener Queue | Blockierender Callback fuehrt zu Tap-Deaktivierung durch das System |
| Q-03 | `AXUIElementSetMessagingTimeout` je AXUIElement setzen, Richtwert 0.1 bis 0.25 s | AX ist synchrone IPC; haengende Ziel-Apps duerfen den Fork nicht blockieren |
| Q-04 | Begrenzte Tap-Recovery fuer `kCGEventTapDisabledByTimeout` und `kCGEventTapDisabledByUserInput`; erstes Auftreten darf reaktivieren, Wiederholung oeffnet Q-12-Circuit-Breaker | Verhindert sowohl sporadischen Totalausfall als auch blinde Reaktivierungsschleifen |
| Q-05 | Tap-Scope minimal; kein dauerhafter Tap auf `mouseMoved`; Dragged-Events nur zwischen Mousedown und Mouseup scharf | High-Polling-Maeuse koennen sehr hohe Eventraten erzeugen |
| Q-06 | Coalescing: pro Frame nur letzter Zielrect, Drop wenn vorheriger AX-Set offen ist; Zielrate 30 bis 60 Hz | Verhindert AX-Queue-Aufstau bei Drag |
| Q-07 | Debug-Ringbuffer mit AX-proposed, AX-result, Fenster-ID, Bundle-ID und Display | App-Kompatibilitaetsbugs sind sonst kaum diagnostizierbar |
| Q-08 | Importierte oder migrierte Settings aktivieren nie automatisch Input- oder AX-Module | Verhindert unbeabsichtigtes Scharfschalten nach Settings-Uebernahme |
| Q-09 | Private-API-Module deaktivieren sich bei unbekannter macOS-Major-Version selbst und melden das sichtbar | Verhindert Raten bei ABI- oder Symbol-Aenderungen |
| Q-10 | Module aus: keine zusaetzlichen Event-Taps oder periodischen Timer; Module an und System idle: CPU und Wakeups gegen den unveraenderten Fork messen | Verhindert unbemerkten Akkuverbrauch einer dauerhaft laufenden Agent-App |
| Q-11 | Safe-Start-Gate wird vor jeder Input-Modulinitialisierung ausgewertet und kann ohne laufende App gesetzt werden | Ein Start-Modifier allein hilft bei automatischem Login-Start nicht |
| Q-12 | Event-Taps arbeiten fail-closed: wiederholte Timeouts oder Berechtigungsfehler deaktivieren das betroffene Modul sichtbar statt es unbegrenzt zu reaktivieren | Verhindert Retry-Schleifen und wiederkehrende Systemblockaden |
| Q-13 | Systemweites Hyper fuegt Modifier nur vollstaendigen Key-down-/Key-up-Paaren hinzu; keine eigenstaendig gehaltenen Modifier-Events. Synthetische Caps-Lock-Taps werden markiert | Vermeidet haengende Modifier und rekursive Event-Verarbeitung |
| Q-14 | Jedes absorbierte Key-down verfolgt und absorbiert sein zugehoeriges Key-up, auch wenn Caps Lock zuerst losgelassen wird | Verhindert halbe Tastensequenzen im Vordergrundprozess |
| Q-15 | Eingabe-Zustandsmaschinen werden bei Deaktivierung, Tap-Ausfall, Sleep/Wake, Berechtigungsverlust und Terminierung bereinigt | Verhindert ueber Sitzungsgrenzen haengende Trigger |
| Q-16 | Leader, FlickRing und Move/Resize fuehren keine Aktion oder AX-Arbeit im Event-Tap-Callback aus | Haelt den Input-Pfad kurz und verhindert Tap-Timeouts |

Permission-Modell:

- Accessibility: AX-Fenstermutation, Event-Posting, modifizierende Taps.
- Input Monitoring: Listen-Only-Taps je nach Event-Typ und macOS-Version.
- IOKit-Pointer-Settings: Annahme ohne zusaetzliche TCC-Berechtigung; per Spike verifizieren.
- Bundle-ID- oder Signaturaenderung gegenueber AltTab erfordert Neu-Autorisierung durch Nutzer.
- TCC-Freigaben gelten fuer den Prozess, nicht fuer einzelne Module. Modultrennung ist eine Produkt- und Laufzeitregel, keine OS-Isolation.
- Berechtigungen werden nach benoetigter Faehigkeit behandelt, nicht pauschal fuer jedes Modul jenseits AX.
- Ein zusaetzlicher Prompt erscheint nie beim App-Start, sondern erst bei bewusster Aktivierung des ersten abhaengigen Moduls.
- Vor Aktivierung und nach Wake wird die benoetigte Berechtigung erneut geprueft.
- Fuer Input Monitoring `CGPreflightListenEventAccess` verwenden; fehlgeschlagene Tap-Erstellung und API-Fehler ebenfalls als Berechtigungsverlust behandeln.
- Es gibt keinen verlasslichen Callback fuer jeden TCC-Entzug. Bei erkanntem Entzug Modul deaktivieren und melden, keine Neustart- oder Retry-Schleife.
- Entzug von Input Monitoring deaktiviert nur abhaengige Module. Entzug von Accessibility betrifft den AltTab-Kern und alle AX-abhaengigen Module.

Safe Start und Laufzeitsicherung:

- Umgesetzt fuer Hyper: `inputModulesSafeMode`, ein fuenfsekundiger Arming-Marker, der feste Not-Aus `Command+Control+Option+Shift+Escape` und ein Circuit Breaker beim zweiten Keyboard-Tap-Ausfall innerhalb von zehn Sekunden.
- Der Not-Aus deaktiviert Hyper und Gesten, schliesst den Switcher und blockiert Window-Layout-Ausfuehrung. Der AltTab-Kern bleibt aktiv.
- Manuelle Verifikation: `docs/input-safety-checklist.md`.
- Primaerer Safe Mode ist ein persistierter Override, der extern per `defaults` oder Sentinel-Datei gesetzt und vor `Preferences.initialize()` beziehungsweise jeder Input-Modulinitialisierung gelesen werden kann.
- Ein beim manuellen Start gedrueckter Modifier bleibt als zusaetzlicher Safe-Mode-Zugang erhalten, ist aber nicht der primaere Mechanismus.
- Vor dem Scharfschalten eines riskanten Moduls wird ein modulspezifischer Arming-Marker geschrieben. Nach bestandener Start-Stabilitaetsfrist wird er entfernt.
- Ein beim naechsten Start verbliebener Marker deaktiviert genau dieses Modul und fuehrt zu einer sichtbaren Meldung.
- Der Marker deckt Crash, erzwungenen Neustart und Hang waehrend der Start-/Scharfschaltungsphase ab. Er ist kein Nachweis fuer spaetere Laufzeitstabilitaet.
- `tapDisabledByTimeout` und `tapDisabledByUserInput` werden gezaehlt. Nach wiederholtem Auftreten oeffnet ein Circuit Breaker: Tap bleibt aus, Modul wird deaktiviert und der Nutzer informiert.
- Ein zusaetzlicher Watchdog darf Callback-Laufzeiten und ausstehende AX-Operationen beobachten. Er ersetzt weder den systemischen Tap-Timeout noch `AXUIElementSetMessagingTimeout` und kann einen bereits blockierten synchronen Aufruf nicht verlaesslich abbrechen.

Private-API-Leitplanke:

- Private API ist zulaessig, wenn sie im bestehenden API-Wrapper-Layer zentralisiert ist.
- Private Symbole muessen optional oder weak gebunden werden, damit Symbolwegfall ein Feature degradiert statt den App-Start zu gefaehrden.
- Private-API-Nutzung wird gegen `ProductVersion` gegated.
- Ausfall degradiert genau ein Feature.
- Neue Module fuehren keine eigenen `dlopen`-Pfade ein.
- Multitouch bleibt Sonderfall: Das Risiko liegt weniger in "private API" an sich, sondern in ABI-Drift und falsch interpretierten Structs im Input-Callback-Pfad.

## Tahoe-Feature-Matrix

Vor Scope-Entscheidungen zu Snapping und Layouts am Zielgeraet klaeren:

- Native Tiling-Features auf macOS Tahoe / Apple Silicon verifizieren: Drag-to-edge, Drag-to-corner, Drag-to-menubar, Option-Modifier, Layout-Previews, `Fn-Control-*` Shortcuts.
- Konsequenz dokumentieren: Alles, was Tahoe nativ gut abdeckt, wird nicht nachgebaut.
- Snapping- und Layout-Scope nur gegen diese Zielplattform schneiden.
- Keine Test- oder Kompatibilitaetsmatrix fuer Intel oder aeltere macOS-Versionen pflegen.
- Vor Entfernen von Kompatibilitaetscode pruefen, ob der dauerhafte Rebase-Aufwand gegen upstream dadurch steigt.

## Usecases

### 0. Gemeinsamer Aktions- und Triggerkern

Status: Geplant; Dual-Role-Hyper und Apps/URLs-Register umgesetzt
Prioritaet: Sehr hoch

Beschreibung:

- Umgesetzt: 9 App- und 9 URL-Slots im Aktionsregister, je mit eigenem globalem Shortcut und Settings-Tab `Apps & URLs`; Verfuegbarkeit meldet fehlende Installation bzw. ungueltige URL.
- Typisiertes Aktionsregister fuer AltTab+-Fensteraktionen, Apps und URLs.
- Getrennte Trigger fuer globale Shortcuts, Dual-Role-Hyper, Leader-Sequenzen und FlickRing.
- Trigger liefern nur eine Aktions-ID; die Ausfuehrung geschieht ausserhalb des Event-Tap-Callbacks.
- Keine Shell-Kommandos oder beliebig skriptbaren Makros im ersten Umfang.

Dual-Role-Hyper:

- Caps Lock bleibt in macOS unter Modifier Keys normal auf `Caps Lock` abgebildet; AltTab+ unterdrueckt das native Event nur bei aktiviertem Modul.
- Kurzes Antippen schaltet Caps Lock ein oder aus; die Tap-/Hold-Schwelle ist konfigurierbar.
- Halten plus Taste ergaenzt das vollstaendige Key-down-/Key-up-Paar systemweit um `Command+Control+Option+Shift`.
- Es werden keine eigenstaendig gehaltenen Modifier-down-/Modifier-up-Events erzeugt.
- Das Modul startet deaktiviert.
- Pfeiltasten koennen vorhandenen Thirds-, Two-Thirds- und Restore-Aktionen zugeordnet werden; konfigurierte interne Paare werden vollstaendig absorbiert.
- Hyper-Kombinationen werden einheitlich als systemweite Shortcuts behandelt; Window Layouts nutzen dieselben globalen Shortcut-Felder wie andere Hyper-Ziele.
- Folgeumfang nach S-09: optionale Variante ohne Dual-Role. Eine reine 1:1-Umbelegung von Caps Lock auf einen Modifier ueber `hidutil UserKeyMapping` liegt unterhalb des Event-Taps und wirkt deshalb auch bei aktivem Secure Input, wo der HID-Monitor nichts meldet. Preis ist der Verlust der Tap-Funktion, da `hidutil` keine Tap-Hold-Logik kann. Nur als bewusst gewaehlte Alternative anbieten, nie als Default, und den Vorwert wie jeden globalen Systemzustand besitzen und zurueckgeben.

Leader:

Umsetzungsstand 2026-08-03, Kern:

- Befund mit Folgen fuer den Zuschnitt: Der Tastatur-Tap in `KeyboardEvents` wird beim App-Start unbedingt erzeugt und deckt `keyDown`, `keyUp` und `flagsChanged` bereits ab; Hyper ist darin nur ein Laufzeit-Flag. Leader faehrt deshalb auf demselben Tap mit, statt einen zweiten zu oeffnen. Damit entfallen ein eigener Arming-Marker, ein eigener Circuit Breaker und eine zweite Stelle, an der ein haengender Callback das System blockieren koennte.
- Umgesetzt als reine Logik mit 12 Tests: Trie fuer verschachtelte Sequenzen, Sitzungsautomat, Timeout, Escape.
- Festgelegt: Ein Knoten fuehrt entweder eine Aktion aus oder fuehrt zu weiteren Tasten, nie beides. Ein Praefix, das zugleich Bindung ist, waere mehrdeutig und der Nutzer koennte nicht erkennen, ob noch Tasten folgen duerfen.
- Festgelegt: Eine Taste ohne Treffer bricht die Sequenz ab, statt ignoriert zu werden. Tastenanschlaege stillschweigend zu schlucken ist schlechter, als den Nutzer neu ansetzen zu lassen.
- Noch nicht umgesetzt: Trigger-Anbindung, Interception im Tap-Callback, die kompakte AppKit-Uebersicht und die Settings-Oberflaeche zum Pflegen der Sequenzen. Ohne diese ist das Modul nicht aktivierbar.

- Leader erhaelt einen eigenen, noch festzulegenden Trigger; Caps-Lock-Tap bleibt fuer normales Caps Lock reserviert.
- Verschachtelte, deterministische Sequenzen verwenden einen Trie oder eine gleichwertige Zustandsmaschine.
- `Escape`, Timeout und Sleep/Wake brechen die Sequenz ab.
- Kompakte AppKit-Uebersicht; keine Uebernahme der SwiftUI-Oberflaeche von LeaderKey.

FlickRing:

- Zusaetzliche Maustaste, Totbereich, vier Richtungen und Ausfuehrung beim Loslassen.
- MVP reserviert eine Seitentaste vollstaendig.
- Durchreichen eines normalen Mittelklicks benoetigt markierte, rekursionssichere Event-Wiedergabe und ist Folgeumfang.

Akzeptanzideen:

- Hyper-Aktion wird pro physischem Tastendruck genau einmal ausgeloest.
- Wiederholte Key-down-Events werden absorbiert, ohne die Aktion erneut auszufuehren.
- Key-up wird auch nach vorzeitigem Loslassen von Caps Lock absorbiert.
- Kurzes Caps-Lock-Tippen schaltet Caps Lock genau einmal; ein verwendeter oder zu lange gehaltener Druck schaltet nicht.
- Nicht intern konfigurierte Kombinationen erreichen andere Apps als vollstaendige Hyper-Key-Paare.
- Deaktivierung und Reset hinterlassen keinen aktiven Zustand.
- AltTab-Switcher-Shortcuts behalten Vorrang, solange die Switcher-Oberflaeche aktiv ist.

### 1. AX-Fensteroperations-Kern

Status: Gemeinsame technische Basis
Prioritaet: Sehr hoch

Beschreibung:

- Gemeinsamer Kern fuer Keyboard Layouts, Modifier Move/Resize und Snapping.
- Modifier Move und Modifier-Snapping verwenden dieselbe Drag-Sitzung; Fensterauflösung, Ursprungsrahmen, Display-Geometrie, Overlay und Abschluss werden nicht von zwei konkurrierenden Trackern verwaltet.
- Identifiziert das betroffene Fenster robust.
- Setzt Fensterposition und Fenstergroesse ueber Accessibility API.
- Filtert ungeeignete Fenster aus, statt riskant zu mutieren.

Fenster-Identifikation nach Modul:

1. Keyboard Layouts verwenden die Frontmost-App und deren `kAXFocusedWindow`.
2. Move/Resize und Drag-Snapping beginnen mit `AXUIElementCopyElementAtPosition` an der Mousedown-Position.
3. Fuer Cursor-Module folgt ein Ancestor-Walk bis `AXWindow`.
4. CGWindowID-Korrelation via `_AXUIElementGetWindow`; AltTab besitzt bereits eine Bruecke in `src/api-wrappers/AXUIElement.swift`.
5. Nur bei Fehlschlag: `kAXFocusedApplication` / `kAXFocusedWindow`.
6. Nur bei weiterem Fehlschlag: `CGWindowListCopyWindowInfo`-Match ueber PID und Bounds.
7. Bei Restunsicherheit: keine Aktion.

Umsetzungsstand 2026-07-26:

- Fuer Keyboard Layouts umgesetzt: Frontmost-App, fokussiertes AX-Fenster, eigene AX-Queue, globaler AX-Timeout, Rollen-/Zustands-/Settable-Filter und sichtbare Display-Geometrie.
- Umgesetzt 2026-07-31 fuer kontinuierliche Cursor-Module: Element-at-position-Kette mit begrenztem Ancestor-Walk bis `AXWindow`, CGWindowID-Korrelation, Fokus-Fallback und eindeutiger Bounds-Match als letzte Stufe; Mehrdeutigkeit fuehrt zu keiner Aktion. Dazu das Q-06-Coalescing (hoechstens ein offener Set, nur der neueste Zielrahmen, Zielrate 60 Hz, Flush bei Mouseup) und der Q-07-Ringpuffer mit Fenster-ID, Bundle-ID, Display, vorgeschlagenem und tatsaechlichem Rahmen.
- Die Reihenfolge der Stufen, das Coalescing und der Ringpuffer sind reine Logik und mit 12 Tests abgedeckt. Die Kette selbst ist nur so gut wie die manuelle Pruefung: S-01 (20 von 20 ueber die Kompatibilitaetsmatrix) und S-02 (Drag-Latenz) sind unveraendert offen.
- Noch nicht angebunden: es gibt bisher keinen Aufrufer. Die Drag-Sitzung, die diesen Kern benutzt, gehoert zu Phase 3B.
- Offen bleibt die vollstaendige App-Klassen-Matrix.

Ausschlussfilter:

- Fullscreen-Fenster.
- Fenster in anderen Spaces.
- Stage-Manager-Zustand.
- `AXMinimized`.
- Fenster ohne settable `kAXSizeAttribute`.
- Fenster mit min gleich max Size, z.B. Sheets oder Panels.

Umsetzungsstand 2026-08-01, am Zielgeraet verifiziert:

- Befund: In Electron-Apps (Claude Desktop, Claude Code, Bitwarden) liefert `AXUIElementCopyElementAtPosition` eine `AXGroup`, deren Elternkette nie ein `AXWindow` erreicht. Chromium-Browser sind nicht betroffen: Brave loeste ohne Workaround korrekt auf.
- Behoben: `AXManualAccessibility` wird einmal je Prozess auf dem App-Element gesetzt und die Aufloesung genau einmal wiederholt. Danach loesen Claude Code und Bitwarden korrekt auf, manuell bestaetigt.
- Ergaenzt: Scheitert die Kette weiterhin, entscheidet die Fensterliste der App ueber den enthaltenen Punkt, aber nur bei genau einem Treffer.
- `AXEnhancedUserInterface` wird nur fuer die Dauer des Schreibvorgangs abgeschaltet und nur, wenn es vorher gesetzt war; bei laufendem VoiceOver entfaellt der Workaround.
- Beobachtung fuer die App-Klassen-Matrix: Gemini (`com.google.GeminiMacOS`) klemmt die y-Koordinate hart auf den Displayrand, waehrend x folgt. Das ist eine Randbegrenzung des Fensters, kein AX-Fehler, und wird nicht umgangen.
- Behoben: Safe Mode unterdrueckte das Move-Modul unsichtbar. Die Auswahl eines Modifiers meldet die Unterdrueckung jetzt als selbst verschwindender Hinweis, und das Verlassen des Safe Mode baut den Tap eines bereits gewaehlten Modifiers sofort wieder auf statt erst beim naechsten Start.

Chrome/Electron/AX:

- `AXEnhancedUserInterface`-Workaround direkt einplanen.
- Attribut nur fuer die Dauer der Operation deaktivieren und danach Originalwert restaurieren.
- Bei aktivem VoiceOver oder anderem Assistive-Technology-Tool Workaround ueberspringen.
- Fuer Electron `AXManualAccessibility` als seiteneffektfreie Alternative pruefen.

Private-API-Befund:

- `_AXUIElementGetWindow` ist vorhanden und wird optional zur Laufzeit gebunden.
- Ein Symbolwegfall degradiert die jeweilige Fenster-ID-Abfrage, statt den App-Start zu gefaehrden.

Kompatibilitaetsmatrix:

- AppKit.
- Catalyst.
- Chromium.
- Electron.
- AWT/Swing.
- Qt.
- Terminal-Apps mit Zeichenraster-Clamping.

### 2. Keyboard-basierte Window Layouts

Status: Erste Ausbaustufe implementiert
Prioritaet: Hoch

Beschreibung:

- Tastatur-Layoutaktionen fuer Fenster, ohne Event-Tap, ohne Overlay, ohne Drag-Tracking und ohne private API.
- Nutzt den AX-Fensteroperations-Kern.
- Deckt besonders Luecken gegenueber Apple ab.

Erste umgesetzte Ausbaustufe:

- Thirds.
- Two-Thirds.
- Three-Quarters.
- Left-, Center- und Right-Focus-Layouts.
- Ein-Schritt-Restore auf den Rahmen vor der ersten Layoutaktion der laufenden Sitzung.
- Keine Shortcuts vorregistrieren.
- Kollisionspruefung gegen registrierte AltTab-Hotkeys.

Folgeumfang nach Tahoe-Feature-Matrix:

- Klassisches Center ohne Resize, falls die Tahoe-Feature-Matrix einen Bedarf zeigt; `Center focus` ist bereits umgesetzt.
- Display-Moves.
- Optionaler Preset-Picker.
- Halves/Quarters nur, wenn die Tahoe-Feature-Matrix echten Bedarf zeigt.

Nicht im MVP:

- Allgemeiner Undo-Stack oder chronologischer Verlauf ueber mehrere Fenster; Restore bleibt zunaechst eine Ein-Schritt-Aktion pro Fenster.
- Shortcut-Wiederholung zum Zyklieren.
- Pro-Display Grid-Definitionen.
- App-spezifische Layout-Regeln.

Repo-Learnings:

- Nudge nutzt Magnet-nahe Defaults mit `Ctrl + Option` und bietet Halves, Quarters, Thirds, Two-Thirds, Maximize, Center, Restore und Display-Wechsel.
- Rectangle bietet viele explizite Aktionen, darunter Thirds, Two-Thirds, Viertel, Achtel, Neuntel, Center, Restore und Display-Wechsel.
- Rectangle-Defaults sind bei Zielnutzern haeufig schon belegt; deshalb keine Default-Shortcuts.
- `Fn-Control-*` gehoert ab aktuellen macOS-Versionen Apple und ist als Default ausgeschlossen.
- Bewertetes Fremdkonzept (Vier-Schichten-Modell fuer Tastatur-Customizing): uebernommen werden die additive Ueberlagerung mit Rollback statt Abschalten von Systemdefaults sowie die Kompatibilitaetsklassen pro App. Nicht uebernommen werden das Generieren von `DefaultKeyBinding.dict` und das Schreiben von `NSUserKeyEquivalents` in fremde Preference-Domains: beides betrifft Textnavigation und Menueeintraege fremder Apps, vervielfacht das State Ownership ueber fremde Domains und faellt unter das Nicht-Ziel `beliebige Makros oder ein allgemeiner Launcher`. Eine deklarative Einzelquelle mit Dry-Run bleibt hoechstens Profil-Export in 2D.
- Erhebung der Symbolic Hotkeys auf Tahoe (2026-07-28): `Control+1` bis `Control+0` (ids 118-127) sind standardmaessig deaktiviert und damit ohne Systemaenderung fuer `Space 1` bis `Space 9` verwendbar. `Control+Pfeil` traegt je drei ids (79/199/240 und 81/200/241); da `Fn-Control-Pfeil` zu Apples Tiling gehoert, sind sie einzeln abzuschalten und das native Tiling ist nach jedem Schritt zu pruefen.
- Fehler in der Hotkey-Zuordnung gefunden und behoben: `CGSSymbolicHotKey.commandKeyAboveTab` zeigte auf id 6, die auf Tahoe `Shift+Option+Command+Escape` (Sofort beenden erzwingen) ist. Wer `Command` plus Taste ueber Tab zuwies, deaktivierte damit den Notausstieg des Systems, waehrend die eigentliche Kombination bei macOS blieb. Richtig sind 27 und, als Shift-Variante, 220.

### 2B. Instant Spaces

Status: Kern implementiert, manuelle Tahoe-Verifikation S-06 offen
Prioritaet: Mittel

Beschreibung:

- Native macOS Spaces ohne sichtbare Wechselanimation nach links, rechts oder direkt zu einem Index wechseln.
- Inspiration: `jurplel/InstantSpaceSwitcher`.
- Ziel-Display ist standardmaessig das Display unter dem Cursor.
- Aktionen werden im gemeinsamen Aktionsregister angeboten und koennen von Shortcuts, Hyper, Leader, FlickRing oder der Spaces-Menueleiste ausgeloest werden.

MVP-Scope:

- `Space left`, `Space right`, `Last Space` und `Space 1` bis `Space 9`.
- `Last Space` toggelt zwischen dem aktuellen und dem zuletzt abgeschlossenen Space desselben Displays. Zwischenstationen eines Mehrschritt-Wechsels zaehlen nicht; nach Displaywechsel, Wake und Neustart ist die Historie leer, bis ein Wechsel beobachtet wurde.
- Kein Wrap am ersten oder letzten Space.
- Keine Default-Shortcuts; ohne zugewiesenen Shortcut und bei ausgeblendeter Spaces-Menueleiste gibt es keinen aktiven Ausloeser.
- Presets statt Defaults: das sinnvolle Set wird als benannte Zuweisung per Klick angeboten und ebenso wieder entfernt. `macOS Spaces` belegt `Control` plus 1 bis 9, `Control+0` fuer den Toggle und `Control` plus Pfeil fuer links/rechts; `Hyper Spaces` dasselbe auf der Hyper-Ebene ohne Systemuebernahme. Fuer Layouts gibt es `Rectangle-style` auf `Control+Option` mit den Buchstaben von Rectangle und `Hyper` mit denselben Buchstaben. Zuweisen ueberschreibt bestehende Belegungen und sichert den Vorzustand; Entfernen stellt genau diesen wieder her. Die Recorder-Felder folgen der Zuweisung sofort, damit sichtbar ist, was ein Preset gesetzt hat. Pro Bereich ist genau ein Preset aktiv; die uebrigen sind gesperrt, solange eines zugewiesen ist. Der aktive Zustand wird gespeichert und nicht aus den Zuweisungen abgeleitet, sonst wuerde eine einzelne Aenderung den Bereich still freigeben. Wurde waehrend eines Presets etwas angepasst, fragt das Entfernen nach, weil der Vorzustand diese Anpassungen verwirft.
- Systemshortcuts werden nur uebernommen, solange die eigene Zuweisung besteht. Der Vorzustand jedes Symbolic Hotkeys wird persistiert und beim Entfernen sowie beim naechsten Start nach einem Absturz zurueckgegeben. `defaults write` dient nur als Rueckfall, wenn der WindowServer die Aenderung ablehnt; dann erscheint ein selbst verschwindender Hinweis auf den noetigen Dock-Neustart.
- Keine Aktion, solange Mission Control oder App Expose verlaesslich als aktiv erkannt wird.
- Feste, auf Tahoe kalibrierte Wechselgeschwindigkeit; kein Speed-Slider im MVP.

Technischer Ansatz:

- Funktionale Swift-Reimplementierung; keine direkte Uebernahme des C-Kerns.
- Wechsel durch eine kurze synthetische Dock-Swipe-Sequenz mit hoher Geschwindigkeit.
- Der MVP postet Events nur bei einer Aktion und benoetigt keinen permanenten Event-Tap.
- Bestehende `Spaces`-/Display-Logik und `CGSCopyManagedDisplaySpaces`-Daten wiederverwenden.
- Private CGS-Symbole zentral im API-Wrapper-Layer optional binden; private Gesture-Event-Typen und -Feldnummern dort zentralisieren und nach macOS-Version gaten.
- Nur auf verifizierten Tahoe-Builds aktivieren; bei unbekannter macOS-Major-Version oder fehlenden Symbolen Modul sichtbar deaktivieren.
- Accessibility muss bereits erteilt sein; andernfalls bleibt die Aktion unverfuegbar und die bestehende Berechtigungsfuehrung des AltTab-Kerns greift.
- Erwarteten Zielindex pro Display nur kurzfristig vorhersagen. Bei `activeSpaceDidChange`, Display-Reconfiguration, Wake, Fehler oder abweichendem Ist-Zustand verwerfen und aus dem Systemzustand neu synchronisieren.
- Direkter Mehrfachwechsel darf nicht dauerhaft auf einer Vorhersage weiterlaufen; Abschluss und naechste Aktion werden mit dem tatsaechlichen Space abgeglichen.
- Erkennung von Mission Control/App Expose ueber Dock-Window-Layer ist empirisch und muss auf Tahoe verifiziert werden; bei unzuverlaessigem Befund keine invasive Unterdrueckung anderer Systemgesten.

Implementierungsstand:

- `Space left`, `Space right`, `Last Space` und `Space 1` bis `Space 9` sind mit stabilen IDs im gemeinsamen Aktionsregister vorhanden.
- Der Swift-Kern sendet die kurze Began-/Changed-/Ended-Sequenz nur bei einer Aktion und verwendet keinen permanenten Event-Tap.
- Befund vom 2026-07-27 aus der Mausbedienung: bei grossen Spruengen flackerte der Bildschirm, weil jeder Swipe ein echter Space-Wechsel ist. Der Versuch, das ueber `CGSManagedDisplaySetCurrentSpace` zu umgehen, wurde am 2026-07-27 am Zielgeraet verworfen: der Wechsel war zwar sofort und flackerfrei, legte aber die Fenster des Ziel-Space ueber den sichtbaren, statt zu wechseln, und beschaedigte auch die native Space-Auswahl in Mission Control, bis der Dock neu gestartet wurde. Das Flackern bleibt damit systembedingt; Mehrschritt-Spruenge werden seither hinter einer kurzen `CGDisplayFade`-Ueberblendung versteckt (oeffentliche API, Reservation verfaellt selbststaendig nach zwei Sekunden).
- Befund vom 2026-07-28, per Messung geklaert: Beim Durchklicken landete der Wechsel regelmaessig wieder auf Space 2. Das Trace-Log zeigt, dass der Wechsel jedes Mal korrekt und in rund 50 ms ankommt und die Sequenz sauber endet; rund 280 ms spaeter meldet das System einen weiteren Wechsel zurueck auf denselben Space. Der Rueckzug kommt also von aussen, nicht aus der Schrittlogik. Ursache am 2026-07-28 vollstaendig geklaert: Der Wechsel auf einen leeren Space wird von macOS zurueckgezogen, weil dort kein Fenster zu aktivieren ist, die zuvor aktive App aktiv bleibt und die Einstellung `Beim Wechsel zu einer App zu einem Space mit offenen Fenstern der App wechseln` den Bildschirm zu deren Fenstern holt. Zielspace war deshalb immer der Space mit dem AltTab+-Fenster. Ein Fenster auf dem Ziel-Space oder das Abschalten der Einstellung behebt es; AltTab+ aendert die Systemeinstellung nicht, sondern dokumentiert sie im README. Belegkette: der Rueckzug tritt ausschliesslich nach Ankunft auf einem bestimmten Space auf, ohne vorangehende App-Aktivierung, und der Nutzer wird beim nativen Wechsel auf denselben Space per `Control+Pfeil` oder Wischgeste genauso zurueckgeworfen. Der Space-Wechsel selbst ist damit als korrekt belegt; das Zurueckziehen gehoert zur Space-Konfiguration des Systems. Eine Deaktivierungs-Gegenmassnahme wurde eingebaut und nach der Widerlegung wieder entfernt.
- Spike vom 2026-07-28 zur Menueleisten-Latenz, negativ abgeschlossen: `NSWorkspace.activeSpaceDidChangeNotification` trifft zwischen 50 und 290 ms nach dem tatsaechlichen Wechsel ein, weshalb die Leiste bei nativem `Control+Pfeil` hinterherhinkt. Eine direkte WindowServer-Benachrichtigung ueber `CGSRegisterNotifyProc` und `CGSRegisterConnectionNotifyProc` wurde geprueft: die Registrierung meldet Erfolg (verbindungsbezogen sogar fuer jeden getesteten Typ von 1000 bis 1600, der Rueckgabewert ist also wertlos), es wurde aber keine einzige Zustellung beobachtet, auch nicht fuer selbst erzeugte Fensterereignisse. Ohne dokumentierte Notification-Nummer und ohne belegte Zustellung bleibt nur Polling, was der Festlegung `Kein Polling-Timer` und dem Energie-Release-Gate widerspricht. Das Thema ruht; die Leiste folgt bei eigenen Aktionen sofort und bei nativen Wechseln mit der Latenz der Systembenachrichtigung.
- Die temporaere Messinstrumentierung wurde nach Abschluss der Untersuchung wieder entfernt; die Befunde stehen hier, der Wechselpfad ist wieder frei von Trace-Aufrufen.
- Messwerte aus demselben Log: ein einzelner Swipe wird zuverlaessig angenommen und der Wechsel ist nach 45 bis 75 ms gemeldet. Die Sequenz-Generationen und das schrittweise Schalten bleiben, sind aber nicht die Ursache der beobachteten Fehlspruenge gewesen.
- Regression vom 2026-07-28: Der Lift-Effekt in der Menueleiste trat erneut auf, weil die Leiste bereits beim Posten des letzten Swipes freigegeben wurde, waehrend die Wechsel-Benachrichtigungen noch eintrafen. Die Sequenz bleibt jetzt bis zur beobachteten Ankunft gesperrt; eine kurze Poll-Schleife (4 x 150 ms) haelt die Markierung trotzdem dicht an der Ankunft.
- Befund vom 2026-07-27 aus der Mausbedienung: bei grossen Spruengen liefen Bildschirm und Menueleiste sichtbar durch jeden Zwischen-Space. Die Leiste ueberspringt ihre Aktualisierung jetzt waehrend einer laufenden Sequenz und zeigt erst den Ankunfts-Space. Das Durchlaufen der Bildschirme selbst bleibt systembedingt: jeder Swipe ist ein echter Space-Wechsel; nur `stepInterval` verkuerzt die sichtbare Dauer.
- Befund vom 2026-07-27 aus der Mausbedienung: Mehrschritt-Wechsel wurden als Burst gepostet und die Zielvorhersage als Tatsache gespeichert; verschluckte Swipes fuehrten dadurch zu Spruengen auf fremde Spaces. Der Kern schaltet jetzt schrittweise, liest den Ist-Space zwischen den Schritten und prueft nach dem letzten Schritt nach. `stepInterval` und `settleInterval` sind Schaetzwerte und am Zielgeraet zu kalibrieren.
- CGS-Symbole werden ueber `dlopen`/`dlsym` optional aufgeloest; macOS-Major-Versionen ausserhalb Tahoe und fehlende Symbole bleiben fail-closed.
- Planung, Randbegrenzung, direkte Ein-basierte Indizes, Dock-Overlay-Erkennung und eindeutige Action-IDs sind automatisiert getestet.
- S-06 und V-12 bleiben offen, bis die Event-Felder, sichtbare Animationsfreiheit, Multi-Display-Semantik und schnelle Folgewechsel ueber eine Bedienoberflaeche am Tahoe-Zielgeraet geprueft wurden.

Nicht im MVP:

- Echte Trackpad-Swipes abfangen, unterdruecken oder ersetzen.
- Permanenter Gesture-/Dock-Control-Event-Tap.
- Konfigurierbare Swipe-Geschwindigkeit.
- Wrap-around.
- Beliebige Space-Namen oder dauerhafte Zuordnung zu Space-IDs; dies folgt im Spaces-Menueleisten-Modul erst nach verifizierter stabiler Identitaet.
- Eigener CLI-Umfang; spaeter optional ueber das bestehende AltTab+-Aktionsmodell.

Folgeumfang:

- Optionaler Swipe-Override erst neben dem Gestenmodul und nur nach Q-01, Q-04, Q-09, Q-11, Q-12 sowie Energie- und Konfliktpruefung.
- Reale HID-Swipes von synthetischen AltTab+-Events unterscheiden, Began/Changed/Ended vollstaendig behandeln und bei Mission Control, App Expose oder unbekanntem Zustand unveraendert durchreichen.

Repo-Learnings:

- InstantSpaceSwitcher nutzt native Spaces ohne SIP-Deaktivierung, indem es synthetische Dock-Swipe-Events mit empirisch sehr hoher Geschwindigkeit postet.
- Es ermittelt Space-Anzahl und aktiven Index pro Display, begrenzt Randwechsel und unterstuetzt direkten Indexwechsel.
- Fuer schnelle Folgeaktionen fuehrt es pro Display einen vorhergesagten Index; AltTab+ uebernimmt dieses Verhalten nur mit expliziter Resynchronisation.
- Der optionale Swipe-Override verwendet private Event-Typen/-Felder und einen aktiven Event-Tap; deshalb kein MVP-Bestandteil.

### 2C. Spaces in der Menueleiste

Status: Mehrdisplay-Gruppierung und Ueberlauf implementiert; S-07 (VoiceOver, Create/Delete/Reorder, reale Klickgeometrie) manuell am Zielgeraet offen
Prioritaet: Mittel bis hoch

Beschreibung:

- Rechts neben dem bestehenden AltTab+-Symbol erscheint optional eine kompakte Reihe der verfuegbaren Spaces.
- Der aktive Space wird monochrom hervorgehoben: schwarz im Light Mode und weiss im Dark Mode.
- Ein Klick auf einen Space aktiviert ihn direkt ueber dieselbe typisierte `Space n`-Aktion wie Shortcut, Hyper, Leader oder FlickRing.
- Konfigurierbare Space-Shortcuts bleiben als vollwertiger Fallback erhalten; die Menueleiste ist kein exklusiver Bedienweg.

Darstellung und Interaktion:

- Ein einzelnes `NSStatusItem` mit variabler Breite und AppKit-Custom-View haelt AltTab+-Symbol und Space-Segmente in stabiler Reihenfolge zusammen. Das Symbol behaelt sein bisheriges Menue- und Klickverhalten; jedes Space-Segment besitzt einen eigenen Hit-Bereich, Tooltip und Accessibility-Namen.
- MVP-Labels sind `1...n`. Optional benannte Spaces zeigen einen kurzen Alias; bei Platzmangel faellt die Leiste auf Nummern zurueck und bietet die vollstaendige Liste im Menue.
- Segmentbreiten sind stabil begrenzt. Viele Spaces oder Displays duerfen andere Status-Items nicht unkontrolliert verdraengen; Ueberlauf wird in ein Menue beziehungsweise einen kompakten `...`-Eintrag verschoben.
- Kein Polling-Timer. Aktualisierung bei `activeSpaceDidChange`, Display-Reconfiguration, Wake, Rueckkehr aus Mission Control, Menueoeffnung und nach einer eigenen Space-Aktion.
- Ein Klick bleibt deaktiviert, wenn Instant Spaces wegen unbekannter macOS-Version, fehlender Symbole, Mission Control/App Expose oder fehlender Berechtigung nicht sicher arbeiten kann. Der sichtbare aktuelle Zustand darf trotzdem angezeigt werden.

Implementierungsstand:

- Die allgemeine Einstellung `Show Spaces next to the menubar icon` ist vorhanden und per Default aus.
- Das bestehende `NSStatusItem` zeigt rechts vom AltTab+-Symbol nummerierte Segmente, gruppiert nach Display in Links-nach-rechts-Reihenfolge, mit duennem Trenner zwischen Gruppen; ab dem neunten Space je Display fasst ein `…`-Segment die restlichen in einem Menue zusammen.
- Ein Klick auf eine Nicht-Cursor-Gruppe wird verworfen, wenn Cursor- und Gruppen-Display auseinanderfallen (nur bei einer einzigen, nicht gespiegelten Menueleiste moeglich); Instant Spaces kann kein Zieldisplay ueber die synthetischen Gesten adressieren. Diese Sperre gilt seit 2026-08-05 nur noch bei aktivierten separaten Spaces: ist die Systemeinstellung aus, schaltet eine Geste den ganzen Verbund, und die Sperre haette einen Klick vom Nebenbildschirm still verschluckt.
- Der aktive Space verwendet eine staerkere monochrome Umrandung und eine dezente Flaeche; Tooltip und Accessibility-Label benennen das direkte Ziel.
- Klicks laufen ueber die registrierte `Space n`-Aktion. Space-, Display- und Wake-Ereignisse aktualisieren die Reihe ohne Polling.
- Eigene Spaces-Settings bieten konfliktgepruefte globale Shortcuts fuer links, rechts und Space 1 bis 9; alle bleiben per Default unbelegt.
- Manueller Befund vom 2026-07-27: Zum Aufzeichnen eines Space-Shortcuts musste Hyperkey in den Settings einmal aus- und wieder eingeschaltet werden. Die Ursache ist weiterhin nicht belegt.
- Statische Analyse dazu: Ein geroutetes Key-Code-Mapping ueberlebte ein ausgebliebenes Key-Up, wodurch jeder spaetere Druck derselben Taste weiterhin die Hyper-Modifier trug, bis `resetHyperKeyState` lief — genau das loest das Aus-/Einschalten von Hyperkey aus. Der Zustandsautomat verwirft ein solches veraltetes Routing jetzt beim naechsten frischen Tastendruck. Ob das der beobachtete Fall war, ist offen und am Zielgeraet zu pruefen.
- **Befund vom 2026-08-05 am Zielgeraet, Ursache belegt**: Die Menueleisten-Reihe folgt dem Anlegen eines Space nicht. Beim Anlegen eines zweiten Space auf dem zweiten Display blieb die Reihe unveraendert; das neue Segment erschien erst nach einem Klick auf ein Space-Icon, mit der bekannten Verzoegerung. Ursache ist eindeutig: die Reihe haengt an genau einem Ausloeser, `NSWorkspace.activeSpaceDidChangeNotification` in `SpacesEvents.observe()`. Diese Benachrichtigung feuert beim *Wechsel* des aktiven Space, nicht beim *Anlegen* oder *Loeschen* eines Space. Der Klick wechselte den Space und loeste damit nachtraeglich `Spaces.refresh()` und `Menubar.refreshSpaces()` aus. Damit sind die Checklistenschritte 13 und 14 nicht bestanden; Loeschen zeigt denselben Fehler aus derselben Ursache.
- **Befund vom 2026-08-05 am Zielgeraet, gleiche Wurzel**: Die Abblendung der Segmente ist veraltet, und das macht Knoepfe unbedienbar. Beobachtet wurden drei Symptome: Fokus auf einem Fenster des zweiten Bildschirms laesst dessen Segmente dunkel; ein Klick auf ein Segment dieser Gruppe vom anderen Bildschirm aus aendert nichts; und es brauchte drei Klicks auf dasselbe Segment, bis der Wechsel ankam. Ursache: `crossDisplay` und `isEnabled` haengen beide an `cursorUuid == group.displayUuid` (Menubar, Aufbau der Gruppensegmente), die Reihe wird aber nur bei `activeSpaceDidChange` neu gebaut. Der Cursor wechselt das Display, ohne diese Benachrichtigung auszuloesen, also zeigt die Abblendung, wo der Cursor beim letzten Space-Wechsel stand. Ein Segment ist dann nicht nur auf `alphaValue` 0.4 abgeblendet, sondern per `isEnabled` tot; die ersten Klicks laufen ins Leere, bis irgendein anderer Weg einen Neuaufbau ausloest. Der alte Testplan hat den doppelten Klick bereits als Verdacht gefuehrt; er ist damit belegt und erklaert.
- **Gegenprobe vom 2026-08-06, entlastet einen Verdaechtigen**: Am selben Rechner laeuft `Ice`, ein Menueleisten-Manager, der ueber der Menueleiste liegt und als Erklaerung fuer den mehrfachen Klick ebenso plausibel waere. Er scheidet aus: mit ausgeschalteten separaten Spaces genuegte **ein** Klick und die ganze Anordnung wechselte, waehrend mit eingeschalteten separaten Spaces drei Klicks noetig waren. Ice lief in beiden Laeufen, kann den Unterschied also nicht verursachen. Der Unterschied liegt genau bei `clickIsReachable`, das ohne getrennte Spaces immer `true` liefert und den Knopf dauerhaft aktiv laesst. Kein Beweis, aber ein sauberer Unterscheidungstest.
- **Bestaetigt vom 2026-08-06**: Schritt 14 faellt tatsaechlich durch, vorher nur abgeleitet. Nach dem Reduzieren auf einen einzigen Space zeigte die Reihe unveraendert drei Segmente. Das Loeschen wechselt den aktiven Space nicht, also feuert die Benachrichtigung nicht. Erschwerend: bei nur noch einem Space gibt es kein zweites Segment mehr, ueber das sich ein Neuaufbau nachtraeglich ausloesen liesse — der Nutzer sitzt dann vor einer dauerhaft falschen Reihe, bis ihn ein anderer Weg erloest.
- **Schluesselbeobachtung vom 2026-08-06**: Ein blosser Rechtsklick auf das Statusitem brachte die Reihe sofort von drei auf ein Segment, ohne dass in den Settings etwas geaendert wurde. Ursache ist `statusItemOnClick()`, das als erstes `refreshSpaces()` aufruft; jede Beruehrung des Statusitems baut die Reihe neu. Damit ist der Defekt scharf eingegrenzt: Datenquelle und Neuaufbau sind korrekt, allein der Ausloesezeitpunkt ist zu eng. Das erklaert auch den mehrfachen Klick vollstaendig — der erste Klick landete auf einem per `isEnabled` toten Segment, loeste ueber denselben Handler aber den Neuaufbau aus, wonach der Knopf aktiv war und der naechste Klick ankam.
- **Behoben 2026-08-06, am Zielgeraet bestaetigt**: Anlegen und Loeschen eines Space kommen jetzt ohne Klick an. Das Verlassen von Mission Control (`AXExposeExit`) baut die Reihe neu, und `isCursorGroup` blendet die Segmente nur noch ab, statt sie auch per `isEnabled` totzulegen; die massgebliche Pruefung ist die auf die Live-Cursorposition in `spaceSegmentOnClick`. Checklistenschritte 13 und 14 bestanden.
- **Befund vom 2026-08-06, Reihenfolge bei gestapelten Displays**: Der interne Hauptschirm erscheint als *zweite* Gruppe. Ursache ist die Sortierung der Screens in `spaceGroups()`, die primaer nach `frame.origin.x` geht und y nur als Gleichstandsregel verwendet. Gemessen: interner Schirm bei Origin (0, 0), Widescreen bei (-900, -1440), also darueber und 900 Punkte nach links versetzt. Nach x aufsteigend gewinnt -900, also der Widescreen. Dieselbe Klasse wie die dokumentierte Nachbarerkennung, die nur links und rechts kannte: eine Regel, die eine rein horizontale Anordnung unterstellt. Zu entscheiden ist die gewuenschte Ordnung, bevor das behoben wird — Hauptschirm zuerst waere stabil und entspricht der Erwartung, eine rein physische Ordnung muesste bei gestapelten Displays nach y sortieren.
- **Offen, nicht durch Raten zu klaeren**: Auf dem Widescreen graut nach der Wahl eines anderen Space die Reihe aus und die Wahl muss wiederholt werden; ein anschliessender Klick wird sofort angenommen. `NSScreen.withMouse()` und `cachedUuid()` scheiden als Ursache aus, weil beide im Fehlerfall `nil` liefern und `nil` in beiden Pfaden als *erreichbar* gilt, also gerade nicht abblendet. Verdacht liegt auf einem Neuaufbau, der waehrend der noch nicht abgeschlossenen Wechselsequenz laeuft und `Spaces.visibleSpaces` inkonsistent sieht. Zu diesem Symptom wurden bereits zwei Ursachen vermutet und wieder verworfen; der naechste Schritt ist Instrumentierung von Cursor-UUID, Gruppen-UUID und Wechselzustand zum Zeitpunkt des Neuaufbaus, nicht eine dritte Vermutung. Die Instrumentierung war schon bei der Halteschaltung des Menueleisten-Drops das, was die Sache entschied.
- **Umgesetzt 2026-08-06 nach dem Scheitern von S-10**: Die Reihe nennt jetzt drei Dinge in drei getrennten Kanaelen, damit keines fuer ein anderes gehalten werden kann. Die Anzahl ist die Zahl der Segmente. Der aktive Space ist der gefuellte Hintergrund samt fetterer Ziffer. Der Rahmen traegt **allein** die Erreichbarkeit. Die frueher pauschale Abblendung des ganzen Segments auf 0.4 entfaellt: sie machte Anzahl und aktiven Space des anderen Schirms unlesbar, was der Hauptzweck der Reihe ist. Ein Zwischenstand, bei dem der Rahmen zugleich aktiv und erreichbar kodierte, wurde verworfen — dabei sah „aktiv aber unerreichbar" staerker aus als „inaktiv aber erreichbar", also das Gegenteil der Aussage.
- Zusaetzlich meldet ein abgelehnter Klick sich jetzt sichtbar ueber `TransientNotice`, statt folgenlos zu verpuffen. Das war der eigentliche Defekt hinter den vierzehn Klicks: nicht die Ablehnung, sondern ihre Stummheit.
- **Entwurfsabsicht des Nutzers, 2026-08-06**: Die Reihe soll in erster Linie *informieren*, nicht sperren. Gewuenscht ist, dass die Segmente jedes Schirms lesbar hell sind, so dass auf einen Blick ablesbar ist, wie viele Spaces es gibt, welcher aktiv ist und welche sich mit einem Klick aktivieren lassen. Zusaetzlich sollen auch die Segmente eines *anderen* Schirms anklickbar sein und dessen Space wechseln, ohne die Maus dorthin bewegen zu muessen. Das hebt die heutige Bedeutung der Abblendung auf: sie steht derzeit fuer *nicht erreichbar* und waere dann hoechstens noch ein dezenter Hinweis auf die Zugehoerigkeit. Voraussetzung ist die Fernumschaltung aus S-10, die unverifiziert ist — scheitert der Cursor-Warp am Geraet, faellt der zweite Teil des Wunsches weg und die Abblendung behaelt ihre Berechtigung.
- Der Wunsch aus der Bedienung: die Segmente sollen dem folgen, wo die Maus gerade steht. Das ist heute nie der Fall, weil die Reihe nur bei einem Space-Wechsel neu gebaut wird. Billigster Weg waere ein Tracking-Bereich auf dem Statusitem, der beim Eintritt der Maus neu bewertet — genau der Moment, in dem die Abblendung ueberhaupt zaehlt.
- Die Abblendung selbst ist als Anzeige fuer Schritt 8 der Checkliste gewollt (eine Gruppe eines anderen Displays ist bei getrennten Spaces nicht per synthetischer Geste erreichbar). Falsch ist nicht die Regel, sondern ihr Aktualisierungszeitpunkt. Zu entscheiden ist zusaetzlich, ob der Cursor das richtige Kriterium ist: aus Nutzersicht war der Fokus gemeint, und beides faellt nur zusammen, solange die Maus dem Fokus folgt.
- Kandidat zur Behebung: `MissionControl.setState()` verfolgt ueber `DockEvents` bereits Eintritt und Verlassen von Mission Control, und dort werden Spaces praktisch immer angelegt oder geloescht. Ein Auffrischen beim Uebergang nach `inactive` waere der billigste Weg und braucht keine neue Beobachtung. Zu pruefen ist, ob das auch Anlegen ueber andere Wege abdeckt und ob die Spaces-Konfiguration zu diesem Zeitpunkt bereits geschrieben ist.
- S-07 ist noch nicht bestanden: Display-Gruppierung und Ueberlauf sind implementiert, aber Separate-Spaces-Modi, Create/Delete/Reorder, VoiceOver und die reale Klickgeometrie in der System-Menueleiste bleiben manuell am Zielgeraet zu pruefen.

Mehrere Displays:

- Standard ist `macOS folgen`, kein eigener globaler Umschaltmodus.
- Bei aktivem `Displays haben separate Spaces` werden Spaces nach Display gruppiert. Ein Klick wechselt nur das Display der angeklickten Gruppe.
- **Zurueckgezogen 2026-08-05**: Der Befund „bei deaktivierten separaten Spaces liefert macOS trotzdem eine Gruppe je Display" beruhte auf einer Fehlmessung. `NSScreen.screensHaveSeparateSpaces` liefert in einem Hilfsprozess ohne App-Bundle einen Vorgabewert statt der echten Einstellung und meldete `false`, waehrend `com.apple.spaces spans-displays` = 0 und die App selbst `true` sagen. Die separaten Spaces waren also die ganze Zeit **eingeschaltet**, und dass neu angeschlossene Displays mit genau einem Space starten, ist dabei normales Verhalten.
- Methodisch: Systemzustand, der das Verhalten der App bestimmt, wird ab jetzt in der App gemessen oder ueber die zugrundeliegende Preference gelesen, nicht ueber AppKit in einem unverpackten Skript.
- Wie sich die Gruppierung bei tatsaechlich **deaktivierten** separaten Spaces verhaelt, ist damit unbelegt.
- Umgesetzt, aber **unbelegt** 2026-08-05: Solange `Displays haben separate Spaces` deaktiviert ist, werden Gruppen mit genau einem Space nicht gezeigt. Die Regel ist nie in diesem Zustand beobachtet worden, weil die Messung, die sie ausgeloest hat, die Einstellung falsch gelesen hatte. Sie ist wirkungslos, solange separate Spaces aktiv sind; vor einer Auslieferung ist sie mit tatsaechlich deaktivierter Einstellung zu pruefen. Sie bieten keine Wahl an, weil der Wechsel ohnehin den ganzen Verbund betrifft. Bleibt genau eine Gruppe uebrig, entfaellt auch der Trenner. Bei aktivierter Einstellung bleibt jede Gruppe sichtbar, auch mit nur einem Space: dort ist die Nummer eine echte Zustandsanzeige, weil das Display unabhaengig wechselt.
- Da macOS dieselbe Statusleiste auf mehreren Displays spiegeln kann, zeigt der MVP in einem Status-Item kompakte Display-Gruppen statt pro Menueleistenkopie unterschiedlichen Inhalt zu versprechen. Die Darstellung pro physischem Display ist ein separater Machbarkeitscheck.

Optionale Namen:

- Space-Aliase sind AltTab+-Metadaten; macOS selbst erhaelt dadurch keine benannten Spaces.
- Aliase werden nur persistiert, wenn eine auf Tahoe verifizierte stabile Managed-Space-UUID verfuegbar ist. Der Nachweis liegt seit 2026-08-03 vor (S-08).
- Ein Space ohne UUID ist moeglich: am 2026-07-31 trug der damalige Login-Space (`id64` 1) keine, und ein Reorder belegte, dass die Luecke an diesem einen Space hing und nicht an der Position 1. Nach dem Neustart war er verschwunden und alle Spaces trugen wieder eine UUID. Die Umsetzung muss den Fall trotzdem tragen: kein Alias fuer diesen Space, sichtbar als ungeklaert markiert, und niemals ein stiller Rueckfall auf `id64` oder die Nummer.
- Reine numerische Indizes oder sitzungsgebundene CGS-Space-IDs duerfen nach Reorder, Neustart, Hinzufuegen oder Loeschen nicht still einem alten Namen zugeordnet werden. Bei unsicherer Identitaet auf Nummern degradieren und die Zuordnung sichtbar als ungeklaert markieren.

Repo-Learnings:

- `xiamaz/YabaiIndicator` zeigt klickbare Space-Segmente, aktiven Zustand, Fullscreen-Spaces, kompakten Modus und mehrere Displays in der Menueleiste.
- YabaiIndicator nutzt yabai als Zustands- und Switching-Backend, externe yabai-Signale zur Synchronisierung und verlangt laut README fuer korrektes Klicken deaktiviertes SIP. AltTab+ uebernimmt nur das Darstellungs- und Event-Refresh-Muster, nicht die yabai-Abhaengigkeit, Socket-Steuerung oder SIP-Anforderung.
- Das bereits gelesene InstantSpaceSwitcher-Menue setzt aktive Eintraege, deaktiviert Randaktionen und aktualisiert vor Menueoeffnung. Diese Zustandslogik kann in das gemeinsame Aktionsregister ueberfuehrt werden; die sichtbare Segmentleiste bleibt AltTab+-eigene AppKit-UI.

Nicht im MVP:

- Space-Erstellung, Loeschung oder Reordering aus der Menueleiste.
- Fensterminiaturen in den Space-Segmenten.
- Erzwingen eines synchronen Wechsels aller Displays, wenn macOS separate Spaces verwendet.
- Projektprofile, App-Zuordnungen und Session-Restore; diese bauen spaeter auf Alias- und Space-Identitaet auf.

### 2E. Shortcut Clues

Status: Umgesetzt; manuelle Abnahme offen
Prioritaet: Mittel, sinnvoll erst nach Phase 3A

Umsetzungsstand 2026-08-05:

- Trigger ueber die bestehende Shortcut-Infrastruktur, ohne Default und konfliktgeprueft wie jeder andere globale Aktions-Shortcut. Der Doppeltipp aus dem Vorbild bleibt bewusst draussen, weil er einen dauerhaften Tap verlangt.
- Das Loslassen wird ueber den vorhandenen `flagsChanged`-Pfad erkannt. Kein zweiter Tap, nichts wird absorbiert: wer ein angezeigtes Kuerzel drueckt, loest es in der Ziel-App aus.
- Der Menuedurchlauf laeuft auf der AX-Queue, nie im Callback, mit Ergebnis-Cache je Prozess und kurzer Gueltigkeit.
- Das Panel nimmt keinen Fokus, ignoriert Mausereignisse, erscheint nicht im Fensterwechsel und wird bei jedem Sitzungsende freigegeben. Not-Aus und Safe Mode raeumen es ebenfalls ab.
- Fehlende Berechtigung und ein leeres Ergebnis erzeugen eine erklaerende Meldung statt eines leeren Panels; ein abgeschnittener Durchlauf sagt es.
- Nicht geprueft: die manuelle Abnahme am Zielgeraet, insbesondere Browser mit grossen Lesezeichenmenues und der App-Wechsel bei gehaltenem Trigger. Checkliste: `docs/shortcut-clues-checklist.md`.

Blendet die Tastenkuerzel der aktiven App als Overlay ein, solange ein Trigger gehalten wird. Erster
Modulumfang, der fremde Shortcuts liest statt eigene auszufuehren, und deshalb ohne Anbindung an das
Aktionsregister. Vollstaendige Spezifikation in `spec-shortcut-clues.md`.

### 2D. Projektprofile und Workspace-Restore

Status: Spaeterer Folgeumfang
Prioritaet: Mittel

Produktmodell:

- Ein Space-Alias benennt nur einen macOS-Space. Ein Projektprofil ist ein stabiles AltTab+-Objekt mit Name, Apps, optionalem Layout, optionalem Space-Binding und optionalem Shortcut.
- Profile wie `Coding`, `Research` oder `Meeting` koennen in der Menueleiste anstelle einer reinen Nummer erscheinen, ersetzen aber nicht den darunterliegenden macOS-Space.
- Profile bleiben auch dann erhalten, wenn ein Space geloescht oder seine sitzungsinterne ID geaendert wird. Eine verlorene Bindung wird sichtbar und nie automatisch auf einen zufaelligen Space umgebogen.

Erste Ausbaustufe:

- Profile anlegen, benennen und optional mit einem stabil identifizierten Space verknuepfen.
- Apps ueber Bundle-ID einem Profil zuordnen.
- Optionales Layout-Preset und eigener konfliktgepruefter Shortcut pro Profil.
- Profilaktivierung wechselt zuerst den gebundenen Space und bietet danach dessen Apps im AltTab+-Switcher priorisiert beziehungsweise gefiltert an.
- Apps werden nicht ungefragt beendet, versteckt, gestartet oder in andere Spaces verschoben. Solche Wirkungen brauchen getrennte Opt-in-Aktionen.

Zweite Ausbaustufe:

- Explizite Aktionen `Profil-Apps starten`, `Fenster dem Profil-Space zuordnen`, `Session speichern` und `Session wiederherstellen`.
- Session-Snapshot umfasst mindestens Bundle-ID, belastbare Fenstermerkmale, Rahmen, Minimized-Zustand, Z-Reihenfolge, Display-UUID, Space-Zuordnung und Display-Topologie.
- Restore arbeitet best-effort, zeigt nicht zuordenbare Fenster und ueberschreibt keine unsicheren Matches. Geaenderte Display-Topologien verwenden dokumentiertes Clamping beziehungsweise Layout-Fallbacks.
- Automatisches Speichern beim Profilwechsel und automatisches Wiederherstellen bleiben aus, bis manuelle Capture-/Restore-Pruefungen ueber die App- und Display-Matrizen stabil sind.

HopTab-Learnings:

- `royalbhati/HopTab` modelliert Profile mit Name, gepinnten Apps, Hotkey und Layout-Binding, ordnet Profile einem aktiven CGS-Space zu und reagiert auf `activeSpaceDidChange`.
- HopTab speichert pro Profil Fensterrahmen, Minimized-Zustand und Z-Reihenfolge und restauriert nach Profilwechsel beziehungsweise App-Start zeitversetzt.
- Fuer AltTab+ sind Produktmodell und Ablauf gute Vorbilder. Die konkrete Implementierung wird nicht direkt uebernommen: HopTabs Space-ID ist laut Quelltext sitzungslokal, und das Fenster-Matching per Bundle-ID, Titel und Reihenfolge ist fuer ein dauerhaftes Restore zu schwach.
- Profile sind keine allgemeine Automationsplattform. Kalender-, Zeitplan-, Focus-Mode- oder frei skriptbare Regeln bleiben ausserhalb dieses Umfangs.

### 2F. Verknuepfte Spaces ueber alle Displays

Status: Spike erforderlich; Messpunkt offen
Prioritaet: Mittel

Produktmodell (a-Modell):

- Gleiche Space-Anzahl auf jedem Bildschirm. Anlegen und Loeschen wirkt auf allen Displays; neu angeschlossene Displays erhalten die Anzahl des Verbunds.
- Ein Wechsel auf Space n wechselt alle Bildschirme gemeinsam auf ihren Space n.
- Das b-Modell (unabhaengige Spaces je Display) ist das native Verhalten bei aktiviertem `Displays haben separate Spaces` und braucht keine eigene Umsetzung.

Messpunkt vor jeder Umsetzung:

- Am Desk mit deaktiviertem `Displays haben separate Spaces` einen Space wechseln und beobachten, ob die externen Bildschirme mitwechseln. Wechseln sie mit, liegt das a-Modell nahe am nativen Verhalten und der Umfang schrumpft auf die Anzahl-Synchronisation. Bleiben sie stehen, ist das a-Modell eine vollstaendige Emulation ueber aktivierte separate Spaces.

Technische Huerden im Emulationsfall:

- Synchrones Wechseln: die synthetischen Dock-Swipes koennen kein Zieldisplay adressieren (dokumentiert in 2C). Als einziger Weg ohne das verworfene `CGSManagedDisplaySetCurrentSpace` galt: Cursor per `CGWarpMouseCursorPosition` auf das Zieldisplay setzen, dort swipen, Cursor zurueckgeben.
- **S-10 am Zielgeraet gemessen und gescheitert, 2026-08-06.** Der Weg funktioniert nicht, und der Grund ist ein anderer als vermutet. Drei Varianten wurden geprueft, jeweils mit zwei gestapelten Displays und eingeschalteten getrennten Spaces:
  - `event.location` auf die Mitte des Zieldisplays setzen: **wirkungslos**. Es wechselte weiterhin der Schirm unter dem Cursor. Ein Kontrolllauf ohne gesetzte Position verhielt sich identisch. Die bisher unbewiesene Annahme, dass die Geste kein Zieldisplay tragen kann, ist damit belegt.
  - Cursor-Warp mit Verzoegerungen von 0, 20, 50, 100 und 200 ms: **kein Display wechselte**, weder das Ziel noch das ursprueng­liche. Es ist also kein Timing-Problem.
  - Abschalten der Ereignisunterdrueckung ueber `localEventsSuppressionInterval = 0` und `CGAssociateMouseAndMouseCursorPosition(1)`: **unveraendert wirkungslos**. Unterdrueckung scheidet als Ursache aus.
- Die Ursache zeigte erst eine gezielte Messung: nach dem Warp meldete `CGSCopyActiveMenuBarDisplayIdentifier` weiterhin den **Ursprungsschirm**, waehrend `NSScreen.withMouse()` bereits das Ziel meldete. Der Dock richtet den Swipe also nach dem **aktiven Menueleisten-Display**, nicht nach der Cursorposition. Ein Cursor-Warp bewegt den Cursor, aber nicht diese Groesse — und die Geste verpufft dann folgenlos.
- Konsequenz: Fernumschaltung eines Displays waere nur erreichbar, indem man es zum *aktiven* Display macht, also dort ein Fenster aktiviert. Das ist genau die Stoerung, die der Wunsch vermeiden wollte, und damit kein gangbarer Weg. S-10 ist abgeschlossen, nicht offen.
- Anzahl-Synchronisation: Spaces programmatisch anlegen und loeschen erfordert `CGSSpaceCreate`/`CGSSpaceDestroy`, die erste schreibende private Space-API des Forks. Nur als eigener Spike (S-11), optional gebunden und fail-closed; der `CGSManagedDisplaySetCurrentSpace`-Befund mit dem entkoppelten Dock ist die Referenz dafuer, wie so ein Symbol scheitern kann.
- Resynchronisation nach Sleep/Wake, Display-Hotplug und manuellen Aenderungen in Mission Control; bei Abweichung sichtbar degradieren statt still anzugleichen.

### 2G. Fenster per Drag auf die Menueleiste verschieben

Status: Geplant; Stufe 1 baut auf vorhandenen Teilen auf
Prioritaet: Mittel

Beschreibung:

- Ein Fenster wird waehrend einer AltTab+-Modifier-Drag-Sitzung auf der Menueleiste fallen gelassen, um es auf einen anderen Bildschirm zu verschieben.
- **Am Zielgeraet bestaetigt 2026-08-05**: Der Drop auf die AltTab+-Icons verschiebt das Fenster auf den anderen Bildschirm. Ein Loslassen in der Menueleiste neben den Icons trifft die Fill-Zone und maximiert; das ist korrekt, solange ueber diesem Bildschirm kein weiterer liegt.
- Dazu noetig war eine Halteschaltung: der 30pt hohe Streifen grenzt direkt an das Display darueber, und der Cursor rutschte auf dem Weg zum Loslassen wieder heraus. Die Erkennung selbst war von Anfang an korrekt, was erst die Instrumentierung zeigte.
- Umgesetzt 2026-08-05, Stufe 1: Drop auf das AltTab+-Statusitem verschiebt auf den naechsten Bildschirm in physischer Reihenfolge; `DisplayMoveGeometry` mit relativer Lage und Clamping wird wiederverwendet. Der Drop erzeugt keinen eigenen Anwendungspfad, sondern nur einen weiteren Weg, `snapFrame` zu berechnen, und laeuft danach durch dieselbe Ausfuehrung wie das Snapping. Das Overlay zeigt den Zielbildschirm, solange der Cursor ueber dem Statusitem steht.
- Das Quelldisplay ist dasjenige, das das Fenster flaechenmaessig am meisten ueberdeckt, nicht das mit dem Fensterursprung: ein Fenster ueber der Displaygrenze wuerde sonst von dem Bildschirm weggeschoben, auf dem es ueberwiegend liegt.
- Nicht geprueft: manuelle Abnahme am Zielgeraet mit mehreren Bildschirmen.
- Stufe 2: Drop auf ein bestimmtes Display-Segment waehlt den Zielbildschirm.
- Mechanik wie beim Snapping: die Drag-Sitzung prueft beim Mouseup, ob der Cursor ueber dem Statusitem liegt; ein Drop-Ziel gewinnt gegen Snap-Ziel und freie Position.

Nicht in Stufe 1 und 2:

- Natives Titelbalken-Ziehen auf die Menueleiste. Fenster-Drags erzeugen keine Pasteboard-Drags; eine Status-Item-View bekommt davon nichts mit.

Folgeumfang natives Ziehen, Kandidatenpfade:

- Beobachtender listen-only Maus-Tap: beim Mousedown die Fensteraufloesung asynchron auf der AX-Queue anstossen; landet das Mouseup auf dem Statusitem und ist das aufgeloeste Fenster dem Cursor gefolgt, gilt es als Drop. Kein Konsumieren, aber ein dauerhafter Tap, solange das Feature aktiv ist; Q-04, Q-10 und Q-12 gelten.
- Alternativ Korrelation ueber die bereits abonnierten `AXWindowMoved`-Ereignisse: ein Fenster, dessen Position waehrend des Drags dem Cursor folgt, ist das gezogene. Ereignisbasiert, aber Zustellverzoegerung der AX-Notifications einplanen.
- In beiden Faellen Fehltreffer ausschliessen (Text- und Datei-Drags, die ueber der Menueleiste enden), etwa ueber die Bedingung, dass ein Fenster dem Cursor gefolgt sein muss.

### 2H. Fenster per Drag auf eine Switcher-Kachel auf deren Space verschieben

Status: Spezifiziert, nicht gebaut
Prioritaet: Mittel

Beschreibung:

- Waehrend einer AltTab+-Modifier-Drag-Sitzung wird das gezogene Fenster auf einer Kachel des Switchers fallen gelassen. Es wandert auf den Space, auf dem das Fenster dieser Kachel liegt.
- Motivation: Der native Weg dafuer ist umstaendlich und in diesem Dokument bereits als solcher festgehalten (siehe Nichtziele der Spaces-Stories) — an den Bildschirmrand ziehen und halten erreicht nur den Nachbar-Space, fuer ein beliebiges Ziel muss Mission Control geoeffnet werden. Der Switcher zeigt die Spaces ohnehin schon an; die Kachel ist damit ein Ziel, das der Nutzer bereits sieht.
- Das Ziel ist der Space der Kachel, nicht die Kachel selbst. Das gezogene Fenster ersetzt nichts und stapelt sich nicht auf das Zielfenster.

Was die Architektur bereits entscheidet:

- **Der bestehende Drop-Pfad kann das nicht ausdruecken.** Menubar-Drop und Snapping enden beide in `snapFrame: CGRect`, und `finishOnQueue` kennt nur `applyFrame`. Ein Space-Wechsel ist kein Rahmen. Die Drag-Sitzung braucht daher erstmals ein Abschlussergebnis, das kein Rahmen ist — etwa ein `DragOutcome` mit den Faellen `frame(CGRect)` und `space(CGSSpaceID)`. Das ist der eigentliche Umbau; die Trefferpruefung ist der kleinere Teil.
- Die Kachel-zu-Fenster-Zuordnung liegt vor (`TileView.window_`), ebenso die Space-Zugehoerigkeit (`Window.spaceIds`, `Window.spaceIndexes`). Eine Kachel mit `isOnAllSpaces` ist kein sinnvolles Ziel und wird nicht angeboten.
- Der Drag-Pfad prueft `App.appIsBeingUsed` nicht, anders als die Layout-Aktionen im Aktionsregister. Eine Drag-Sitzung kann also laufen, waehrend der Switcher offen ist; das Feature ist erreichbar, ohne diese Sperre zu lockern.
- Vorrang wie beim Menubar-Drop: ein getroffenes Kachel-Ziel gewinnt gegen Snap-Ziel und freie Position. Zwischen Kachel-Ziel und Menubar-Drop kann nicht beides zugleich getroffen sein.

Offene Entscheidung, vor dem Bauen zu treffen:

- **Wie der Switcher waehrend eines Drags erscheint.** Ohne eine Antwort darauf ist das Feature nicht bedienbar, denn der Switcher oeffnet heute ueber ein gehaltenes Tastenkuerzel, waehrend Maustaste und Drag-Modifier bereits gehalten werden. Kandidatenpfade:
  - Der Nutzer drueckt das Switcher-Kuerzel mitten im Drag. Kein neuer Mechanismus, aber eine Handhaltung aus Drag-Modifier, Maustaste und Kuerzel gleichzeitig; am Geraet auf Bedienbarkeit zu pruefen, bevor darauf gebaut wird.
  - Der Switcher oeffnet selbsttaetig, sobald eine Drag-Sitzung laeuft, hinter einer eigenen Einstellung und per Default aus. Bequem, aber er verdeckt waehrend jedes Drags den Bildschirm.
  - Ein eigener Modifier waehrend des Drags blendet ihn ein. Erfordert eine dritte Modifier-Zuweisung neben Move und Resize, mit derselben Konfliktpruefung.
- Ob das gezogene Fenster dem Space folgt (Wechsel dorthin) oder nur verschoben wird und der Nutzer bleibt. Beides ist vertretbar; die Entscheidung gehoert vor die Umsetzung, weil sie den Ausfuehrungspfad und das Overlay bestimmt.

Risiko, das die Umsetzung bestimmt:

- `CGSAddWindowsToSpaces` ist in `SkyLight.framework.swift` deklariert, hat aber **keinen Aufrufer**. Der Pfad ist damit unbelegt — dasselbe Muster wie beim Pointer-Schreibpfad (V-10) und bei den drei Faellen im Handover, in denen Code eine Faehigkeit behauptete, die er nie lieferte. Vor jeder UI-Arbeit ist zu belegen, dass der Aufruf ein Fenster tatsaechlich auf einen anderen Space verschiebt, und zwar auf dem Tahoe-Zielgeraet.
- Zu klaeren ist dabei mindestens: Verhalten bei Fullscreen-Spaces, bei Fenstern auf allen Spaces, bei einem Fenster auf einem anderen Display, und ob der Aufruf ohne zusaetzliche Berechtigung durchgeht.
- Faellt dieser Beleg negativ aus, ist die Story hinfaellig oder braucht einen anderen Systempfad; das ist vor der Trefferpruefung und dem Overlay zu entscheiden, nicht danach.

Nicht in dieser Story:

- Natives Titelbalken-Ziehen auf eine Kachel. Gleiche Begruendung wie bei 2G: Fenster-Drags erzeugen keine Pasteboard-Drags.
- Umsortieren von Spaces oder Erzeugen eines neuen Space durch Drop auf eine leere Flaeche.

Verifikation:

- Erst der Systempfad-Beleg (siehe Risiko), dann eine manuelle Abnahme am Zielgeraet mit mehreren Displays und mehreren Spaces. Unit-Tests decken die Trefferpruefung und die Zielauswahl ab, nicht den Systempfad — die Erfahrung in diesem Projekt ist, dass genau dort die Fehler sitzen.

### 3. Modifier-basierter Window Move/Resize

Status: Move und Resize umgesetzt, manuelle Abnahme von Resize offen
Prioritaet: Hoch

Beschreibung:

- Fenster unter dem Cursor bewegen oder resizen, ohne den Fensterrahmen exakt treffen zu muessen.
- Ziel ist ein BTT-aehnliches Move/Resize-Verhalten.
- Move und Snapping bilden eine gemeinsame Drag-Sitzung: freies Bewegen und Randziel-Erkennung laufen auf demselben festgehaltenen Fenster und enden in genau einer Abschlussaktion.
- Kein Default-Modifier; Modul startet aus.
- Keine direkte Uebernahme von `Moves/WindowHandler.swift`; AltTab+ verwendet den eigenen AX-, Queue-, Timeout- und Diagnosepfad.

Drag-Sitzung:

1. Zustand `idle -> armed -> resolving -> dragging -> finishing/cancelled`.
2. Fenster an der ersten relevanten Mausposition einmal bestimmen und fuer die ganze Sitzung festhalten.
3. Ursprungsrahmen und Mausposition einmal speichern; Ziel aus kumulativem Delta berechnen.
4. Event-Callback publiziert nur den neuesten Zielrahmen.
5. Serielle AX-Queue schreibt mit Coalescing bei 30 bis 60 Hz und laesst hoechstens einen Set-Aufruf gleichzeitig laufen.
6. Waehrend eines Move-Drags Randziele aus derselben Maus- und Display-Geometrie bestimmen und das gemeinsame Snapping-Overlay aktualisieren.
7. Mouseup ohne aktives Randziel behaelt die frei verschobene Position; Mouseup mit aktivem Randziel setzt genau dessen Zielrahmen.
8. Move samt Modifier-Drag-Snapping zuerst ausliefern; Resize und weitere Fenster-Fallbacks erst nach bestandener Move-Matrix.

Umsetzungsstand 2026-07-31:

- Umgesetzt als reine Logik mit 16 Tests: Zustandsautomat der Drag-Sitzung, Randmodell samt Dwell fuer geteilte Raender, Zielrahmen fuer `Left half`, `Right half` und `Fill` sowie die Modifier-Auswahl ohne Default.
- Festgelegt und getestet: Loslassen des Modifiers waehrend des Drags beendet ihn nicht. Die Maustaste haelt die Sitzung; ein Fenster fallen zu lassen, sobald ein Finger hochgeht, waere unbedienbar.
- Festgelegt und getestet: nur der Zustand `finishing` darf einen Rahmen schreiben. Eine abgebrochene Sitzung schreibt nie.
- Umgesetzt: dauerhafter Maus-Event-Tap mit Arming-Marker, Circuit Breaker und Anbindung an den Not-Aus; Settings-Auswahl ohne Default; Snapping auf `Left half`, `Right half` und `Fill` innerhalb der eigenen Drag-Sitzung.
- Korrigiert vor der ersten Nutzung: Das Randmodell rechnete in AppKit-Koordinaten, waehrend `CGEvent.location` und die AX-Rahmen Quartz-Koordinaten mit y nach unten liefern. Oberer und unterer Rand waren dadurch vertauscht, `Fill` haette am Dock-Rand ausgeloest.
- Nachgezogen 2026-08-03: Der Q-07-Ringpuffer erscheint im Debug-Profil unter `Window drag AX deviations`, beschraenkt auf die letzten 20 Schreibvorgaenge, die eine App nicht wie vorgeschlagen uebernommen hat. Er wurde zuvor nur befuellt und nie gelesen.
- Nachgezogen 2026-08-03: Der `AXManualAccessibility`-Cache wird bei App-Beendigung geleert. PIDs werden wiederverwendet, ein veralteter Eintrag haette eine frisch gestartete Electron-App als bereits umgestellt gelten lassen.
- Umgesetzt: Overlay fuer den Zielrahmen als nicht aktivierendes `NSPanel` mit `NSVisualEffectView`, das Mausereignisse ignoriert, nicht im Fensterwechsel erscheint und bei jedem Sitzungsende freigegeben wird. Reduce Transparency ersetzt die Vibrancy durch eine deckende Flaeche, Increase Contrast verstaerkt den Rahmen.
- Umgesetzt: `Command+Control` steht in der Auswahl und setzt Besitz ueber `NSWindowShouldDragOnGesture` voraus. Der Schalter wird ueber `CFPreferences` in `NSGlobalDomain` gelesen und geschrieben; laesst er sich nicht auf `false` setzen und zurueckverifizieren, wird der Modifier abgelehnt statt halb zu funktionieren, mit sichtbarem Hinweis. Jeder andere Modifier gibt den Schalter zurueck.
- Das Besitzmodell ist dasselbe wie beim Pointer: es wurde als `SystemValueOwnership` generisch herausgezogen, weil zwei Kopien eines sicherheitskritischen Zustandsautomaten auseinanderdriften und der Schaden einer gedrifteten Kopie das Zerstoeren einer fremden Systemeinstellung ist. Die 19 Pointer-Tests liefen unveraendert durch die Refaktorierung und bewachen sie.
- Bewusste Ausnahme: Das eigene Settings-Fenster laesst sich mit dem Modifier nicht bewegen. Eine synchrone AX-Abfrage in den eigenen Prozess muss der Thread beantworten, der bereits auf die Antwort wartet, und haengt die App; der Cursor-Pfad lehnt das eigene Fenster deshalb ab, so wie der Switcher-Pfad die eigene App seit jeher ausschliesst. Ein zweiter, AX-freier Pfad ueber `NSWindow.setFrame` waere moeglich, wuerde aber Drag-Sitzung, Coalescing, Snapping und Overlay doppeln, und das lohnt fuer ein einzelnes Fenster nicht. Wird `Command+Control` von macOS selbst behandelt (`NSWindowShouldDragOnGesture` aktiv), verschiebt das System dieses Fenster weiterhin.

V-13-Stand 2026-08-03, am Zielgeraet geprueft:

- Bestanden: Aktivierung setzt den Schalter auf `false` und verifiziert ihn; sauberer Wechsel auf einen anderen Modifier gibt den Vorwert zurueck.
- Bestanden: externe Aenderung des Schalters waehrend `managed` fuehrt beim naechsten Start zu `relinquished` ohne Rueckschreiben.
- Gefunden und behoben: Nach einer erfolgreichen Kill-Recovery hat der Startvorgang den Wert sofort wieder uebernommen, weil der Modifier noch gesetzt war. Der Restore wurde dadurch in derselben Sitzung rueckgaengig gemacht. Das Modul startet nach einer Recovery jetzt deaktiviert und meldet die Wiederherstellung, wie es das Besitzmodell verlangt.
- Offen: Wake und erneute Aktivierung aus `relinquished` heraus.

Vorherige Groesse merken (offen):

- Befund aus der Bedienung 2026-08-05: Wird ein Fenster ueber die Fill-Zone auf Bildschirmgroesse gebracht, behaelt es diese Groesse, wenn es danach wieder weggezogen wird. macOS stellt bei seinem eigenen Tiling die vorherige Groesse wieder her; der AltTab+-Drag kennt bisher kein Gedaechtnis dafuer.
- Vorgesehen: Der Rahmen vor dem ersten Snap einer Drag-Sitzung wird gesichert. Wird das Fenster in einer spaeteren Sitzung aus einem Snap-Zustand heraus gezogen, ohne dass ein neues Snap-Ziel aktiv wird, erhaelt es diesen Rahmen zurueck, waehrend die Position dem Cursor folgt.
- Abzugrenzen vom Ein-Schritt-Restore der Window Layouts: dort ist Restore eine eigene Aktion mit eigenem Shortcut. Hier geschieht es implizit beim Wegziehen, und die beiden Gedaechtnisse duerfen sich nicht gegenseitig ueberschreiben.
- Offene Fragen: Wie lange gilt der gesicherte Rahmen — nur bis zum naechsten Snap, ueber die Sitzung hinaus, oder bis das Fenster von aussen veraendert wird? Und was geschieht, wenn eine App die Groesse waehrend des Snaps selbst aendert; dann ist der gesicherte Rahmen nicht mehr das, was der Nutzer erwartet.
- Nicht im ersten Umfang: ein mehrstufiger Verlauf. Ein Schritt zurueck reicht, wie beim Layout-Restore auch.

Resize, umgesetzt 2026-08-03:

- Eigener Modifier, per Default aus, getrennt von Move konfigurierbar. Beide Module teilen sich Tap, Drag-Sitzung, Cursor-Aufloesung, AX-Queue, Coalescing und alle Sicherungen; nur die Zielgeometrie unterscheidet sich.
- Der Quadrant, in dem der Drag beginnt, bestimmt die Ecke, die dem Cursor folgt. Die gegenueberliegende Ecke bleibt fest, sonst wandert das Fenster beim Groessenaendern. Der Anker wird einmal je Sitzung bestimmt, damit ein Ueberqueren der Fenstermitte die wachsende Kante nicht mittendrin umschaltet.
- Mindestgroesse 120x80; das Klemmen schiebt die Kante unter dem Cursor zurueck, nie die verankerte.
- Snapping bleibt Move vorbehalten: ein Resize zielt auf eine Groesse, nicht auf einen Bildschirmrand.
- Dieselbe Kombination kann nicht beide Module treiben; die Settings weisen das mit Hinweis ab.
- Nicht geprueft: die manuelle Abnahme am Zielgeraet und die App-Klassen-Matrix, insbesondere Apps mit eigenen Mindestgroessen oder Zeichenraster-Clamping. Checkliste dafuer: `docs/window-drag-checklist.md`.
- Befund zur Verifikation, 2026-08-01: Innerhalb dieser Story traten drei Koordinatenfehler auf, die alle Unit-Tests passierten. Erstens rechnete das Randmodell in AppKit- statt Quartz-Koordinaten, wodurch oberer und unterer Rand vertauscht waren. Zweitens war der Flip im Overlay zu pruefen. Drittens wurde das Display ueber seinen sichtbaren statt seinen vollen Rahmen gesucht, wodurch der Cursor im Menueleistenstreifen kein Display mehr traf und genau die Fill-Zone tot blieb. Alle drei fand die manuelle Pruefung am Geraet, keiner davon ein Test: die reine Logik war jeweils in sich stimmig, nur ihre Annahme ueber die Aussenwelt war falsch. Fuer Move und Resize ist Unit-Testabdeckung deshalb keine ausreichende Qualitaetsaussage; die App-Klassen- und Display-Matrizen bleiben das entscheidende Gate.

Modifier-Regeln:

| Kombination | Bewertung |
|---|---|
| `ctrl` allein und alle Control-Kombinationen ausser dem expliziten `cmd+ctrl`-Pfad | Ausgeschlossen. Control-click ist systemweit Secondary Click |
| `option` | Belegt. Apple nutzt Option beim Drag fuer schnelleres Tiling; Finder nutzt Option fuer Copy-Drag |
| `cmd` allein | Belegt. macOS zieht damit bereits Hintergrundfenster ohne Fokuswechsel |
| `fn` / Globe | Kandidat, aber nicht als Default; Nicht-Apple-Tastaturen melden es teils nicht als `maskSecondaryFn`, und Apple belegt `Fn-Control-*` |
| `cmd+shift` | Konfliktarmer Kandidat im Picker |
| `cmd+ctrl` | Explizit waehlbarer, konfliktbehafteter Kandidat. Nur bei bewusster Auswahl und nie als Default |

`Command+Control` und globale macOS-Einstellung:

- Bei bewusst gewaehltem `Command+Control` konsumiert AltTab+ den primaeren Mousedown und die zugehoerige Drag-/Mouseup-Sequenz. Dieser Pfad wird nicht zugleich als Control-click an die Ziel-App durchgereicht.
- Vor Aktivierung liest AltTab+ `NSGlobalDomain` / `NSWindowShouldDragOnGesture` und stellt sicher, dass der Wert `false` ist; dies entspricht `defaults write -g NSWindowShouldDragOnGesture -bool false`.
- Die Umsetzung verwendet die strukturierte Preferences-API und startet keinen Shell-Prozess.
- Ursprungswert, letzter von AltTab+ geschriebener Wert und Besitzstatus werden persistiert. Beim Deaktivieren oder bei Recovery wird der Ursprungswert nur restauriert, wenn der aktuelle Wert weiterhin dem letzten AltTab+-Wert entspricht; eine zwischenzeitliche externe Aenderung wird nicht ueberschrieben.
- Kann `false` nicht gesetzt oder verifiziert werden, bleibt `Command+Control` deaktiviert und die App meldet den Konflikt sichtbar.

Repo-Learnings:

- `jmgao/metamove` ist eine thematisch nahe Referenz fuer XFree86-style Modifier-Drag.
- `jmgao/metamove` nutzt laut README `Cmd-Shift-Click` fuer Move und `Option-Shift-Click` fuer Resize.
- `Option-Shift` ist unter Tahoe wegen Apples Option-Drag-Tiling nicht mehr als Default geeignet; `Cmd-Shift` bleibt ein valider Kandidat im Picker.
- Bei Nutzung von metamove als Referenz Originalquellen erneut lesen. Die detaillierte AX-Kette ist noch nicht vollstaendig aus einer eigenen Repo-Durchsicht belegt.

Entscheidung:

- Kein Default-Modifier ausliefern.
- Beim ersten Aktivieren: Modifier-Picker mit Live-Kollisionspruefung.
- `Command+Control` nur nach bewusster Auswahl und erfolgreicher Verifikation von `NSWindowShouldDragOnGesture == false` scharfschalten.
- Modul bleibt Opt-in.

Akzeptanzideen:

- Nutzer kann Move und Resize getrennt konfigurieren.
- Dragging fuehlt sich in AppKit-Apps fluessig an.
- Nicht-standard Fenster werden ignoriert, wenn sie nicht sicher resizable sind.
- Latenz wird pro App-Klasse bewertet, nicht pauschal.

### 4. Pointer Acceleration und Speed

Status: Umgesetzt, manuelle Verifikation V-10 offen
Prioritaet: Mittel bis hoch

Beschreibung:

- Pointer-Beschleunigung und Pointer-Geschwindigkeit fuer Maus und Trackpad auf Kategorie-Ebene anpassen.
- Kein Event-Tap, kein Event-Rewriting, kein laufender Input-Pfad.
- IOKit-hidsystem ist der vermutete oeffentliche Pfad; per Spike verifizieren.

MVP-Scope:

- Settings-Abschnitt `Pointer & Scroll`.
- Teilbereich `Pointer`.
- Kategorien `Mouse` und `Trackpad`.
- `Use system default`.
- `Pointer acceleration`: system default, disabled, custom.
- `Pointer speed`.

Anforderungen:

- Werte sind globaler Systemzustand, nicht app-lokal.
- Pointer-Werte verwenden ein explizites, persistiertes Besitzmodell mit den Zustaenden `unmanaged`, `managed` und `relinquished`.
- Beim bewussten Wechsel zu `managed` werden aktueller Originalwert, gewuenschter Wert und nach dem Schreiben zurueckgelesener kanonischer Wert persistiert.
- Vor jedem weiteren Schreiben muss der aktuelle Wert dem letzten von AltTab+ geschriebenen kanonischen Wert entsprechen.
- Weicht der aktuelle Wert ab, hat macOS, eine Systemeinstellung oder eine andere App wie LinearMouse, Logi Options oder Mac Mouse Fix geschrieben: in den persistierten Zustand `relinquished` wechseln, nicht zurueckschreiben und nicht dagegen anlaufen.
- `relinquished` bleibt ueber Neustarts erhalten. Das Setting zeigt neutral, dass der Wert ausserhalb von AltTab+ geaendert oder von einem anderen Tool uebernommen wurde; die Meldung unterstellt keine Nutzeraktion oder Schuld.
- Aus `relinquished` wird Besitz nur nach einer erneuten bewussten Aktivierung uebernommen. Dabei gilt der dann aktuelle Systemwert als neuer Originalwert.
- Beim Deaktivieren nur dann auf den Originalwert der aktuellen Besitzperiode restaurieren, wenn der aktuelle Wert noch dem letzten AltTab+-Wert entspricht.
- Bei sauberer App-Terminierung gilt dieselbe Restore-Regel; Restore-Fehlschlag oder zwischenzeitliche Aenderung fuehrt zu `relinquished`.
- Bleibt nach Crash oder `SIGKILL` ein persistierter Zustand `managed` zurueck, wird beim naechsten Start vor einem Re-Apply Recovery ausgefuehrt: aktueller Wert gleich letzter AltTab+-Wert fuehrt zum Restore des persistierten Originalwerts, jede Abweichung zu `relinquished` ohne Restore.
- Nach erfolgreicher Kill-Recovery startet das Teilmodul deaktiviert und meldet die Wiederherstellung. Eine erneute Besitzuebernahme erfolgt erst nach bewusster Aktivierung.
- Der Wert der allerersten Aktivierung gilt nicht lebenslang; jede neue bewusste Besitzperiode erfasst ihre eigene Baseline.
- Re-Apply nach Sleep/Wake, Login und Device-Reconnect folgt derselben Besitzpruefung und ist kein Freibrief zum Ueberschreiben.
- Werte nach jedem Schreiben zuruecklesen und vor Vergleichen kanonisieren, da das System Werte runden oder transformieren kann.
- Besitzdaten werden vor dem Systemwert geschrieben und nach dem kanonischen Read-back aktualisiert. Bei einem Abbruch zwischen Write und Read-back wird nur restauriert, wenn der aktuelle Wert sicher dem persistierten erwarteten Schreibwert zugeordnet werden kann; sonst fail-closed zu `relinquished`.
- Per-Device bleibt out of scope; Kategorie-Ebene ist der angestrebte oeffentliche Pfad, Per-Device wuerde private HID-Event-System-APIs erfordern.

Umsetzungsstand 2026-07-31:

- Befund zum Systempfad: nicht IOKit-hidsystem, sondern `NSGlobalDomain`. Die Werte stehen als `com.apple.mouse.scaling` und `com.apple.trackpad.scaling` und wurden auf macOS 26.5.1 (Build 25F80) lesend verifiziert (3 bzw. 0.6875). Geschrieben wird ueber `CFPreferences` gegen `kCFPreferencesAnyApplication`, also die strukturierte API ohne Shell-Prozess, ohne Event-Tap, ohne private API und ohne zusaetzliche TCC-Berechtigung.
- macOS kodiert beide Einstellungen in einem Wert: negativ schaltet die Beschleunigung ab, positiv ist die Geschwindigkeit. `System default` bedeutet deshalb, dass AltTab+ den Wert gar nicht besitzt, statt einen neutralen Wert zu schreiben.
- Geschwindigkeit wird als Rasterindex gespeichert, weil macOS selbst nur diskrete Stufen anbietet; der geschriebene Wert bleibt exakt.
- Der Besitz-Zustandsautomat ist vollstaendig als reine Entscheidungslogik umgesetzt und mit 19 Tests abgedeckt: Erwerb, Read-back, Abbruch zwischen Write und Read-back, Fremdaenderung, `relinquished` ueber Neustart, Wiedererwerb mit neuer Baseline, Disable, Crash-Recovery in beide Richtungen.
- Der Pfad, der das System tatsaechlich beschreibt, ist von keinem Test ausgefuehrt worden. V-10 ist damit die erste Ausfuehrung dieses Pfades; Checkliste in `docs/pointer-ownership-checklist.md`.
- Nachgezogen 2026-08-03: Das Re-Apply nach Wake ist an `SleepWakeEvents` angebunden. Es war zuvor geschrieben, aber nirgends aufgerufen, und sah damit nach einer erfuellten Anforderung aus, ohne eine zu sein.
- Nachgezogen 2026-08-03: Der Besitz-Text im Settings-Tab wird beim Oeffnen des Fensters aktualisiert. Zuvor wurde er einmal beim Aufbau ausgewertet und haette dauerhaft `Managed by AltTab+` behauptet, auch nachdem ein anderes Werkzeug den Wert uebernommen hat.

Exit-Kriterium:

- Getrennte Werte fuer Mouse und Trackpad sind setzbar und restaurierbar, ohne Event-Tap, ohne private API und ohne zusaetzliche TCC-Berechtigung.
- Aenderung ausserhalb von AltTab+ waehrend `managed` wird erkannt, als `relinquished` persistiert, nicht ueberschrieben und verhindert ein destruktives Restore.
- Crash und `SIGKILL` waehrend `managed` restaurieren beim naechsten Start nur unter Gleichheit mit dem letzten AltTab+-Schreibwert.
- Falls das nicht erreichbar ist: Teilmodul entfaellt; kein Event-Rewriting als Ersatz.

### 5. Window Snapping mit Drag-Overlay

Status: Revidiert nach macOS-native-Tiling
Prioritaet: Mittel, nach Tahoe-Feature-Matrix

Neue Leitlinie:

- Apple-Verhalten nicht nachbauen.
- Coexistence sicherstellen.
- Nur Luecken schliessen, die Apple auf Tahoe nicht liefert.
- Ausnahme: Waehrend einer AltTab+-eigenen Modifier-Drag-Sitzung stellt AltTab+ `Left half`, `Right half` und `Fill` selbst bereit, weil der AX-basierte Drag nicht Apples Titelbalken-Tiling ausloest.
- Die Ausnahme gilt ausschliesslich fuer den eigenen Modifier-Drag. Normales Ziehen am Titelbalken und Apples native Snap-Zonen werden weder abgefangen noch veraendert.

Im Scope:

- Coexistence-Pruefung: Sind native Tiling-Schalter aktiv?
- UX-Hinweis, dass Apples Schalter nur durch Nutzer in Desktop & Dock geaendert werden koennen.
- Luecken-Kandidaten: Thirds, Two-Thirds, Custom-Zonen, Center, Display-Moves.
- Modifier-Drag-Ziele `Left half`, `Right half` und `Fill`; `Fill` nutzt das sichtbare Desktop-Rechteck und ist kein macOS-Fullscreen-Space.
- Fenster-Identifikation ueber den AX-Fensteroperations-Kern.
- Edge-Modell in Points, nicht Pixeln.
- Halbtransparenter Zielrahmen als nicht aktivierendes `NSPanel`, ohne Fokuswechsel.
- Overlay ignoriert Mausereignisse und erscheint nicht im Window Cycle.
- Overlay wird bei Display-/Space-Wechsel, verlorenem Zielfenster, Drag-Abbruch und Mouseup sofort ausgeblendet.
- Bei Display-Wechsel waehrend des Drags wird das alte Ziel verworfen und gegen die neue Display-Geometrie neu bestimmt.
- Window Level liegt ueber dem Zielfenster, ohne Menubar, Dock oder Systemoberflaechen dauerhaft zu ueberdecken.
- `collectionBehavior` wird fuer aktive Spaces und das Verhalten an Fullscreen-Grenzen explizit getestet; ausgeschlossene Fullscreen-Fenster erhalten kein Overlay.
- Darstellung nutzt System-Akzentfarben und respektiert Reduce Transparency und Increase Contrast.
- Optik soll auf Tahoe systemnah und ruhig wirken; keine exakte Liquid-Glass-Imitation und keine Bindung an die historische AltTab-Optik.

Nicht im Scope:

- Left/right half, corner quarters und top-Fill ausserhalb einer AltTab+-eigenen Modifier-Drag-Sitzung, solange Tahoe sie nativ liefert.
- Ueberschreiben oder Unterdruecken von Apples Snap-Zonen.
- Bottom-Edge im MVP.
- Gespeicherte Layouts.
- Snap Groups.
- Animierte oder konfigurierbare Overlays im MVP.

Edge-Modell:

| Randtyp | Trigger |
|---|---|
| Freier Rand ohne Nachbardisplay | Cursor an Screen-Bounds geclampt, Toleranz 2 bis 4 pt, sofort |
| Geteilter Rand mit Nachbardisplay | Dwell 150 bis 300 ms oder explizites Modifier-Gate; kein reiner Distanz-Threshold |
| Oberer Rand bei normalem Fensterdrag | Keine eigene Zone; dort liegen Menubar-Fill und Mission-Control-Trigger |
| Oberer Rand bei AltTab+-Modifier-Drag | Eigenes `Fill`-Ziel innerhalb derselben Drag-Sitzung; Overlay vor Mouseup, kein macOS-Fullscreen-Space |
| Unterer Rand | Deaktiviert; Kollision mit Dock Auto-Hide und Magnification |

Folgeumfang:

- Konfigurierbares Padding fuer AltTab+-Layout- und Snap-Zielrahmen.
- Ein-/ausschaltbare beziehungsweise konfigurierbare Bewegungsanimation, ohne die AX-Queue oder Mouseup-Latenz zu verschlechtern.
- Konfigurierbare Snap-Zonenstaerke und Dwell-Zeit mit sicheren Wertebereichen; das MVP verwendet feste, getestete Werte.
- Allgemeiner Undo-Stack erst nach dem Ein-Schritt-Restore und nur mit klarer Semantik fuer mehrere Fenster, Displays und externe Fensteraenderungen.

Repo-Learnings:

- `mikusnuz/nudge` nutzt Drag-to-edge Snapping mit Preview und Accessibility API fuer Fensterbewegung.
- Rectangle nutzt Snap Areas an Rands- und Eckbereichen und zeigt einen Zielbereich als Preview.
- `mikusnuz/nudge` und Rectangle liefern Drittel/Zwei-Drittel; genau dort liegt gegenueber Apple eher Differenzierungswert.
- `mikusnuz/nudge` ist nicht `macadmins/nudge`. Im Backlog immer Repo-Owner mitschreiben.
- Electron-Fallback und Chrome-`AXEnhancedUserInterface`-Workaround sind version-unabhaengig als Repo-Learning aufgenommen; konkrete Release-Notes nur bei Code- oder Algorithmusuebernahme erneut verifizieren.

### 6. Reverse Scrolling und Scroll Speed

Status: Tap-basierter Folge-Spike
Prioritaet: Niedriger als Pointer Accel/Speed

Beschreibung:

- Getrennte Scrollrichtung und Scroll-Geschwindigkeit fuer Maus und Trackpad.
- Anders als Pointer Accel/Speed braucht dies einen aktiven `CGEventTap` auf `scrollWheel`, solange die Einstellung aktiv ist.

Zentrale Korrektur:

- macOS kennt nur eine globale Natural-Scrolling-Praeferenz.
- Getrennte Scrollrichtung fuer Maus und Trackpad ist nicht ueber Defaults oder IOKit erreichbar.
- Kategorienunterscheidung ohne Device-Enumeration ueber `kCGScrollWheelEventIsContinuous` und Momentum-/Phase-Felder: kontinuierlich fuer Trackpad oder Magic Mouse, diskret fuer klassisches Rasterrad.

MVP-Scope:

- `Reverse vertical scrolling`.
- `Scroll speed`.
- Tap-Scope strikt auf `scrollWheel`.
- Kein `mouseMoved`-Tap.
- Momentum- und Phase-Events konsistent mitbehandeln.

Nicht im MVP:

- Smoothed Scrolling.
- Eigene Scroll-Kurven.
- Button-Remapping.
- Per-Device-Regeln.
- App-spezifische Regeln.
- Import von LinearMouse-Konfiguration.

Korrigierte Akzeptanzidee:

- Kein Event-Tap, solange keine tap-abhaengige Einstellung aktiv ist.
- Sobald Reverse Scrolling oder Scroll Speed aktiv ist, darf ein permanenter, enger `scrollWheel`-Tap laufen.

### 7. Trackpad-Gesten fuer Middle Click

Status: Letzter Spike
Prioritaet: Mittel

Beschreibung:

- Drei-Finger-Tap oder Drei-Finger-Click erzeugt Middle Click an der aktuellen Cursorposition.
- Drei-Finger-Drag bleibt Folgepunkt.
- Inspiration: MiddleDrag und MiddleClick.

Praezisierungen:

- Die Bruchstelle ist ABI-Drift, nicht nur Wegfall der API.
- Private Touch-Struct-Layouts muessen pro `ProductVersion` versioniert werden.
- Bei unbekannter Major-Version Modul deaktivieren statt raten.
- Tahoe-only reduziert ABI-Drift im ersten Zielzustand, weil nur ein Touch-Struct-Layout relevant ist.
- Separater Helper-Prozess ist Vorbedingung fuer Default-Aktivierung, nicht fuer Spike oder Opt-in.
- Middle-Click-Synthese mit `otherMouseDown`/`otherMouseUp`, Button 2, braucht Accessibility zum Posten.
- Systemschalter "Drei-Finger-Ziehen" in den Bedienungshilfen ist harter Konflikt und muss beim Aktivieren geprueft und gemeldet werden.
- Default: 4 und mehr Finger ignorieren.
- Kein oeffentlicher Ersatzpfad: Ausserhalb eigener Views liefert AppKit keine verlaessliche Fingeranzahl fuer Taps.

Nicht im MVP:

- Magic Mouse.
- Drei-Finger-Drag.
- App-spezifische Ausnahmen.
- Default-Aktivierung ohne Helper-Prozess.

## Settings-Modell

Status: Minimal halten

- Kein grosses Modulframework bauen.
- In der Settings-Sidebar erscheinen weitere Eintraege, z.B. `Pointer & Scroll`, `Window Layouts`, `Window Move/Resize`, `Window Snapping`, `Gestures`.
- Klick auf einen Eintrag scrollt rechts an den passenden Abschnitt.
- Jeder Abschnitt verwaltet seine Settings so lokal wie moeglich.
- Keine Profile wie `Windows-like`, `Minimal` oder `Custom` in der ersten Iteration.
- Keine Scheme-/Rule-Engine aus LinearMouse uebernehmen.
- Settings-Suche ist im Fork view-basiert/generiert: `SettingsWindow` traversiert die Settings-Views und sammelt Labels, Buttons, Dropdowns, Segmented Controls, Tabellen und TextViews.
- Neue experimentelle Abschnitte muessen nicht aktiv aus der Suche ausgeschlossen werden. Unuebersetzte Labels sind aber sofort nur englisch suchbar.
- Sidebar vorerst flach halten.

## Aktionsoberflaechen

- Das gemeinsame typisierte Aktionsregister ist die einzige Quelle fuer Window Layouts, Restore, Display-Wechsel und spaetere Fensteraktionen.
- Globale Shortcuts, Hyper, Leader, FlickRing und die klickbaren Space-Segmente verwenden dieses Register.
- Die bestehende Menueleiste wird als weiterer Verbraucher angebunden und bietet die verfuegbaren Fensteraktionen fuer das aktuell fokussierte geeignete Fenster an.
- Nicht verfuegbare Aktionen werden deaktiviert oder ausgeblendet; die Menueleiste implementiert keine eigene Fensterlogik.

## Distribution und Migration

- Produktname und Bundle-ID bleiben fork-spezifisch: AltTab+ und `com.gcolicig.alttab-plus`.
- Nutzer muessen Accessibility- und gegebenenfalls Screen-Recording-/Input-Monitoring-Freigaben fuer AltTab+ neu erteilen; Freigaben der originalen AltTab-App werden nicht uebernommen.
- Vor einer oeffentlichen Version festlegen: eigene Developer-ID-Signatur, Notarisierung und Vertriebskanal, z.B. eigener Cask oder Tap.
- Sparkle-Appcast und Signierschluessel sind nur erforderlich, wenn automatische Updates angeboten werden; ein manueller Release-Kanal ist ein gueltiger Fallback.
- Sparkle bleibt deaktiviert, solange kein fork-eigener Feed vollstaendig eingerichtet ist.
- Bestehender manueller Import nutzt `.plist`, nicht `alt-tab-macos.json`.
- Import aus AltTab oder aelteren AltTab+-Versionen wird als gefuehrte Migration angeboten; kompatible Switcher-Settings werden uebernommen, unbekannte oder veraltete Keys ignoriert.
- Import ersetzt nicht ungefiltert die gesamte Settings-Domain.
- Q-08 wird nach jedem Import und jeder Migration technisch erzwungen: Pointer/Scroll, Move/Resize, Snapping und Gesten bleiben deaktiviert, bis der Nutzer sie in AltTab+ bewusst aktiviert.

## Verifikationsstrategie

AX- und globale Input-Pfade werden durch reproduzierbare manuelle Integrationstests abgesichert. Unit-Tests bleiben fuer reine Geometrie-, Mapping-, Filter- und Settings-Logik zustaendig.

Pruefraster fuer AX-basierte Fenstermodule:

| Pruefung | Erwartung |
|---|---|
| Fenstererkennung | Korrektes Fenster unter Cursor oder Fokus wird gefunden; bei Unsicherheit keine Aktion |
| Position und Groesse | Layout, Move und Resize erreichen das erwartete Rect innerhalb app-bedingter Toleranzen |
| Grenzen | Mindest-/Maximalgroesse, Zeichenraster und nicht skalierbare Fenster werden respektiert |
| Fokus und Zustand | Kein unbeabsichtigter Fokuswechsel; Fullscreen, minimierte und modale Fenster werden korrekt behandelt |
| Drag-Latenz | Kein sichtbarer Queue-Aufstau; AX-Timeout und Coalescing greifen |
| Abbruch und Degradation | Mouseup, Escape, Space-/Display-Wechsel, fehlende Berechtigung und unbekannte private API hinterlassen keinen aktiven Tap oder Overlay |

App-Klassen-Matrix:

- AppKit.
- Catalyst.
- Chromium.
- Electron.
- AWT/Swing.
- Qt.
- Terminal mit Zeichenraster-Clamping.

Befund 2026-08-03 zu Electron im Switcher: Kurz nach einem Systemstart zeigte Claude (`com.anthropic.claudefordesktop`) zwei Eintraege. Das zweite Fenster war 800x600, ohne Titel, nicht auf dem Bildschirm, trug aber Rolle `AXWindow` und Subrolle `AXStandardWindow` und passierte damit jede generische Pruefung. Weder Sichtbarkeit noch Space-Zugehoerigkeit taugen zur Unterscheidung: `CGSCopySpacesForWindows` meldete fuer dieses Fenster den aktuellen Space, und ein legitim minimiertes Fenster einer anderen App ist genauso wenig auf dem Bildschirm. Einziges belastbares Unterscheidungsmerkmal war der leere Titel. Rund 17 Minuten spaeter war das Fenster von selbst verschwunden, der Fall ist seither nicht reproduzierbar und vermutlich auf die Startphase der App beschraenkt. Vor einer Regel im Discriminator ist ein reproduzierbarer Fall abzuwarten.

Testmittel:

- Kleine native Test-App mit normalen, nicht skalierbaren, groessenbegrenzten, modalen und mehreren Fenstern in definierten Ausgangsrects.
- Pro externer App-Klasse mindestens eine dokumentierte Referenz-App und Version.
- Kurze manuelle Checkliste pro Modul mit Ausgangszustand, Aktion, Soll-Ergebnis und erlaubter Degradation.
- Tahoe-Tiling-Matrix und Modul-Checklisten vor jeder oeffentlichen Version sowie nach jedem unterstuetzten macOS-Major-Update erneut ausfuehren.
- Fehler werden mit Q-07-Ringbuffer, App-Klasse, App-Version, macOS-Build und Display-Konfiguration dokumentiert.

Display-Topologien fuer Layouts und Snapping:

- Ein Display sowie mehrere Displays links, rechts, oberhalb und unterhalb des Hauptdisplays.
- Unterschiedliche Aufloesungen, Skalierungen und Refresh-Raten.
- Dock links, rechts, unten sowie Auto-Hide; Menubar und Notch/Camera Housing pro Display ueber das jeweils frisch gelesene `visibleFrame` beruecksichtigen.
- `safeAreaInsets` nicht pauschal als Layout-Grenze normaler Fenster verwenden; sie sind primaer fuer eigene Fullscreen-Inhalte relevant.
- Systemeinstellung "Bildschirme haben separate Spaces" ein und aus.
- Landscape-, Portrait- und rotierte Displays.
- UX-Entscheidung am Zielgeraet verifizieren: Thirds immer entlang der horizontalen Achse oder auf Portrait-Displays entlang der laengsten Achse.
- Display-Anordnung, Aufloesung oder Skalierung waehrend eines aktiven Drags aendern.
- Display waehrend eines aktiven Drags trennen oder verbinden; laufendes Ziel verwerfen und gegen die neue Geometrie bestimmen.
- Nach Display-Trennung nur laufende Operationen sowie von AltTab+ gespeicherte Ziel- und Restore-Rects auf ein vorhandenes `visibleFrame` abbilden oder clampen. Keine pauschale Umsiedlung fremder Fenster; die allgemeine Repositionierung bleibt macOS ueberlassen.

Energiepruefung:

- Baseline: unveraenderter Fork im Idle fuer einen festgelegten Messzeitraum.
- Vergleich: gleicher Ablauf mit allen neuen Modulen aus sowie einzeln aktiviert.
- Idle-Messung ueber mindestens zehn Minuten; CPU-Zeit und Wakeups werden mit derselben Messmethode und auf demselben Zielgeraet verglichen.
- Aktive Messungen verwenden feste Ablaeufe fuer Scrollen, Move/Resize, Snapping und Gesten.
- Akzeptiert wird nur, wenn ausgeschaltete Module keine Taps oder periodischen Timer hinterlassen und aktivierte Module im Idle keine relevante, reproduzierbare Mehrlast gegenueber der Baseline zeigen.
- Messmethode, Baseline und Ergebnis werden im Release-Check dokumentiert; die wechselhafte Anzeige in Activity Monitor ist kein alleiniges Akzeptanzkriterium.

## Spikes mit Exit-Kriterien

| ID | Spike | Exit-Kriterium |
|---|---|---|
| S-01 | AX-Fensteroperations-Kern | Identifikationskette liefert in 20 von 20 manuellen Faellen ueber alle Klassen der Kompatibilitaetsmatrix das korrekte Fenster oder verweigert bewusst |
| S-02 | AX-Latenz bei Drag | Move und Resize bei 30 bis 60 Hz Coalescing ohne sichtbaren Lag in AppKit-Apps; dokumentiertes Verhalten fuer Chromium, Electron, AWT, Terminal |
| S-03 | Pointer Accel/Speed via IOKit | Getrennte Werte fuer Mouse und Trackpad setzbar und restaurierbar, ohne Event-Tap, private API oder zusaetzliche TCC-Berechtigung; Aenderung ausserhalb von AltTab+ persistiert `relinquished`; Crash-/Kill-Recovery restauriert nur unter Gleichheitspruefung |
| S-04 | Tahoe-Tiling-Feature-Matrix | Auf macOS Tahoe / Apple Silicon dokumentierte Liste nativ vorhandener Drag- und Shortcut-Aktionen |
| S-05 | Scroll-Tap Kosten | Tap-Recovery nachgewiesen; feste Scrollmessung bleibt innerhalb des unter Energiepruefung dokumentierten Budgets |
| S-06 | Instant Spaces | Links/rechts und direkter Index wechseln auf verifiziertem Tahoe ohne sichtbare Animation; Display-Ziel, Randblockierung und Ist-Zustand konvergieren bei schnellen Folgen; fehlende Symbole oder unbekannte Version deaktivieren nur das Modul |
| S-07 | Spaces-Menueleiste | Space-Anzahl und aktiver Zustand konvergieren ereignisbasiert ohne Polling; Klick aktiviert den erwarteten Space; Ueberlauf, Separate-Spaces-Modi und deaktiviertes Instant Spaces degradieren bedienbar |
| S-09 | HID-Remapping unterhalb des Event-Taps | `hidutil UserKeyMapping` laesst sich auf Tahoe aus dem Agent-Prozess setzen und nach Keyboard-Hotplug erneuern, ohne Root und ohne LaunchAgent; die Zuordnung wirkt nachweislich auch bei aktivem Secure Input; Entzug und Absturz hinterlassen keine dauerhafte Umbelegung |
| S-08 | Stabile Space-Identitaet | **Bestanden 2026-08-03** auf macOS 26.5.1 (Build 25F80). Drei Spaces ueberlebten einen Neustart mit unveraenderter UUID, waehrend zwei ihre `id64` wechselten (31→7, 33→6). Reorder, Create, Delete, Fullscreen und natives Wechseln liessen die UUIDs ebenfalls unveraendert. Aliase und Profil-Bindings duerfen auf die UUID zeigen, niemals auf `id64` oder den Index. Nicht geprueft: Umschalten von `Displays haben separate Spaces` und Display-Wechsel, beides mangels zweitem Display |
| S-10 | Synchroner Mehrdisplay-Space-Wechsel | Cursor-Warp plus Swipe schaltet alle Displays in einer Aktion auf denselben Index, ohne haengenden Cursor und ohne Mission-Control-Stoerung; andernfalls bleibt das a-Modell aus 2F deaktiviert |
| S-11 | Programmatisches Anlegen/Loeschen von Spaces | `CGSSpaceCreate`/`CGSSpaceDestroy` optional gebunden; Anlegen und Loeschen wirkt korrekt, Dock und Mission Control bleiben konsistent, Symbolwegfall degradiert nur dieses Feature |

## Umsetzungsreihenfolge

1. Abgeschlossen: fokussierter AX-Fensterpfad, Window Layouts und Hyper sind umgesetzt; Dokumentation und automatisierte Tests sind aktualisiert, der aktuelle Funktionsstand wurde manuell abgenommen. Formale App-/Display-Matrizen bleiben wiederkehrende Release-Gates.
2. Plattform-Gates vor privaten oder kontinuierlichen Modulen schliessen: Tahoe-Tiling-Matrix S-04, degradierbare Symbolbindung V-03 und Provenienz-Register V-04.
3. Minimalen gemeinsamen Aktionskern gemaess Q-01 aufbauen: Die erste Ausbaustufe fuer Window Layouts, Restore und globale Shortcuts ist umgesetzt; Display-, Space-, App-, URL- und Menueleisten-Verbraucher folgen. Keine beliebigen Makros oder Shell-Kommandos.
4. Instant-Spaces-Kern ist als tap-freie Private-Event-Reimplementierung ueber das Aktionsregister umgesetzt; S-06/V-12 bleiben als manuelle Tahoe-Pruefung offen, Swipe-Override bleibt Folgeumfang.
5. Teilweise abgeschlossen: Spaces-Menueleiste mit Nummern, monochrom aktivem Zustand, Klick und Shortcut-Fallback ist umgesetzt. S-07 bleibt fuer Mehrdisplay, Ueberlauf, Create/Delete/Reorder, VoiceOver und Degradation offen.
6. Abgeschlossen: Stabile Space-Identitaet S-08 ist am 2026-08-03 bestanden. Aliase und persistente Profil-Bindings duerfen auf der Managed-Space-UUID aufbauen.
7. Cursor-basierten AX-Fensterkern und AX-Latenz-Spikes S-01/S-02 fuer kontinuierliche Operationen abschliessen.
8. Move samt gemeinsamer Modifier-Drag-Sitzung und den exklusiven Zielen `Left half`, `Right half` und `Fill` umsetzen; sichere Input-Laufzeit gemaess Q-04 und Q-11 bis Q-16 fuer diesen Pfad erweitern.
9. Resize auf derselben Cursor-Erkennung, AX-Queue und Input-Sicherung aufbauen; jeweils ohne Default-Trigger.
10. Leader-Modus mit verschachtelten Sequenzen umsetzen, danach FlickRing mit reservierter Seitentaste; die Input-Sicherung jeweils nur um den benoetigten Modulpfad erweitern.
11. Weiteres Snapping ausserhalb des Modifier-Drags nur dort ergaenzen, wo Tahoe nativ nicht ausreicht; setzt S-04 und V-11 voraus.
12. Projektprofile mit Apps, Layout und Space-Binding einfuehren; manueller Session-Restore bleibt die zweite Ausbaustufe.
13. Reverse Scrolling und Scroll Speed mit Tap umsetzen; setzt S-05 voraus.
14. Gesten als letzten Spike behandeln; Default-Aktivierung erst mit Helper-Prozess.

Pointer Accel/Speed ist kein Schritt der linearen Abhaengigkeitskette. Der settings-basierte Spike S-03 darf nach Abschluss von Schritt 1 parallel zu Aktionskern, Spaces und Fensteroperationen laufen.

Default-Settings, Reset-Verhalten und Migration werden nach jedem neuen Modul geprueft. Vor einer oeffentlichen Version folgt zusaetzlich ein Gesamtaudit aller Fork-Defaults.

## Geschlossene Fragen

| Frage | Entscheidung |
|---|---|
| Zielplattform | macOS Tahoe auf Apple Silicon |
| Intel und aeltere macOS-Versionen | Bewusst ausgeschlossen |
| MultitouchSupport akzeptabel | Ja, versioniert und mit Helper-Prozess als Vorbedingung fuer Default-Aktivierung |
| Magic Mouse im MVP | Nein |
| Modifier fuer Move/Resize | Kein Default, Picker mit Kollisionspruefung; `Command+Control` explizit waehlbar und nur bei `NSWindowShouldDragOnGesture == false` |
| Chrome-Workaround sofort | Ja, mit Restore und VoiceOver-Ausnahme |
| Fenster-Identifikation | Fokus fuer Keyboard Layouts; Element unter Mousedown zuerst fuer Cursor-Module |
| Edge-Toleranz | Modell in Points, getrennt fuer freie und geteilte Raender |
| Bottom-Edge | Deaktiviert |
| Default-Shortcuts Layouts | Keine; Preset-Picker optionaler Folgeumfang |
| Shortcut-Wiederholung | Nicht im MVP |
| Scrollrichtung getrennt ohne Tap | Nicht moeglich |
| Nur Maus im ersten Pointer-Spike | Ja |
| Settings-Suche | View-basiert/generiert; unveraendert weiterverwenden |
| Sidebar flach | Ja |
| `_AXUIElementGetWindow` vorhanden | Ja; der Wrapper loest das Symbol optional zur Laufzeit auf und degradiert bei Wegfall auf einen Fehler der jeweiligen Fenster-ID-Abfrage |
| Produktarchitektur | Integrierte AltTab+-App; keine separate Companion-App und keine geplante Upstream-Rueckspielung |
| Hyper-MVP | Dual-Role Caps Lock: kurzer Tap schaltet Caps Lock, Halten plus Taste erzeugt systemweites Hyper; Window Layouts verwenden dieselben globalen Shortcuts |
| Caps-Lock-Tap | Bleibt fuer normales Caps Lock reserviert; Leader erhaelt einen eigenen Trigger |
| Leader-Aktionen | Typisiertes Register, keine beliebigen Makros oder Shell-Kommandos im ersten Umfang |
| FlickRing-MVP | Reservierte zusaetzliche Maustaste; Mittelklick-Passthrough erst nach Rekursionstest |
| Moves-Integration | Funktionale Reimplementierung auf AltTab+-Queues; Move und Modifier-Snapping teilen eine Drag-Sitzung; keine direkte Portierung des Referenz-Controllers |
| Instant-Spaces-MVP | Aktionsgesteuerter Wechsel links/rechts/Index durch synthetische Dock-Swipes; kein permanenter Tap und kein nativer Swipe-Override |
| Spaces-Menueleiste | Optional rechts neben AltTab+, aktiver Space hervorgehoben, Klick ueber gemeinsames Aktionsregister, Shortcuts als Fallback |
| Mehrere Displays und Spaces | Standardmaessig macOS-Semantik folgen: gruppiert bei separaten Spaces, gemeinsame Reihe bei deaktivierter Systemeinstellung |
| Projektprofile | Eigene stabile Objekte; Space-Alias bleibt reine Anzeige. Apps/Layout zuerst, manueller Session-Restore spaeter |

## Verifikationspunkte

| ID | Punkt | Umgang |
|---|---|---|
| V-01 | Tahoe-Tiling-Feature-Matrix am Apple-Silicon-Zielgeraet | Manuelle Verifikation gemaess `docs/tahoe-tiling-checklist.md` |
| V-02 | Versions-Policy nach Tahoe-only | Klaeren: nur aktuelle Major-Version `N` oder `N und N-1` |
| V-03 | Private Symbolbindung | `_AXUIElementGetWindow` ist optional zur Laufzeit gebunden; weitere private Symbole vor ihrer ersten neuen Modulnutzung gleichwertig degradierbar machen |
| V-04 | Provenienz-Register | `THIRD-PARTY.md` ist fuer die bisher ausgewerteten Quellen angelegt; Pflege im PR-Prozess bleibt zu erzwingen |
| V-05 | Modul- und App-Klassen-Checklisten | `docs/input-safety-checklist.md`, `docs/window-layout-checklist.md`, `docs/window-drag-checklist.md`, `docs/shortcut-clues-checklist.md` und `docs/spaces-menubar-checklist.md` vor jeder oeffentlichen Version und nach jedem unterstuetzten macOS-Major-Update ausfuehren |
| V-06 | Energie-Baseline | Idle- und Aktivmessungen auf dem Tahoe-/Apple-Silicon-Zielgeraet dokumentieren |
| V-07 | Distribution | Signing, Notarisierung, Vertriebskanal und Update-Strategie vor erster oeffentlicher Version abschliessen; Sparkle bleibt optional |
| V-08 | Safe Start und Circuit Breaker | Vor dem ersten ausgelieferten Input-Modul mit Login-Start, verbliebenem Arming-Marker und wiederholtem Tap-Timeout pruefen |
| V-09 | Berechtigungsentzug | Accessibility und Input Monitoring getrennt bei Start, Aktivierung, Wake und Laufzeit pruefen |
| V-10 | Pointer State Ownership | Aenderung durch Systemeinstellungen oder paralleles Maus-Tool, persistiertes `relinquished`, erneute Besitzuebernahme, Disable, saubere Terminierung, Crash, `SIGKILL`, Wake und Device-Reconnect ohne Rueckschreibschleife oder destruktives Restore pruefen |
| V-11 | Display-Topologien | Snapping-Checkliste ueber definierte Topologien, Separate-Spaces-Zustaende und dynamische Reconfiguration ausfuehren |
| V-12 | Instant Spaces | Tahoe-Build, Separate Spaces ein/aus, Cursor-Display, Fullscreen-Space, Stage Manager, Mission Control/App Expose, Randwechsel und schnelle direkte Mehrfachwechsel pruefen |
| V-13 | `Command+Control`-Move | `NSWindowShouldDragOnGesture` vor Aktivierung lesen, auf `false` setzen und verifizieren; Disable, externe Aenderung, Crash und Recovery ohne destruktives Restore pruefen |
| V-14 | Spaces-Menueleiste | Checkliste `docs/spaces-menubar-checklist.md`. Ein bis 16 Spaces, mehrere Displays, Fullscreen-Spaces, Reorder, Create/Delete, Wake, Mission-Control-Ende, Statusleisten-Ueberlauf und VoiceOver pruefen; mit drei Bildschirmen und deaktivierten separaten Spaces pruefen, dass nur Gruppen mit mehr als einem Space erscheinen und kein Trenner uebrig bleibt |
| V-15 | Profile und Session-Restore | Fenster-Matching, App-Start, verlorene Space-Bindings, geaenderte Titel, mehrere Fenster derselben App und geaenderte Display-Topologie ohne falsche Mutation pruefen |

## Provenienz-Register

Mechanismus: `THIRD-PARTY.md` im Repo-Root, eine Zeile pro Quelle.

| Spalte | Inhalt |
|---|---|
| Quelle | Repo-URL, Version oder Commit-SHA, Abrufdatum |
| Lizenz | SPDX-Kennung, aus der LICENSE-Datei verifiziert |
| Uebernahmeart | A = Verhalten beobachtet, B = Algorithmus reimplementiert, C = Code uebernommen |
| Zieldateien im Fork | Nur bei B und C |
| Attribution erledigt | Nur bei C |

Regeln:

- Art C erfordert Lizenzkopf in der Zieldatei plus Eintrag in `NOTICE`, falls die Lizenz das verlangt.
- Art A und B brauchen rechtlich meist nichts, werden aber fuer Auditierbarkeit erfasst.
- `jmgao/metamove` ist GPL-2.0-or-later und damit mit einer GPL-3-Basis kompatibel. Code-Uebernahme ist rechtlich moeglich, aber strategisch eine Copyleft-Einbahnstrasse; daher vorerst nur als Verhaltens- und Architekturvorbild nutzen.
- `mikusnuz/nudge` ist MIT-lizenziert; Code-Uebernahme nur nach eigenem Review, nicht auf Reputationsbasis.
- `jurplel/InstantSpaceSwitcher` ist MIT-lizenziert; Typ B ist als funktionale Swift-Reimplementierung mit Quelle, Commit-SHA, Abrufdatum und Zieldateien im Provenienz-Register dokumentiert.
- `xiamaz/YabaiIndicator` ist MIT-lizenziert; vorerst Typ A fuer Menueleisten-Darstellung, Multi-Display-Gruppierung und ereignisbasierte Aktualisierung. Keine yabai-, Socket- oder SIP-abhaengige Implementierung uebernehmen.
- `royalbhati/HopTab` ist MIT-lizenziert; vorerst Typ A fuer Profile, Space-Binding und Session-Ablauf. Keine direkte Uebernahme des sitzungslokalen Space-ID- oder titelbasierten Fenster-Matchings.
- PR-Template spaeter um Checkbox ergaenzen: Provenienz-Register aktualisiert oder n/a.

## Gelesene Inspirationsquellen

- Apple Tile windows: https://support.apple.com/guide/mac-help/tile-windows-mchlef287e5d/mac
- Apple Tiling shortcuts: https://support.apple.com/guide/mac-help/window-tiling-icons-keyboard-shortcuts-mchl9674d0b0/mac
- Apple Tiling settings: https://support.apple.com/guide/mac-help/change-window-tiling-settings-mchl118087b0/mac
- Apple Right-click / Control-click: https://support.apple.com/guide/mac-help/right-click-mh35853/mac
- Apple Work in multiple spaces: https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac
- Apple Mission Control: https://support.apple.com/guide/mac-help/view-open-windows-and-spaces-mh35798/mac
- Apple Desktop & Dock settings: https://support.apple.com/guide/mac-help/change-desktop-dock-settings-mchlp1119/mac
- Apple Rosetta / Intel transition note: https://developer.apple.com/documentation/Apple-Silicon/about-the-rosetta-translation-environment
- MiddleDrag: https://middledrag.app/
- MiddleClick: https://github.com/artginzburg/MiddleClick
- mikusnuz/nudge: https://github.com/mikusnuz/nudge
- mikusnuz/nudge Projektseite: https://nudge.run/
- mikusnuz/nudge technischer Erfahrungsbericht: https://dev.to/alanwest/i-made-a-free-mac-window-manager-because-magnet-doesnt-exist-outside-the-app-store-3j93
- jmgao/metamove: https://github.com/jmgao/metamove
- Rectangle: https://github.com/rxhanson/Rectangle
- Rectangle Snap Areas: https://rectangleapp.com/pro/docs/snap-areas/
- LinearMouse Configuration: https://github.com/linearmouse/linearmouse/blob/main/Documentation/Configuration.md
- mikker/LeaderKey: https://github.com/mikker/LeaderKey
- mikker/FlickRing: https://github.com/mikker/FlickRing
- mikker/Moves: https://github.com/mikker/Moves
- jurplel/InstantSpaceSwitcher: https://github.com/jurplel/InstantSpaceSwitcher
- xiamaz/YabaiIndicator: https://github.com/xiamaz/YabaiIndicator
- royalbhati/HopTab: https://github.com/royalbhati/HopTab

## Nicht-Ziele fuer die erste Iteration

- Vollstaendige BetterTouchTool-Kompatibilitaet.
- Beliebig skriptbare Automationen.
- Umfangreiche Makro- oder App-Launcher-Funktionen.
- Vollstaendige LinearMouse-Kompatibilitaet.
- App-, Display- oder Device-ID-spezifische Pointer-/Scroll-Regeln.
- Ueberschreiben oder Unterdruecken nativer Apple-Snap-Zonen ausserhalb einer expliziten AltTab+-Modifier-Drag-Sitzung.
- Abfangen oder Ersetzen nativer Space-Trackpad-Swipes im Instant-Spaces-MVP.
- Intel-Support.
- Support fuer macOS-Versionen vor Tahoe.
