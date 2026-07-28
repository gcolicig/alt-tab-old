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
- Hyper-Kombinationen werden einheitlich als systemweite Shortcuts behandelt; Window Layouts nutzen dieselben globalen Shortcut-Felder wie andere Hyper-Ziele.
- Folgeumfang nach S-09: optionale Variante ohne Dual-Role. Eine reine 1:1-Umbelegung von Caps Lock auf einen Modifier ueber `hidutil UserKeyMapping` liegt unterhalb des Event-Taps und wirkt deshalb auch bei aktivem Secure Input, wo der HID-Monitor nichts meldet. Preis ist der Verlust der Tap-Funktion, da `hidutil` keine Tap-Hold-Logik kann. Nur als bewusst gewaehlte Alternative anbieten, nie als Default, und den Vorwert wie jeden globalen Systemzustand besitzen und zurueckgeben.

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
- Presets statt Defaults: das sinnvolle Set wird als benannte Zuweisung per Klick angeboten und ebenso wieder entfernt. `macOS Spaces` belegt `Control` plus 1 bis 9, `Control+0` fuer den Toggle und `Control` plus Pfeil fuer links/rechts; `Hyper Spaces` dasselbe auf der Hyper-Ebene ohne Systemuebernahme. Fuer Layouts gibt es `Rectangle-style` auf `Control+Option` mit den Buchstaben von Rectangle und `Hyper` mit denselben Buchstaben. Zuweisen ueberschreibt bestehende Belegungen und sichert den Vorzustand; Entfernen stellt genau diesen wieder her. Die Recorder-Felder folgen der Zuweisung sofort, damit sichtbar ist, was ein Preset gesetzt hat.
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

Status: Erster einzeiliger MVP-Schnitt implementiert, Mehrdisplay und Ueberlauf offen
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
- Das bestehende `NSStatusItem` zeigt rechts vom AltTab+-Symbol bis zu neun nummerierte Segmente fuer das Display unter dem Cursor.
- Der aktive Space verwendet eine staerkere monochrome Umrandung und eine dezente Flaeche; Tooltip und Accessibility-Label benennen das direkte Ziel.
- Klicks laufen ueber die registrierte `Space n`-Aktion. Space-, Display- und Wake-Ereignisse aktualisieren die Reihe ohne Polling.
- Eigene Spaces-Settings bieten konfliktgepruefte globale Shortcuts fuer links, rechts und Space 1 bis 9; alle bleiben per Default unbelegt.
- Manueller Befund vom 2026-07-27: Zum Aufzeichnen eines Space-Shortcuts musste Hyperkey in den Settings einmal aus- und wieder eingeschaltet werden. Die Ursache ist weiterhin nicht belegt.
- Statische Analyse dazu: Ein geroutetes Key-Code-Mapping ueberlebte ein ausgebliebenes Key-Up, wodurch jeder spaetere Druck derselben Taste weiterhin die Hyper-Modifier trug, bis `resetHyperKeyState` lief — genau das loest das Aus-/Einschalten von Hyperkey aus. Der Zustandsautomat verwirft ein solches veraltetes Routing jetzt beim naechsten frischen Tastendruck. Ob das der beobachtete Fall war, ist offen und am Zielgeraet zu pruefen.
- S-07 ist noch nicht bestanden: Display-Gruppierung, Separate-Spaces-Modi, Ueberlauf, Create/Delete/Reorder, VoiceOver und die reale Klickgeometrie in der System-Menueleiste bleiben manuell zu pruefen.
- Konkreter S-07-Pruefpunkt: Findet sich fuer das Cursor-Display kein Eintrag in `Spaces.screenSpacesMap`, zeigt die Leiste still das erste bekannte Display, waehrend der Klick weiterhin auf das Cursor-Display zielt. Anzeige und Wirkung koennen dadurch auseinanderlaufen; das Verhalten ist am Zielgeraet zu pruefen, bevor die Display-Gruppierung gebaut wird.

Mehrere Displays:

- Standard ist `macOS folgen`, kein eigener globaler Umschaltmodus.
- Bei aktivem `Displays haben separate Spaces` werden Spaces nach Display gruppiert. Ein Klick wechselt nur das Display der angeklickten Gruppe.
- Bei deaktiviertem `Displays haben separate Spaces` wird eine gemeinsame Reihe gezeigt; ein Wechsel betrifft gemaess macOS-Semantik den gesamten Displayverbund.
- Da macOS dieselbe Statusleiste auf mehreren Displays spiegeln kann, zeigt der MVP in einem Status-Item kompakte Display-Gruppen statt pro Menueleistenkopie unterschiedlichen Inhalt zu versprechen. Die Darstellung pro physischem Display ist ein separater Machbarkeitscheck.

