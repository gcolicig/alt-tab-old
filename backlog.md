# Backlog: Mac UX Enhancer

Stand: 2026-07-26

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

Status: Geplant; Dual-Role-Hyper umgesetzt
Prioritaet: Sehr hoch

Beschreibung:

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
- Nicht intern konfigurierte Tasten, einschliesslich Pfeiltasten mit `Do nothing`, bleiben fuer systemweite Hyper-Shortcuts verfuegbar.

Leader:

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
- Fuer kontinuierliche Cursor-Module offen: Element-at-position-Kette, Coalescing, erweiterter Diagnose-Ringbuffer und die vollstaendige App-Klassen-Matrix.

Ausschlussfilter:

- Fullscreen-Fenster.
- Fenster in anderen Spaces.
- Stage-Manager-Zustand.
- `AXMinimized`.
- Fenster ohne settable `kAXSizeAttribute`.
- Fenster mit min gleich max Size, z.B. Sheets oder Panels.

Chrome/Electron/AX:

- `AXEnhancedUserInterface`-Workaround direkt einplanen.
- Attribut nur fuer die Dauer der Operation deaktivieren und danach Originalwert restaurieren.
- Bei aktivem VoiceOver oder anderem Assistive-Technology-Tool Workaround ueberspringen.
- Fuer Electron `AXManualAccessibility` als seiteneffektfreie Alternative pruefen.

Private-API-Befund:

- `_AXUIElementGetWindow` ist vorhanden, aber aktuell per `@_silgen_name` gebunden.
- Restarbeit: optionales/weak Binding oder gleichwertige Degradationsstrategie pruefen, damit ein Symbolwegfall nicht zum Startup-Problem wird.

Kompatibilitaetsmatrix:

- AppKit.
- Catalyst.
- Chromium.
- Electron.
- AWT/Swing.
- Qt.
- Terminal-Apps mit Zeichenraster-Clamping.

### 2. Keyboard-basierte Window Layouts

Status: Revidierter MVP-Kandidat
Prioritaet: Hoch

Beschreibung:

- Tastatur-Layoutaktionen fuer Fenster, ohne Event-Tap, ohne Overlay, ohne Drag-Tracking und ohne private API.
- Nutzt den AX-Fensteroperations-Kern.
- Deckt besonders Luecken gegenueber Apple ab.

Erste umgesetzte Ausbaustufe:

- Thirds.
- Two-Thirds.
- Restore.
- Keine Shortcuts vorregistrieren.
- Kollisionspruefung gegen registrierte AltTab-Hotkeys.

Folgeumfang nach Tahoe-Feature-Matrix:

- Center.
- Display-Moves.
- Optionaler Preset-Picker.
- Halves/Quarters nur, wenn die Tahoe-Feature-Matrix echten Bedarf zeigt.

Nicht im MVP:

- Shortcut-Wiederholung zum Zyklieren.
- Pro-Display Grid-Definitionen.
- App-spezifische Layout-Regeln.

Repo-Learnings:

- Nudge nutzt Magnet-nahe Defaults mit `Ctrl + Option` und bietet Halves, Quarters, Thirds, Two-Thirds, Maximize, Center, Restore und Display-Wechsel.
- Rectangle bietet viele explizite Aktionen, darunter Thirds, Two-Thirds, Viertel, Achtel, Neuntel, Center, Restore und Display-Wechsel.
- Rectangle-Defaults sind bei Zielnutzern haeufig schon belegt; deshalb keine Default-Shortcuts.
- `Fn-Control-*` gehoert ab aktuellen macOS-Versionen Apple und ist als Default ausgeschlossen.

### 3. Modifier-basierter Window Move/Resize

Status: Revidierter MVP-Kandidat
Prioritaet: Hoch

Beschreibung:

- Fenster unter dem Cursor bewegen oder resizen, ohne den Fensterrahmen exakt treffen zu muessen.
- Ziel ist ein BTT-aehnliches Move/Resize-Verhalten.
- Kein Default-Modifier; Modul startet aus.
- Keine direkte Uebernahme von `Moves/WindowHandler.swift`; AltTab+ verwendet den eigenen AX-, Queue-, Timeout- und Diagnosepfad.

Drag-Sitzung:

1. Zustand `idle -> armed -> resolving -> dragging -> finishing/cancelled`.
2. Fenster an der ersten relevanten Mausposition einmal bestimmen und fuer die ganze Sitzung festhalten.
3. Ursprungsrahmen und Mausposition einmal speichern; Ziel aus kumulativem Delta berechnen.
4. Event-Callback publiziert nur den neuesten Zielrahmen.
5. Serielle AX-Queue schreibt mit Coalescing bei 30 bis 60 Hz und laesst hoechstens einen Set-Aufruf gleichzeitig laufen.
6. Move zuerst ausliefern; Resize und weitere Fenster-Fallbacks erst nach bestandener Move-Matrix.

Modifier-Regeln:

