# Roadmap: AltTab+

AltTab+ entwickelt sich als eigenstaendige, integrierte App zu einem offenen macOS UX Enhancer. Zielplattform ist macOS Tahoe auf Apple Silicon. Die Features werden nicht fuer Upstream entwickelt.

Der vollstaendige Scope und alle technischen Leitplanken stehen in `backlog.md`.

## Guide: macOS Spaces

- Neue Spaces nativ in Mission Control anlegen: `Control+Pfeil hoch`, Mission-Control-Taste (`F3`) oder konfigurierte Trackpad-Geste, danach `+` in der Spaces-Leiste.
- Nativ wechseln: horizontaler Drei-/Vier-Finger-Wisch, Zwei-Finger-Wisch auf der Magic Mouse oder `Control+Pfeil links/rechts`.
- Direkte `Control+Zahl`-Spruenge nur als konfigurierbare Mission-Control-Shortcuts dokumentieren, nicht als garantierte `1-0`-Belegung.
- Fenster nativ per kurzem Halten am Bildschirmrand in den Nachbar-Space oder in Mission Control auf einen beliebigen Space ziehen.
- Mehrdisplay-Verhalten folgt `Displays haben separate Spaces`: getrennte Space-Mengen bei aktivierter, gemeinsamer Wechsel bei deaktivierter Option.

## Phase 0A: Aktuellen Stand konsolidieren

- Umgesetzt: fokussierter AX-Fensterpfad, settable-Filter und sichtbare Display-Geometrie fuer einmalige Tastaturaktionen.
- Umgesetzt: Window Layouts mit Thirds, Two-Thirds, Three-Quarters, Focus-Layouts und Ein-Schritt-Restore.
- Umgesetzt: eigene Layout-Settings, globale Shortcut-Registrierung und Kollisionspruefung; keine Default-Shortcuts.
- Umgesetzt: Presets weisen ein benanntes Set per Klick zu und wieder ab, fuer Spaces und Layouts je in einer macOS-nahen und einer Hyper-Variante.
- Umgesetzt: Dual-Role-Hyper samt Safe Start, Arming-Marker, festem Kill-Switch und Circuit Breaker.
- Automatisierte Tests und die manuelle Nutzerabnahme des aktuellen Stands sind abgeschlossen. Die formalen App-/Display-Matrizen bleiben Release-Gates und werden nach relevanten Aenderungen erneut ausgefuehrt.

## Phase 0B: Plattform- und Release-Gates

- Tahoe-Tiling-Matrix am Zielgeraet gemaess `docs/tahoe-tiling-checklist.md` verifizieren.
- Umgesetzt fuer `_AXUIElementGetWindow`: optionale Laufzeitbindung degradiert einen Symbolwegfall zum Ausfall der jeweiligen AX-Fenster-ID-Abfrage.
- Weitere private Symbole jeweils vor Nutzung durch ein neues Modul degradierbar binden und unbekannte macOS-Major-Versionen fail-closed behandeln.
- Umgesetzt: Provenienz-Register `THIRD-PARTY.md` fuer die bisher ausgewerteten OSS-Quellen.
- Signing, Notarisierung, Update-Feed und Vertrieb vor einer oeffentlichen Version klaeren.

Lokales Codesigning ist eingerichtet. Notarisierung, ein eigener Update-Feed und der Vertrieb bleiben offen; Sparkle ist bis dahin optional und deaktiviert.

## Phase 1: Minimaler gemeinsamer Aktionskern

- Umgesetzt fuer Window Layouts und Restore: typisierte stabile Action-IDs, zentraler Dispatch sowie Verfuegbarkeit mit Fehlergrund.
- Umgesetzt: globale Window-Layout-Shortcuts verwenden das gemeinsame Register.
- Umgesetzt: Space links/rechts, `Last Space` und Space 1 bis 9 sind als typisierte Aktionen registriert.
- Umgesetzt: `Move to next display` und `Move to previous display` sind als typisierte Aktionen registriert; sie behalten die relative Lage des Fensters und begrenzen es auf den Zielbildschirm.
- Umgesetzt: Register um Apps und URLs erweitert; 9 App- und 9 URL-Slots mit je eigenem globalem Shortcut, konfigurierbar im Settings-Tab `Apps & URLs`.
- Spaces-Menueleiste, Leader-Sequenzen, FlickRing-Sektoren und spaetere Module verwenden danach dasselbe Register.
- Die Menueleiste enthaelt keine eigene Fenster- oder Space-Aktionslogik.
- Keine beliebigen Makros oder Shell-Kommandos im ersten Umfang.

