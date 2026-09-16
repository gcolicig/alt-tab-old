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

## Phase 1C: Thumbnail-Drop

- Thumbnails nehmen waehrend einer laufenden Drag-Sitzung Datei- und Web-URLs entgegen.
- Spring-Loading fokussiert das Zielfenster und laesst den Drag weiterlaufen; ein Drop uebergibt die Nutzlast an die App des Zielfensters.
- Reine AppKit-Dragging-Destination-Logik: kein Event-Tap, kein Event-Posting, keine zusaetzliche Berechtigung; damit unabhaengig von der Input-Laufzeit einplanbar.
- Zustellung an ein bestimmtes Fenster ist nicht Teil des Scopes; Fenstergenauigkeit entsteht ueber Spring-Loading.

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
- Umgesetzt: gruppierte Display-Reihen gemaess `Displays haben separate Spaces` (Befund 2026-08-05: macOS liefert auch bei deaktivierter Option eine Gruppe je Display; Ein-Space-Gruppen sollen dann ausgeblendet werden, noch offen) und Ueberlauf-Menue ab dem neunten Space pro Display.
- Klicks auf eine Nicht-Cursor-Display-Gruppe werden bei einer einzigen, nicht gespiegelten Menueleiste ignoriert statt das falsche Display zu schalten: Instant Spaces postet synthetische Trackpad-Gesten ohne Zieldisplay-Feld und kann nur das Display unter dem Cursor schalten. Bei gespiegelter Menueleiste (macOS-Einstellung) trifft der Klick immer das richtige Display, da der Cursor beim Klick bereits dort sitzt.
- Beobachtung aus der manuellen Abnahme: Zum Aufzeichnen eines Space-Shortcuts musste Hyperkey einmal aus- und wieder eingeschaltet werden. Der Befund ist dokumentiert; es wurde bewusst keine Aenderung vorgenommen.
- Umgesetzt: Stabile Managed-Space-Identitaet ist verifiziert (S-08, 2026-08-03). UUIDs ueberleben Neustart, Reorder, Create und Delete; `id64` wechselt dabei. Aliase duerfen auf der UUID aufbauen, ein Space ohne UUID bleibt unbenennbar und wird sichtbar so markiert.

## Paralleler Umfang: Shortcut Clues

- Umgesetzt 2026-08-05: Trigger, Menueleser, Overlay und Settings. Die Modifier-Kodierung wurde vor der Darstellung am Zielgeraet gemessen; manuelle Abnahme steht aus.
- Overlay mit den Tastenkuerzeln der aktiven App, solange ein Trigger gehalten wird; liest fremde
  Shortcuts statt eigene auszufuehren und haengt daher nicht am Aktionsregister.
- Datenquelle ist ausschliesslich die Menueleiste ueber die oeffentliche Accessibility API; keine
  private API und kein dauerhafter Event-Tap.
- Setzt die AX-Disziplin aus Phase 3A voraus und wird deshalb nicht davor begonnen.
- Vollstaendige Spezifikation in `spec-shortcut-clues.md`.

## Phase 3A: Cursor-basierter AX-Fensterkern

- Umgesetzt: Fenster unter dem Cursor wird zu Beginn einer Operation ueber die Element-at-position-Kette bestimmt; bei Mehrdeutigkeit erfolgt keine Aktion.
- Umgesetzt: Coalescing der AX-Schreibvorgaenge und der Diagnose-Ringpuffer als reine, getestete Logik.
- Angebunden: die Drag-Sitzung aus Phase 3B ruft den Kern auf und ist am Zielgeraet bedient.
- Offen: S-01 und S-02 am Zielgeraet sowie das App-Klassen-Pruefraster.

## Phase 3B: Move und Modifier-Snapping