| Kombination | Bewertung |
|---|---|
| `ctrl` in jeder Kombination | Ausgeschlossen. Control-click ist systemweit Secondary Click |
| `option` | Belegt. Apple nutzt Option beim Drag fuer schnelleres Tiling; Finder nutzt Option fuer Copy-Drag |
| `cmd` allein | Belegt. macOS zieht damit bereits Hintergrundfenster ohne Fokuswechsel |
| `fn` / Globe | Kandidat, aber nicht als Default; Nicht-Apple-Tastaturen melden es teils nicht als `maskSecondaryFn`, und Apple belegt `Fn-Control-*` |
| `cmd+shift`, `cmd+ctrl` | Kandidaten; `cmd+ctrl` nur mit Pruefung der Secondary-Click-Interpretation |

Repo-Learnings:

- `jmgao/metamove` ist eine thematisch nahe Referenz fuer XFree86-style Modifier-Drag.
- `jmgao/metamove` nutzt laut README `Cmd-Shift-Click` fuer Move und `Option-Shift-Click` fuer Resize.
- `Option-Shift` ist unter Tahoe wegen Apples Option-Drag-Tiling nicht mehr als Default geeignet; `Cmd-Shift` bleibt ein valider Kandidat im Picker.
- Bei Nutzung von metamove als Referenz Originalquellen erneut lesen. Die detaillierte AX-Kette ist noch nicht vollstaendig aus einer eigenen Repo-Durchsicht belegt.

Entscheidung:

- Kein Default-Modifier ausliefern.
- Beim ersten Aktivieren: Modifier-Picker mit Live-Kollisionspruefung.
- Modifier-Flags erst nach Mousedown auswerten, damit Secondary-Click-Interpretation nicht als Blocker greift.
- Modul bleibt Opt-in.

Akzeptanzideen:

- Nutzer kann Move und Resize getrennt konfigurieren.
- Dragging fuehlt sich in AppKit-Apps fluessig an.
- Nicht-standard Fenster werden ignoriert, wenn sie nicht sicher resizable sind.
- Latenz wird pro App-Klasse bewertet, nicht pauschal.

### 4. Pointer Acceleration und Speed

Status: Settings-basierter Early-Win-Spike
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

Im Scope:

- Coexistence-Pruefung: Sind native Tiling-Schalter aktiv?
- UX-Hinweis, dass Apples Schalter nur durch Nutzer in Desktop & Dock geaendert werden koennen.
- Luecken-Kandidaten: Thirds, Two-Thirds, Custom-Zonen, Center, Display-Moves.
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

- Left/right half, corner quarters, top-maximize als Drag-Ziele, solange Tahoe sie nativ liefert.
- Ueberschreiben oder Unterdruecken von Apples Snap-Zonen.
- Bottom-Edge im MVP.
- Gespeicherte Layouts.
- Snap Groups.
- Animierte oder konfigurierbare Overlays.

Edge-Modell:

| Randtyp | Trigger |
|---|---|
| Freier Rand ohne Nachbardisplay | Cursor an Screen-Bounds geclampt, Toleranz 2 bis 4 pt, sofort |
| Geteilter Rand mit Nachbardisplay | Dwell 150 bis 300 ms oder explizites Modifier-Gate; kein reiner Distanz-Threshold |
| Oberer Rand | Keine eigene Zone; dort liegen Menubar-Fill und Mission-Control-Trigger |
| Unterer Rand | Deaktiviert; Kollision mit Dock Auto-Hide und Magnification |

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

## Umsetzungsreihenfolge

1. Fokussierter AX-Fensterpfad fuer einmalige Tastaturaktionen.
2. Keyboard Layouts mit Thirds, Two-Thirds und Restore, ohne Default-Shortcuts. Dieser Stand ist umgesetzt.
3. Dual-Role-Hyper fuer systemweite Shortcuts und vorhandene Window Layouts, deaktiviert per Default. Dieser Stand ist umgesetzt.
4. Gemeinsames Aktionsregister und Input-Laufzeit gemaess Q-01, Q-04, Q-11 bis Q-16 sowie V-08/V-09 vervollstaendigen.
5. Leader-Modus mit verschachtelten Sequenzen, danach FlickRing mit reservierter Seitentaste.
6. Cursor-basierter AX-Fensterkern und AX-Latenz-Spike S-01/S-02 fuer kontinuierliche Operationen.
7. Move zuerst, danach Resize, jeweils ohne Default-Trigger.
8. Pointer Accel/Speed als settings-basierter Early Win, sofern S-03 haelt.
9. Snapping nur dort, wo Tahoe nativ nicht ausreicht, setzt S-04 und V-11 voraus.
10. Reverse Scrolling und Scroll Speed mit Tap, setzt S-05 voraus.
11. Gesten als Spike; Default-Aktivierung erst mit Helper-Prozess.
12. Abschliessender Default-Settings-Audit: alle Fork-Defaults gemeinsam pruefen, Reset-Verhalten und Migration abgleichen und noetige manuelle Nachkonfiguration minimieren.

