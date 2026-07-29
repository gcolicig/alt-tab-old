# Spezifikation: Shortcut Clues

Stand: 2026-07-29

Ergaenzende Spezifikation zu `backlog.md`. Sie beschreibt ein eigenstaendiges Modul und aendert keine
bestehende Phase. Alle Querschnittsanforderungen (`Q-01` bis `Q-16`), die Private-API-Leitplanke und die
Release-Gates aus `backlog.md` gelten unveraendert.

## Leitidee

Wer eine App selten benutzt, kennt ihre Tastenkuerzel nicht. Sie stehen zwar in den Menues, aber das
Nachschlagen unterbricht genau den Arbeitsfluss, den die Kuerzel beschleunigen sollen. Shortcut Clues
blendet die Kuerzel der gerade aktiven App als Overlay ein, solange ein Trigger gehalten wird, und
verschwindet beim Loslassen. Es ist ein Nachschlagewerk, kein Ausfuehrungsweg: Das Overlay loest keine
Aktion aus und faengt keine Tasten ab.

## Abgrenzung zum Aktionsregister

Shortcut Clues ist der erste Modulumfang, der **fremde** Shortcuts liest statt eigene auszufuehren. Es
haengt deshalb nicht am gemeinsamen Aktionsregister aus Phase 1 und registriert keine Aktionen. Einzige
Beruehrung: Der Trigger, der das Overlay zeigt, wird wie jeder andere Trigger konfliktgeprueft.

## Vorbild und Provenienz

`https://github.com/Anze/KeyCluCask` (KeyClu), BSD-3-Clause-Clear, geprueft am 2026-07-29 auf Revision
`4fc7acbbad060822782bab4c5e8bc71cf42458da`. Uebernommen wird ausschliesslich das **Produktkonzept**;
kein Quellcode. Der Eintrag im Provenienz-Register erfolgt als Typ A.

Belegte Eigenschaften des Vorbilds:

- Aufruf durch zweimaliges Tippen und Halten von `Command`, alternativ einfaches Halten.
- Datenquelle sind die Menues der aktiven App ueber die Accessibility API.
- Ausdrueckliche Grenze laut FAQ: "KeyClu only have access to App's menus". Kuerzel, die eine App nicht
  im Menue fuehrt, sind unsichtbar. Das Projekt pflegt dafuer ein separates Repository kuratierter
  Zusatzdateien (`KeyCluExtensions`).
- Bekanntes Performanceproblem bei Browsern mit grossen Lesezeichenmenues; das Vorbild bietet dagegen
  eine Option, die Zahl der Menueeintraege zu begrenzen.
- Weitere Quellen des Vorbilds (skhd, Jitouch2, CustomShortcuts) sind fuer AltTab+ **nicht** Umfang.

## Status und Prioritaet

Status: Spezifiziert, nicht begonnen
Prioritaet: Mittel. Sinnvoll erst nach Phase 3A, weil dieselbe AX-Disziplin gebraucht wird.

## Trigger

- Kein Default-Trigger. Das Modul startet deaktiviert, wie jedes Input-nahe Modul.
- Der Trigger ist ein gehaltenes Kuerzel; das Overlay erscheint nach einer konfigurierbaren Verzoegerung
  (Richtwert 300 ms) und verschwindet beim Loslassen.
- **Bewusst nicht uebernommen wird der Doppeltipp auf `Command`.** Ihn zu erkennen verlangt einen
  dauerhaften Keyboard-Tap, der jeden Tastendruck des Systems sieht. AltTab+ haelt einen Keyboard-Tap
  bereits fuer Hyper, aber der ist Opt-in und faellt unter `Q-04`, `Q-11` und `Q-12`. Ein zweiter
  Grund, den Tap dauerhaft scharf zu halten, waere ein Rueckschritt gegenueber `Q-05` und dem
  Energie-Gate `Q-10`.
- Umgesetzt wird der Trigger deshalb ueber die bestehende Shortcut-Infrastruktur, damit
  Kollisionspruefung, Presets und die Recorder-Oberflaeche unveraendert greifen.
- Solange das Overlay sichtbar ist, werden keine Tasten absorbiert. Wer waehrend des Haltens ein
  angezeigtes Kuerzel drueckt, loest es in der Ziel-App aus; das Overlay schliesst sich dabei.

## Datenquelle

Einzige Quelle im MVP ist die Menueleiste der aktiven App, gelesen ueber die oeffentliche Accessibility
API. Keine private API, kein Scraping fremder Konfigurationsdateien.

Auslesepfad:

1. Frontmost-App bestimmen, wie es der Fensterkern fuer Keyboard-Layouts bereits tut.
2. `kAXMenuBarAttribute` des App-Elements holen und die Menuestruktur rekursiv durchlaufen.
3. Je Eintrag Titel, Aktivierungszustand und die Kuerzel-Attribute lesen: `AXMenuItemCmdChar`,
   `AXMenuItemCmdVirtualKey`, `AXMenuItemCmdGlyph`, `AXMenuItemCmdModifiers`.