- Umgesetzt: Drag-Sitzung, Event-Tap mit Not-Aus und Circuit Breaker, Snapping auf `Left half`, `Right half` und `Fill` sowie das Zielrahmen-Overlay. Am Zielgeraet bedient und bestaetigt.
- Umgesetzt: `Command+Control` samt Besitzmodell fuer `NSWindowShouldDragOnGesture`.
- Offen: V-13, die App-Klassen- und die Display-Matrizen am Zielgeraet.
- Modifier-Move und Snapping bilden eine gemeinsame Drag-Sitzung und bestimmen das Fenster genau einmal.
- Der eigene Modifier-Drag bietet `Left half`, `Right half` und `Fill`; normale Titelbalken-Drags und native Tahoe-Snap-Zonen bleiben unberuehrt.
- `Command+Control` ist explizit waehlbar, konfliktbehaftet und nie Default. Vor Aktivierung muss `NSWindowShouldDragOnGesture` verifiziert auf `false` stehen; AltTab+ verwaltet den globalen Vorwert konfliktfrei.
- Safe Start, Kill-Switch, Berechtigungsentzug und Circuit Breaker fuer diesen Modulpfad erweitern und verifizieren.

## Phase 3C: Resize

- Umgesetzt: Resize auf derselben Cursor-Erkennung, AX-Queue und sicheren Input-Laufzeit; eigener Modifier, per Default aus, Ankerecke aus dem Startquadranten.
- Fluessigkeit und Degradation ueber die definierte App-Klassen-Matrix pruefen.
- Erweiterte Fenster-Fallbacks erst nach stabilem Move und Resize.

## Paralleler Spike: Pointer

- Umgesetzt: Pointer Acceleration und Speed fuer Maus und Trackpad ueber IOKit (`IOHIDGetAccelerationWithKey` / `IOHIDSetAccelerationWithKey`). Der Weg ueber `NSGlobalDomain` wurde am 2026-08-07 widerlegt: die Praeferenz liess sich setzen, der effektive Wert blieb unveraendert. Siehe Story 4 im Backlog.
- Offen: V-10 am Zielgeraet; der schreibende Pfad ist bisher nur durch Entscheidungslogik abgedeckt, nicht ausgefuehrt.
- Persistiertes State Ownership mit `unmanaged`, `managed` und `relinquished`.
- Kein Release ohne konfliktfreies Restore sowie Crash-/Kill-Recovery.
- Der Spike darf nach Phase 0 parallel zu Aktionskern, Spaces und Fensteroperationen laufen.

## Phase 4: Leader und FlickRing

- Dual-Role-Hyper bleibt umgesetzt und deaktiviert per Default; Caps Lock kurz tippen schaltet weiterhin Caps Lock.
- Umgesetzt: Leader hat einen eigenen konfigurierbaren Trigger, verschachtelte Sequenzen, Escape, Timeout und eine kompakte AppKit-Uebersicht. Er reitet auf dem bestehenden Keyboard-Tap, ohne zweiten Tap oder eigenen Arming-Marker; der Settings-Tab pflegt acht Sequenz-Slots mit Konfliktwarnung.
- Umgesetzt: FlickRing nutzt eine konfigurierbare Maustaste (Default Seitentaste), einen 5pt-Totbereich und vier Richtungen mit Ring-Overlay; der Tap existiert nur bei aktivem Modul.
- Umgesetzt: beide Module fuehren ausschliesslich Aktionen aus dem gemeinsamen Register aus, gebunden ueber die stabile Action-ID.
- Umgesetzt: die sichere Input-Laufzeit ist nur um den benoetigten Pfad erweitert — Leader haengt an Not-Aus, Safe Mode und Sleep/Wake des Keyboard-Taps; FlickRing bringt einen eigenen Circuit Breaker mit und wird vom Not-Aus geschlossen.
- Offen: die manuelle Abnahme beider Module am Tahoe-Zielgeraet gemaess `docs/leader-flickring-checklist.md`.

## Phase 5: Weiteres Snapping