Optionale Namen:

- Space-Aliase sind AltTab+-Metadaten; macOS selbst erhaelt dadurch keine benannten Spaces.
- Aliase werden nur persistiert, wenn eine auf Tahoe verifizierte stabile Managed-Space-UUID verfuegbar ist.
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

### 3. Modifier-basierter Window Move/Resize

Status: Revidierter MVP-Kandidat
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
| S-08 | Stabile Space-Identitaet | Managed-Space-UUID bleibt auf Tahoe ueber Neustart, Reorder sowie Hinzufuegen/Loeschen eindeutig genug fuer Aliase; andernfalls bleiben persistente Namen und Profile-Bindings deaktiviert |

## Umsetzungsreihenfolge

1. Abgeschlossen: fokussierter AX-Fensterpfad, Window Layouts und Hyper sind umgesetzt; Dokumentation und automatisierte Tests sind aktualisiert, der aktuelle Funktionsstand wurde manuell abgenommen. Formale App-/Display-Matrizen bleiben wiederkehrende Release-Gates.
2. Plattform-Gates vor privaten oder kontinuierlichen Modulen schliessen: Tahoe-Tiling-Matrix S-04, degradierbare Symbolbindung V-03 und Provenienz-Register V-04.
3. Minimalen gemeinsamen Aktionskern gemaess Q-01 aufbauen: Die erste Ausbaustufe fuer Window Layouts, Restore und globale Shortcuts ist umgesetzt; Display-, Space-, App-, URL- und Menueleisten-Verbraucher folgen. Keine beliebigen Makros oder Shell-Kommandos.
4. Instant-Spaces-Kern ist als tap-freie Private-Event-Reimplementierung ueber das Aktionsregister umgesetzt; S-06/V-12 bleiben als manuelle Tahoe-Pruefung offen, Swipe-Override bleibt Folgeumfang.
5. Teilweise abgeschlossen: Spaces-Menueleiste mit Nummern, monochrom aktivem Zustand, Klick und Shortcut-Fallback ist umgesetzt. S-07 bleibt fuer Mehrdisplay, Ueberlauf, Create/Delete/Reorder, VoiceOver und Degradation offen.
6. Stabile Space-Identitaet S-08 pruefen; Aliase und persistente Profil-Bindings erst nach bestandenem Spike aktivieren.
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
| V-05 | Modul- und App-Klassen-Checklisten | `docs/input-safety-checklist.md` und `docs/window-layout-checklist.md` vor jeder oeffentlichen Version und nach jedem unterstuetzten macOS-Major-Update ausfuehren |
| V-06 | Energie-Baseline | Idle- und Aktivmessungen auf dem Tahoe-/Apple-Silicon-Zielgeraet dokumentieren |
| V-07 | Distribution | Signing, Notarisierung, Vertriebskanal und Update-Strategie vor erster oeffentlicher Version abschliessen; Sparkle bleibt optional |
| V-08 | Safe Start und Circuit Breaker | Vor dem ersten ausgelieferten Input-Modul mit Login-Start, verbliebenem Arming-Marker und wiederholtem Tap-Timeout pruefen |
| V-09 | Berechtigungsentzug | Accessibility und Input Monitoring getrennt bei Start, Aktivierung, Wake und Laufzeit pruefen |
| V-10 | Pointer State Ownership | Aenderung durch Systemeinstellungen oder paralleles Maus-Tool, persistiertes `relinquished`, erneute Besitzuebernahme, Disable, saubere Terminierung, Crash, `SIGKILL`, Wake und Device-Reconnect ohne Rueckschreibschleife oder destruktives Restore pruefen |
| V-11 | Display-Topologien | Snapping-Checkliste ueber definierte Topologien, Separate-Spaces-Zustaende und dynamische Reconfiguration ausfuehren |
| V-12 | Instant Spaces | Tahoe-Build, Separate Spaces ein/aus, Cursor-Display, Fullscreen-Space, Stage Manager, Mission Control/App Expose, Randwechsel und schnelle direkte Mehrfachwechsel pruefen |
| V-13 | `Command+Control`-Move | `NSWindowShouldDragOnGesture` vor Aktivierung lesen, auf `false` setzen und verifizieren; Disable, externe Aenderung, Crash und Recovery ohne destruktives Restore pruefen |
| V-14 | Spaces-Menueleiste | Ein bis 16 Spaces, mehrere Displays, Fullscreen-Spaces, Reorder, Create/Delete, Wake, Mission-Control-Ende, Statusleisten-Ueberlauf und VoiceOver pruefen |
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