## Phase 2A: Instant Spaces

- Umgesetzt: Space links/rechts, direkter Wechsel zu Space 1 bis 9 und `Last Space` ueber das gemeinsame Aktionsregister.
- Verworfen: direkter Sprung ueber `CGSManagedDisplaySetCurrentSpace`. Der Aufruf entkoppelt Dock und WindowServer; Fenster des Ziel-Space werden ueber den sichtbaren gelegt und auch die native Auswahl in Mission Control bleibt defekt, bis der Dock neu startet. Das Symbol wird bewusst nicht gebunden.
- Umgesetzt: schrittweises Schalten mit Abgleich gegen den Ist-Space zwischen den Schritten; ein verschluckter Swipe verschiebt keine Folgeaktion mehr.
- Umgesetzt: tap-freier Kern durch synthetische Dock-Swipe-Sequenzen, ohne permanenten Event-Tap und ohne Default-Shortcuts.
- Umgesetzt: benoetigte private Symbole werden optional gebunden; unbekannte macOS-Major-Versionen und fehlende Symbole deaktivieren die Aktionen.
- Umgesetzt: Zielwahl ueber das Cursor-Display, Randbegrenzung, kurzfristige Folgewechsel-Vorhersage und Resynchronisation bei tatsaechlichem Space-Wechsel.
- Offen: Event-Feldnummern, Wechselwirkung mit Mission Control/App Expose und S-06-Verhalten auf dem Tahoe-Zielgeraet manuell verifizieren.
- Umgesetzt: eigene Spaces-Settings mit globalen Shortcuts fuer links, rechts und Space 1 bis 9 sowie die sichtbare Spaces-Menueleiste aus Phase 2B.
- Das Abfangen nativer Trackpad-Swipes bleibt spaeterer Folgeumfang neben dem Gestenmodul.

## Phase 2B: Spaces-Menueleiste und Identitaet

- Umgesetzt: optionale nummerierte Space-Segmente rechts neben dem AltTab+-Symbol, deaktiviert per Default.
- Umgesetzt: aktiven Space monochrom mit schwarzer Umrandung im Light Mode und weisser Umrandung im Dark Mode markieren; Klick verwendet dieselbe direkte `Space n`-Aktion aus dem Aktionsregister.
- Umgesetzt: ereignisbasierte Aktualisierung bei Space-, Display- und Wake-Ereignissen ohne Polling.
- Der erste Schnitt zeigt bis zu neun Spaces fuer das Display unter dem Cursor und deaktiviert Klicks bei nicht verfuegbarem Instant-Spaces-Kern.
- Umgesetzt: konfigurierbare Shortcut-Fallbacks fuer links, rechts und Space 1 bis 9.
- Offen: gruppierte Display-Reihen gemaess `Displays haben separate Spaces` und Ueberlauf fuer mehr als neun Spaces.
- Beobachtung aus der manuellen Abnahme: Zum Aufzeichnen eines Space-Shortcuts musste Hyperkey einmal aus- und wieder eingeschaltet werden. Der Befund ist dokumentiert; es wurde bewusst keine Aenderung vorgenommen.
- Stabile Managed-Space-Identitaet getrennt verifizieren; optionale Aliase erst danach persistieren.

## Phase 3A: Cursor-basierter AX-Fensterkern

- Fenster unter dem Cursor zu Beginn einer Operation eindeutig bestimmen.
- AX-Schreibvorgaenge coalescen und ueber eine serielle Queue ausfuehren.
- Diagnose und App-Klassen-Pruefraster vor kontinuierlichen Move-/Resize-Operationen vervollstaendigen.

## Phase 3B: Move und Modifier-Snapping

- Fenster unter dem Cursor per Modifier bewegen; kein Default-Modifier und Modul startet deaktiviert.
- Modifier-Move und Snapping bilden eine gemeinsame Drag-Sitzung und bestimmen das Fenster genau einmal.
- Der eigene Modifier-Drag bietet `Left half`, `Right half` und `Fill`; normale Titelbalken-Drags und native Tahoe-Snap-Zonen bleiben unberuehrt.
- `Command+Control` ist explizit waehlbar, konfliktbehaftet und nie Default. Vor Aktivierung muss `NSWindowShouldDragOnGesture` verifiziert auf `false` stehen; AltTab+ verwaltet den globalen Vorwert konfliktfrei.
- Safe Start, Kill-Switch, Berechtigungsentzug und Circuit Breaker fuer diesen Modulpfad erweitern und verifizieren.