- Umgesetzt: der eigene Modifier-Drag bietet neben Left/Right half und Fill jetzt vier Eck-Viertel und Kanten-Tiefenbaender (Haelfte am Rand, dann Drittel, dann Zwei-Drittel). Die Thirds teilen die Rechteck-Geometrie mit den Tastatur-Window-Layouts, sodass Drag und Shortcut auf demselben Rahmen landen. Reine Zonenlogik in `DragSnapPolicy`, unit-getestet; das bestehende Overlay zeichnet die neuen Ziele ueber denselben Rahmenpfad. Neighbour-/Dwell-Gating gilt fuer alle neuen Ziele.
- Offen und bewusst zurueckgestellt: Luecken ausserhalb des eigenen Modifier-Drags. Der Scope dafuer haengt an der Tahoe-Feature-Matrix (offenes Geraete-Gate); ohne sie wuerde geraten, was Tahoe nativ abdeckt.
- Offen: Display-Topologien, Separate Spaces und dynamische Display-Wechsel am Zielgeraet pruefen (`docs/window-drag-checklist.md`).
- Padding, Bewegungsanimation und konfigurierbare Snap-Zonenstaerke bleiben Folgeumfang nach festen, getesteten MVP-Werten.

## Phase 6: Projektprofile und Session Restore

- Umgesetzt (Fundament): stabile Managed-Space-Identitaet im Code (`Spaces.uuidsById`, `currentSpaceUuid`, `identitySnapshot()`), reiner `SpaceIdentity`-Resolver. Eine UUID ohne aktuellen Space loest zu nil auf.
- Umgesetzt (Stufe 1): fuenf Profil-Slots mit Name, Apps (Bundle-IDs), optionalem Layout, optionalem Space-Binding (per stabiler UUID) und eigenem konfliktgepruefter Shortcut (als globale Aktion im Register). Aktivierung wechselt auf den gebundenen Space, sofern das Binding noch aufloest, und **filtert** den Switcher auf die Profil-Apps; erneutes Ausloesen schaltet das Profil wieder ab. Ein verlorenes Binding wird gemeldet und nie umgebogen. Keine App wird gestartet, beendet, versteckt oder verschoben. Reines Modell + Planer + Space-Identitaet sind unit-getestet.
- Zurueckgestellt: der Profilname in der Spaces-Menueleiste (statt der Nummer) — Menueleisten-Integration, spaeter.
- Zurueckgestellt: das Profil-Layout wird gespeichert, aber bei Aktivierung noch nicht angewendet (unerwartete Fenstermutation vermeiden); Anwendung wird eine eigene Aktion.
- Offen (Geraete-Gate): Session-/Layout-Restore erst nach robustem Fenster-Matching sowie App- und Display-Matrix; keine automatische Wiederherstellung im ersten Schritt. Manuelle Abnahme von Stufe 1 am Zielgeraet: `docs/profiles-checklist.md`.

## Phase 7: Scroll

- **Vorgezogen am 2026-08-13, in der Roadmap nachgetragen am 2026-09-10.** Die getrennte Scrollrichtung ist die einzige LinearMouse-Funktion, die im taeglichen Gebrauch fehlt. Sie lief damit parallel zu den Phasen 4 bis 6 und wartete nicht auf sie.
- Umgesetzt (MVP 2026-08-18, beim Zusammenfuehren der beiden Arbeitsstaende am 2026-09-16 auf eine Implementierung vereinheitlicht): getrenntes Reverse-Scrolling und Scroll-Speed fuer Maus und Trackpad ueber den bestehenden `scrollWheel`-Tap. Der Tap laeuft nur, wenn der Switcher blockieren will oder eine Scroll-Einstellung aktiv ist; das Blockieren kontinuierlichen Scrollens bleibt strikt auf den aktiven Switcher beschraenkt, damit Trackpad-Scrollen ausserhalb nie blockiert wird. Kategorie ueber `kCGScrollWheelEventIsContinuous` (kontinuierlich = Trackpad/Magic Mouse, diskret = Rasterrad). Die reine `ScrollTransform`-Logik ist unit-getestet; sie schreibt Linien-, Pixel- und Fixed-Point-Deltas konsistent um. Safe Mode schaltet die Modifikation ab, ohne die Einstellung zu loeschen.
- Reverse betrifft im MVP nur die vertikale Achse; Speed skaliert beide. Keine App- oder geraetespezifischen Regeln, kein Smoothing, keine eigenen Kurven.
- Offen (Geraete-Gate): Tap-, Berechtigungs- und Energiepruefung am Zielgeraet (`docs/scroll-direction-checklist.md`), inkl. Momentum-/Phase-Verhalten. Die Energie- und Latenzmessung fuer den dauerhaft aktiven Tap ist V-17 und noch offen.