## Geschlossene Fragen

| Frage | Entscheidung |
|---|---|
| Zielplattform | macOS Tahoe auf Apple Silicon |
| Intel und aeltere macOS-Versionen | Bewusst ausgeschlossen |
| MultitouchSupport akzeptabel | Ja, versioniert und mit Helper-Prozess als Vorbedingung fuer Default-Aktivierung |
| Magic Mouse im MVP | Nein |
| Modifier fuer Move/Resize | Kein Default, Picker mit Kollisionspruefung |
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
| `_AXUIElementGetWindow` vorhanden | Ja, Wrapper existiert; weak/optional Binding bleibt Restarbeit |
| Produktarchitektur | Integrierte AltTab+-App; keine separate Companion-App und keine geplante Upstream-Rueckspielung |
| Hyper-MVP | Dual-Role Caps Lock: kurzer Tap schaltet Caps Lock, Halten plus Taste erzeugt systemweites Hyper; Pfeilaktionen koennen intern geroutet werden |
| Caps-Lock-Tap | Bleibt fuer normales Caps Lock reserviert; Leader erhaelt einen eigenen Trigger |
| Leader-Aktionen | Typisiertes Register, keine beliebigen Makros oder Shell-Kommandos im ersten Umfang |
| FlickRing-MVP | Reservierte zusaetzliche Maustaste; Mittelklick-Passthrough erst nach Rekursionstest |
| Moves-Integration | Funktionale Reimplementierung auf AltTab+-Queues; keine direkte Portierung des Referenz-Controllers |

## Verifikationspunkte

| ID | Punkt | Umgang |
|---|---|---|
| V-01 | Tahoe-Tiling-Feature-Matrix am Apple-Silicon-Zielgeraet | Manuelle Verifikation |
| V-02 | Versions-Policy nach Tahoe-only | Klaeren: nur aktuelle Major-Version `N` oder `N und N-1` |
| V-03 | Private Symbolbindung | `_AXUIElementGetWindow` und weitere private Symbole optional/weak oder gleichwertig degradierbar machen |
| V-04 | Provenienz-Register | `THIRD-PARTY.md` anlegen und Pflege im PR-Prozess erzwingen |
| V-05 | Modul- und App-Klassen-Checklisten | Vor jeder oeffentlichen Version und nach jedem unterstuetzten macOS-Major-Update ausfuehren |
| V-06 | Energie-Baseline | Idle- und Aktivmessungen auf dem Tahoe-/Apple-Silicon-Zielgeraet dokumentieren |
| V-07 | Distribution | Signing, Notarisierung, Vertriebskanal und Update-Strategie vor erster oeffentlicher Version abschliessen; Sparkle bleibt optional |
| V-08 | Safe Start und Circuit Breaker | Vor dem ersten ausgelieferten Input-Modul mit Login-Start, verbliebenem Arming-Marker und wiederholtem Tap-Timeout pruefen |
| V-09 | Berechtigungsentzug | Accessibility und Input Monitoring getrennt bei Start, Aktivierung, Wake und Laufzeit pruefen |
| V-10 | Pointer State Ownership | Aenderung durch Systemeinstellungen oder paralleles Maus-Tool, persistiertes `relinquished`, erneute Besitzuebernahme, Disable, saubere Terminierung, Crash, `SIGKILL`, Wake und Device-Reconnect ohne Rueckschreibschleife oder destruktives Restore pruefen |
| V-11 | Display-Topologien | Snapping-Checkliste ueber definierte Topologien, Separate-Spaces-Zustaende und dynamische Reconfiguration ausfuehren |

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
- PR-Template spaeter um Checkbox ergaenzen: Provenienz-Register aktualisiert oder n/a.

## Gelesene Inspirationsquellen

- Apple Tile windows: https://support.apple.com/guide/mac-help/tile-windows-mchlef287e5d/mac
- Apple Tiling shortcuts: https://support.apple.com/guide/mac-help/window-tiling-icons-keyboard-shortcuts-mchl9674d0b0/mac
- Apple Tiling settings: https://support.apple.com/guide/mac-help/change-window-tiling-settings-mchl118087b0/mac
- Apple Right-click / Control-click: https://support.apple.com/guide/mac-help/right-click-mh35853/mac
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

## Nicht-Ziele fuer die erste Iteration

- Vollstaendige BetterTouchTool-Kompatibilitaet.
- Beliebig skriptbare Automationen.
- Umfangreiche Makro- oder App-Launcher-Funktionen.
- Vollstaendige LinearMouse-Kompatibilitaet.
- App-, Display- oder Device-ID-spezifische Pointer-/Scroll-Regeln.
- Ueberschreiben oder Unterdruecken nativer Apple-Snap-Zonen.
- Intel-Support.
- Support fuer macOS-Versionen vor Tahoe.