## Phase 3C: Resize

- Resize auf derselben Cursor-Erkennung, AX-Queue und sicheren Input-Laufzeit aufbauen.
- Fluessigkeit und Degradation ueber die definierte App-Klassen-Matrix pruefen.
- Erweiterte Fenster-Fallbacks erst nach stabilem Move und Resize.

## Paralleler Spike: Pointer

- Pointer Acceleration und Speed fuer Maus und Trackpad per IOKit-Spike.
- Persistiertes State Ownership mit `unmanaged`, `managed` und `relinquished`.
- Kein Release ohne konfliktfreies Restore sowie Crash-/Kill-Recovery.
- Der Spike darf nach Phase 0 parallel zu Aktionskern, Spaces und Fensteroperationen laufen.

## Phase 4: Leader und FlickRing

- Dual-Role-Hyper bleibt umgesetzt und deaktiviert per Default; Caps Lock kurz tippen schaltet weiterhin Caps Lock.
- Leader erhaelt einen eigenen Trigger, verschachtelte Sequenzen, Escape, Timeout und eine kompakte AppKit-Uebersicht.
- FlickRing verwendet eine konfigurierbare zusaetzliche Maustaste, Totbereich und vier Richtungen.
- Beide Module fuehren ausschliesslich Aktionen aus dem gemeinsamen Register aus.
- Die sichere Input-Laufzeit jeweils nur um den konkret benoetigten Modulpfad erweitern.

## Phase 5: Weiteres Snapping

- Ausserhalb des eigenen Modifier-Drags nur Luecken schliessen, die Tahoe nicht nativ abdeckt.
- Drag-Overlay fuer Thirds, Two-Thirds und weitere bestaetigte Ziele.
- Display-Topologien, Separate Spaces und dynamische Display-Wechsel pruefen.
- Padding, Bewegungsanimation und konfigurierbare Snap-Zonenstaerke bleiben Folgeumfang nach festen, getesteten MVP-Werten.

## Phase 6: Projektprofile und Session Restore

- Stabile Profile mit Name, Apps, optionalem Layout, Space-Binding und konfliktgeprueftem Shortcut einfuehren.
- Profilname kann in der Spaces-Menueleiste statt der Nummer erscheinen; verlorene Space-Bindings werden sichtbar und nicht automatisch umgebogen.
- Zuerst explizite Profilaktivierung und App-Filterung, danach Opt-in-Aktionen zum Starten oder Zuordnen von Apps.
- Session-/Layout-Restore erst nach robustem Fenster-Matching sowie App- und Display-Matrix; keine automatische Wiederherstellung im ersten Schritt.

## Phase 7: Scroll

- Reverse Scrolling und Scroll Speed mit engem `scrollWheel`-Tap.
- Nur nach bestandener Tap-, Berechtigungs- und Energiepruefung.
- Keine App- oder geraetespezifischen Regeln im MVP.

## Phase 8: Gesten

- Drei-Finger-Middle-Click als letzter Spike.
- Private Multitouch-API strikt nach macOS-Version gaten.
- Default-Aktivierung erst mit Helper-Prozess; unbekannte Version deaktiviert das Modul.

## Release-Gates

Vor jeder oeffentlichen Version:

- Modul-Checklisten und relevante App-/Display-Matrizen bestanden.
- Keine neuen Module durch Import oder Migration automatisch aktiviert.
- Default-Settings, Reset-Verhalten und Migration fuer jedes neue Modul geprueft; zusaetzlicher Gesamtaudit vor einer oeffentlichen Version.
- Idle- und Aktiv-Energieverbrauch gegen die dokumentierte Baseline geprueft.
- Private-API-, Berechtigungs- und Safe-Start-Degradation getestet.
- Provenienz-Register fuer verwendete OSS-Quellen aktualisiert.

## Nicht-Ziele

- Intel-Macs und macOS-Versionen vor Tahoe.
- BetterTouchTool-Kompatibilitaet, beliebige Makros oder ein allgemeiner Launcher.
- Eigenstaendig gehaltene oder frei kombinierbare synthetische Modifier-Zustaende.
- Vollstaendiger Ersatz fuer LinearMouse.
- Ueberschreiben nativer Tahoe-Snap-Zonen ausserhalb des expliziten AltTab+-Modifier-Drags.
- Upstream-PRs fuer die UX-Module.