- Folgestufe Smoothed Scrolling (Story 6c): Engine aus LinearMouse uebernehmen, Anbindung an den bestehenden Tap neu bauen. Erst Mausrad vertikal mit festem Preset und ohne Gesten-Begleiter, dann Messung (V-18), dann Presets und Regler. Beginnt erst nach bestandenem V-17.

## Phase 8: Gesten

- Drei-Finger-Middle-Click als letzter Spike.
- Private Multitouch-API strikt nach macOS-Version gaten.
- Default-Aktivierung erst mit Helper-Prozess; unbekannte Version deaktiviert das Modul.

## Phase 10: Keep Awake (Sleep Override)

- MVP umgesetzt 2026-09-16 (ohne Disk-Assertion); Ausbaustufe offen.

- Eigenstaendiges Modul, per Default aus: Caffeine als Minimal-Referenz (Menubar-Toggle), Amphetamine als Funktionsreferenz (Sessions, Trigger, Energie-Policies). Kein Event-Tap und keine private API — nur oeffentliche `IOPMAssertion` plus System-Observer; damit ausserhalb der Q-01..Q-16-Input-Sicherung.
- MVP: Menubar-Toggle, Sessions (unbegrenzt / feste Dauer / bis Uhrzeit / verlaengern), System- vs. Display-wach, Restlaufzeit, globale Shortcuts ueber das Aktionsregister, Batterie-Auto-Ende, striktes Fail-safe gegen Assertion-Leak.
- Ausbaustufe: Trigger (App laeuft, Stromversorgung, Batterie-Schwelle, Volume gemountet, externe Anzeige), Notifications, Auto-Start, Trennung manuell/triggerbasiert mit Prioritaetsregeln.
- Spaeter: WLAN/SSID (Standort-Berechtigung), USB/Bluetooth, Idle, CPU, Netzwerkumgebung, Automation.
- Bewusst nicht: Download-Trigger (kein verlaesslicher oeffentlicher Pfad), Maus-Jiggle (Assertions machen es ueberfluessig), Umgehung der Sperr-Policy.
- Vollstaendige Spezifikation und die editierbare Feature-Checkliste in `backlog.md` unter Story 10 "Keep Awake / Sleep Override".

## Phase 11: Switcher-Verhalten (minimierte Fenster, Per-App-Policies, Cmd+Tab)

- Betrifft den Switcher-Kern, kein Add-on-Modul. Alt-Tab+ ist ein AltTab-Fork, darum nur das bewusst abweichende Verhalten bauen; vieles ist schon da (minimierte/versteckte Fenster konfigurierbar, Auswahl deminiaturisiert, Per-App-`ExceptionEntry`, `Cmd+Tab` als Default-Trigger).
- Delta 1: Policy fuer minimierte Fenster erweitern um `ShowButDoNotRestore` und `RestoreOnlyOnExplicitAction` (heute nur Sichtbarkeit plus Auto-Restore). Default bleibt AlwaysRestore.
- Delta 2: Per-App-Regeln (`ExceptionEntry`) um eine Minimized-Policy, App- vs. Window-Switching und Priorisierung erweitern; reichere Match-Kriterien spaeter.
- Delta 3: neue Aktion `Restore most recent minimized window of selected app` im gemeinsamen Register.
- Delta 4: `Cmd+Tab`-Remap ist bereits Realitaet; offen nur Onboarding-Hinweis und Reset-Pfad.
- Benannte Default-Profile: Konservativ, Power-User, Windows-like.
- Vollstaendige Spezifikation in `backlog.md` unter Story 11.