4. Eintraege ohne Kuerzel und deaktivierte Eintraege verwerfen, Gruppen nach Menuetitel behalten.

Zu verifizieren, bevor implementiert wird:

- Die Modifier-Kodierung von `AXMenuItemCmdModifiers` ist ein Bitfeld, in dem `Command` invertiert
  kodiert sein soll (gesetztes Bit bedeutet *kein* Command). Das ist am Zielgeraet gegen echte Menues
  zu pruefen, bevor die Darstellung darauf aufbaut.
- Ob `AXMenuItemCmdGlyph` fuer Sondertasten wie Pfeile oder Tabulator zuverlaessig gefuellt ist, oder ob
  `AXMenuItemCmdVirtualKey` der belastbarere Weg ist.
- Ob Menues vieler Apps erst nach dem Oeffnen vollstaendig befuellt sind. Falls ja, ist zu dokumentieren,
  welche Apps unvollstaendig bleiben, statt Menues heimlich zu oeffnen.

## Leistungsanforderungen

Ein Menuebaum vollstaendig zu durchlaufen sind viele synchrone AX-Aufrufe. Ohne Disziplin blockiert das
die App sichtbar, und beim Vorbild ist genau das bei Browsern belegt.

- Der Durchlauf laeuft ausschliesslich ueber die bestehende serielle AX-Queue, nie im Event-Callback
  (`Q-02`) und mit gesetztem Messaging-Timeout (`Q-03`).
- Ergebnisse werden je App zwischengespeichert und beim App-Wechsel, bei Menueaenderungen und nach
  einer kurzen Gueltigkeitsdauer verworfen.
- Harte Obergrenzen fuer Rekursionstiefe und Eintragszahl je Menue, damit ein Lesezeichenmenue mit
  Tausenden Eintraegen die App nicht anhaelt. Ueberschreitung wird sichtbar gemeldet, nicht still
  abgeschnitten.
- Wird die Sammlung nicht rechtzeitig fertig, erscheint das Overlay mit dem bereits Bekannten und einem
  Ladehinweis, statt den Trigger ins Leere laufen zu lassen.

## Darstellung

- Ein Panel, das nicht den Fokus uebernimmt, damit die Ziel-App aktiv bleibt.
- Gruppierung nach Menuetitel in der Reihenfolge der Menueleiste, mehrspaltig.
- Kuerzel in Systemschreibweise; Sondertasten als Symbole.
- Anzeige auf dem Bildschirm unter dem Cursor, wie die uebrigen Module.
- Ohne Accessibility-Berechtigung oder bei leerem Ergebnis erscheint eine erklaerende Meldung mit Grund,
  kein leeres Panel.

## Nicht im MVP

- Doppeltipp-Trigger und jeder dafuer noetige dauerhafte Event-Tap.
- Eigene Kuerzel-Dateien und ein Pendant zu `KeyCluExtensions`.
- Uebernahme von Kuerzeln aus skhd, Jitouch2 oder anderen Fremdwerkzeugen.
- Export nach Markdown oder in andere Formate.
- Suche, Lesezeichen und Ausblenden bekannter Kuerzel.
- Anzeige der eigenen AltTab+-Aktionen im selben Overlay. Sinnvoll erst, wenn das Aktionsregister
  Titel wirklich ausliefert; die Leader-Uebersicht aus Phase 4 ist der natuerliche Ort dafuer.
- Menues fremder Apps oeffnen, um sie zu befuellen.

## Akzeptanzideen

- Trigger halten zeigt das Overlay; Loslassen schliesst es rueckstandsfrei.
- Waehrend das Overlay sichtbar ist, erreicht jeder Tastendruck unveraendert die Ziel-App.
- Ein App-Wechsel bei gehaltenem Trigger zeigt die Kuerzel der neuen App oder schliesst das Overlay,
  aber mischt nie zwei Apps.
- Eine App ohne Menuekuerzel erzeugt eine erklaerende Meldung statt eines leeren Panels.
- Ein Browser mit sehr grossem Lesezeichenmenue laesst die App bedienbar; die Begrenzung ist sichtbar.
- Entzug der Accessibility-Berechtigung deaktiviert das Modul sichtbar und ohne Retry-Schleife.
- Deaktivieren des Moduls hinterlaesst weder Panel noch Beobachter noch Cache.

## Offene Fragen

- Verhaelt sich das Overlay bei gehaltenem Trigger und Space-Wechsel sinnvoll, oder ist es dort besser
  zu schliessen?
- Braucht es eine Begrenzung auf die vorderste Menueebene, um bei sehr tiefen Menues brauchbar zu
  bleiben?
- Sollen deaktivierte Menueeintraege ausgegraut mitlaufen, statt zu verschwinden? Sie verraten, welches
  Kuerzel es gaebe, wenn der Kontext stimmt.
