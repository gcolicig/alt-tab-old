# Roadmap: AltTab+

AltTab+ entwickelt sich als eigenstaendige, integrierte App zu einem offenen macOS UX Enhancer. Zielplattform ist macOS Tahoe auf Apple Silicon. Die Features werden nicht fuer Upstream entwickelt.

Der vollstaendige Scope und alle technischen Leitplanken stehen in `backlog.md`.

## Phase 0A: Release- und Plattformbasis

- Tahoe-Tiling-Matrix am Zielgeraet verifizieren.
- Private Symbole degradierbar binden.
- Signing, Notarisierung, Update-Feed und Vertrieb vor einer oeffentlichen Version klaeren.

Lokales Codesigning ist eingerichtet. Notarisierung, ein eigener Update-Feed und der Vertrieb bleiben offen; Sparkle ist bis dahin optional und deaktiviert.

## Phase 0B: AX- und Input-Basis

- Der fokussierte AX-Fensterpfad, settable-Filter und sichtbare Display-Geometrie sind fuer einmalige Tastaturaktionen umgesetzt.
- Cursor-basierte Fenstererkennung, erweiterte Diagnose und App-Klassen-Pruefraster vor Move/Resize vervollstaendigen.
- Safe Start, Panic-Kill-Switch, Berechtigungsentzug und Event-Tap-Circuit-Breaker vor dem ersten tap-basierten Input-Modul fertigstellen.

## Phase 1: Window Layouts

- Umgesetzt: Thirds, Two-Thirds und sessionbasiertes Restore fuer das fokussierte Fenster.
- Umgesetzt: eigene Settings, globale Shortcut-Registrierung und Kollisionspruefung; keine Default-Shortcuts.
- Offen nach der Tahoe-Matrix: Center, Display-Wechsel und ein optionaler Preset-Picker.
- Halves und Quarters nur bei nachgewiesener Luecke gegenueber Tahoe.

## Phase 1B: Gemeinsamer Aktionskern

- Ein typisiertes Aktionsregister fuer Window Layouts, Restore, Display-Wechsel, Apps und URLs aufbauen.
- Leader-Sequenzen, FlickRing-Sektoren und spaetere Pointer-Module verwenden dasselbe Register.
- Keine beliebigen Makros oder Shell-Kommandos im ersten Umfang.

## Phase 2A: Sichere Input-Laufzeit

- Safe Start, Kill-Switch, enge Berechtigungsfuehrung und Circuit Breaker verifizieren.
- Abgefangene Key-down-/Key-up-Paare, Zustandsbereinigung bei Sleep/Wake und fail-closed Degradation zentralisieren.
- AX-Coalescing und Diagnose fuer kontinuierliche Fensteroperationen fertigstellen.

## Phase 2B: Hyper und Leader

- Dual-Role-Hyper umgesetzt: Caps Lock kurz tippen schaltet Caps Lock, Halten plus Taste erzeugt systemweit `Command+Control+Option+Shift`.
- Hyper wird dem vollstaendigen Key-down-/Key-up-Paar hinzugefuegt; es werden keine eigenstaendig gehaltenen Modifier-Events erzeugt.
- Die vier Pfeiltasten koennen stattdessen direkt vorhandene Window-Layout-Aktionen ausloesen.
- Offen: eigener Leader-Trigger, verschachtelte Sequenzen, Escape, Timeout und kompakte AppKit-Uebersicht.
- Modul startet deaktiviert; Caps Lock bleibt in macOS normal auf `Caps Lock` abgebildet.

## Phase 2C: FlickRing

- Konfigurierbare zusaetzliche Maustaste aktiviert einen Ring mit Totbereich und vier Richtungen.
- Beim Loslassen wird genau eine Aktion aus dem gemeinsamen Aktionsregister ausgefuehrt.
- MVP mit reservierter Seitentaste; transparentes Wiedergeben eines normalen Mittelklicks erst nach Event-Tagging- und Rekursionstest.

## Phase 2D: Move und Resize

- Fenster unter dem Cursor per Modifier bewegen und skalieren.
- Kein Default-Modifier; Modul startet deaktiviert.
- Drag-Sitzung bestimmt das Fenster einmal und schreibt nur den neuesten Zielrahmen ueber eine serielle AX-Queue.
- Zuerst Move, danach Resize, danach erweiterte Fenster-Fallbacks.
- Fluessigkeit und Degradation ueber die definierte App-Klassen-Matrix pruefen.

## Phase 3: Pointer

- Pointer Acceleration und Speed fuer Maus und Trackpad per IOKit-Spike.
- Persistiertes State Ownership mit `unmanaged`, `managed` und `relinquished`.
- Kein Release ohne konfliktfreies Restore sowie Crash-/Kill-Recovery.

## Phase 4: Snapping

- Nur Luecken schliessen, die Tahoe nicht nativ abdeckt.
- Drag-Overlay fuer Thirds, Two-Thirds und weitere bestaetigte Ziele.
- Display-Topologien, Separate Spaces und dynamische Display-Wechsel pruefen.

## Phase 5: Scroll

- Reverse Scrolling und Scroll Speed mit engem `scrollWheel`-Tap.
- Nur nach bestandener Tap-, Berechtigungs- und Energiepruefung.
- Keine App- oder geraetespezifischen Regeln im MVP.

## Phase 6: Gesten

- Drei-Finger-Middle-Click als letzter Spike.
- Private Multitouch-API strikt nach macOS-Version gaten.
- Default-Aktivierung erst mit Helper-Prozess; unbekannte Version deaktiviert das Modul.

## Release-Gates

Vor jeder oeffentlichen Version:

- Modul-Checklisten und relevante App-/Display-Matrizen bestanden.
- Keine neuen Module durch Import oder Migration automatisch aktiviert.
- Idle- und Aktiv-Energieverbrauch gegen die dokumentierte Baseline geprueft.
- Private-API-, Berechtigungs- und Safe-Start-Degradation getestet.
- Provenienz-Register fuer verwendete OSS-Quellen aktualisiert.

## Nicht-Ziele

- Intel-Macs und macOS-Versionen vor Tahoe.
- BetterTouchTool-Kompatibilitaet, beliebige Makros oder ein allgemeiner Launcher.
- Eigenstaendig gehaltene oder frei kombinierbare synthetische Modifier-Zustaende.
- Vollstaendiger Ersatz fuer LinearMouse.
- Ueberschreiben nativer Tahoe-Snap-Zonen.
- Upstream-PRs fuer die UX-Module.