## Phase 12: Fenster-Fokus-Aktionen

- Umgesetzt 2026-09-16; Geraetepruefung offen (`docs/system-actions-checklist.md`).

- `Isolate Window` als Aktion im gemeinsamen Register: andere Apps ausblenden, uebrige Fenster der Ziel-App minimieren. Kein Tap, kein Timer.
- Danach die verwandten Aktionen aus denselben zwei Bausteinen, einzeln waehlbar.
- Vollstaendige Spezifikation und der ganze Supercharge-Abgleich in `backlog.md` unter Story 12 und `Supercharge-Abgleich`.

## Phase 13: Debug-Untermenue

- Umgesetzt 2026-09-16; Geraetepruefung offen.

- Der Menueleisten-Eintrag `Debug tools` wird zu `Debug` mit Untermenue: Debug-Info kopieren, Accessibility-Baum des fokussierten Fensters kopieren, Berechtigungen zuruecksetzen, dazu das bestehende Debug-Fenster.
- Geschwaerzt: keine Fenstertitel, URL-Slots, Benutzernamen oder Textfeldinhalte im kopierten Text.
- Vollstaendige Spezifikation in `backlog.md` unter Story 13.

## Phase 14: System-Aktionen und Werkzeuge

- Umgesetzt 2026-09-16, alle Bloecke; Geraetepruefung offen, dazu V-19 (Cat Mode), V-20 (Funktionstasten), V-21 (Mitteilungen).

- Aus dem Supercharge-Abgleich uebernommen, in unabhaengigen Bloecken: Apps beenden (mit Rueckfrage), Auto-Quit, Displays schlafen, Ton und Mikrofon stummschalten, Zwischenablage leeren, Laufwerke auswerfen, Standardbrowser mit Untermenue, Funktionstasten, Bildschirm-Werkzeuge (Farbe, Texterkennung, Uebersetzung, QR), Mitteilungen leeren, Cat Mode.
- Jede Funktion ist eine Aktion im gemeinsamen Register; keine Tastenkombination ab Werk; nichts laeuft im Hintergrund, solange es nicht benutzt wird.
- Unverifizierte Wege (Displays ohne Admin, Funktionstasten, Mitteilungen per AX, Uebersetzung) zuerst per Spike belegen. Cat Mode nur nach V-19.
- Vollstaendige Spezifikation in `backlog.md` unter Story 14.

## Phase 15: Menueleisten-Menue gruppiert

- Umgesetzt 2026-09-16; Shortcuts im Tab `Menu Actions`.

- Alle Eintraege in inhaltlichen Gruppen mit Ueberschrift: Switcher, Fenster, Apps, Werkzeuge, Mitteilungen, System, Schalter, Standards, AltTab+. Die Gruppe Systemeinstellungen wurde am 2026-09-16 wieder entfernt.
- Alles immer sichtbar: Switcher, Fenster und AltTab+ im Hauptmenue, alle anderen Gruppen als Abschnitte in `Other…`. Kein Ein- und Ausblenden (entschieden 2026-09-16).
- Waechst mit Story 10, 12, 13 und 14. Vollstaendige Spezifikation in `backlog.md` unter Story 15.

## Phase 16: Einstellungsfenster umbauen

- Umgesetzt 2026-09-16 in drei gestapelten Branches; darunter liegt der Fix `fix/system-action-shortcuts` (PR #57).

- Stufe 1 (`feat/settings-pages`): eine Seite pro Bereich, Seitenleiste mit Gruppen inklusive Triggers und Devices, breitere Recorder, Seitenleiste unten aufgeraeumt, Texte.
- Stufe 2 (`feat/settings-lists`): Apps & URLs und Profiles als Listen mit App-Auswahl per Dialog; Speicherformat bleibt, nur Aufraeumen leerer Slots.
- Stufe 3 (`feat/settings-shortcut-overview`): Shortcut-Uebersicht mit Konflikten und `Show`; ein Recorder pro Shortcut.
- Vollstaendige Spezifikation in `backlog.md` unter Story 16.

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
