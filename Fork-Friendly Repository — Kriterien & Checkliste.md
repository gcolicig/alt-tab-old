# Fork-Friendly Repository - Kriterien & Checkliste

Diese Checkliste hilft dabei, ein Repository so vorzubereiten, dass es realistisch geforkt, lokal gebaut, angepasst und unabhaengig weitergefuehrt werden kann.

Sie basiert auf der Analyse eines macOS-App-Forks von `lwouis/alt-tab-macos` auf Stand `v10.12.0` sowie auf allgemeinen Open-Source-Kriterien.

## Was "fork-friendly" bedeutet

Ein fork-freundliches Repository erlaubt einer fremden Person, ohne Sonderzugang:

1. den Code zu klonen,
2. die benoetigten Werkzeuge zu installieren,
3. die App lokal zu bauen,
4. die App lokal zu starten oder zu installieren,
5. Projektnamen, Bundle-ID, Update-Kanal und Links auf den eigenen Fork umzustellen,
6. kostenpflichtige, zentrale oder maintainer-spezifische Dienste zu entfernen oder zu ersetzen.

Fork-freundlich ist ein Projekt erst dann, wenn der Fork nicht nur technisch kompiliert, sondern auch praktisch unabhaengig betrieben werden kann.

## Pflicht-Kriterien

### Lizenz und rechtliche Klarheit

- [ ] Eine OSI-kompatible Lizenz ist vorhanden, idealerweise als `LICENSE`.
- [ ] Alte oder alternative Lizenzdateien sind eindeutig, z. B. `LICENCE.md` plus `LICENSE`.
- [ ] Marken, Namen, Logos und Screenshots sind geklaert oder austauschbar.
- [ ] README und Dokumentation nennen klar, worauf der Fork basiert.
- [ ] Upstream-Projekt und Fork-Projekt sind unterscheidbar.

### Lokaler Build

- [ ] Ein einzelner Build-Befehl funktioniert, z. B. `./build.sh`.
- [ ] Der Build benoetigt keine privaten Zertifikate.
- [ ] Lokale Builds verwenden ad-hoc signing, wenn echte Developer-Zertifikate nicht noetig sind.
- [ ] Das Build-Script prueft Xcode, Command Line Tools und Mindestversion.
- [ ] Fehlende Werkzeuge erzeugen klare Fehlermeldungen.
- [ ] Der Build schreibt lokale Artefakte in ignorierte Ordner wie `DerivedData/` oder `build/`.
- [ ] Der Build wurde auf einem frischen Checkout getestet.

### Testen und Installieren

- [ ] Es gibt einen dokumentierten Testpfad ohne Installation, z. B. `./build.sh --run`.
- [ ] Der Pfad zur gebauten App ist dokumentiert.
- [ ] Es gibt einen dokumentierten Installationspfad, z. B. `/Applications/<Fork Name>.app`.
- [ ] README erklaert, ob die App parallel zum Original laufen kann.
- [ ] README warnt vor moeglichen Konflikten, z. B. globalen Shortcuts.

### Unabhaengigkeit vom Upstream

- [ ] Bundle Identifier ist auf den Fork umgestellt.
- [ ] App-Name oder Installationsname unterscheidet sich vom Original.
- [ ] Repository-Links zeigen auf den Fork.
- [ ] Issue-, Support-, Feedback- und Dokumentationslinks zeigen nicht unabsichtlich auf Upstream.
- [ ] Git-Remote `origin` zeigt auf den eigenen Fork.
- [ ] Git-Remote `upstream` ist nur zum Lesen vorgesehen oder gegen versehentliches Pushen gesichert.

### Updates und zentrale Dienste

- [ ] Auto-Update ist deaktiviert oder auf einen eigenen Update-Kanal umgestellt.
- [ ] Sparkle-Appcast oder vergleichbare Update-Feeds zeigen nicht mehr auf Upstream.
- [ ] Update-Checks lassen sich per Default ausschalten.
- [ ] Crash-Reporting ist optional oder deaktiviert, wenn kein eigener Account konfiguriert ist.
- [ ] Analytics, Telemetrie, Feedback-Formulare und Sponsoring-Links sind entfernt, optional gemacht oder auf den Fork umgestellt.
- [ ] Keine kostenpflichtigen oder maintainer-spezifischen Funktionen bleiben als harte Laufzeitabhaengigkeit im Fork.

### Secrets und Zertifikate

- [ ] Keine privaten Zertifikate, Provisioning Profiles oder Notarisierungs-Credentials liegen im Repository.
- [ ] CI- und Release-Scripte erwarten Secrets nur optional und dokumentiert.
- [ ] Lokale Builds funktionieren ohne Apple Developer Account.
- [ ] Release-Builds dokumentieren klar, welche Signatur- und Notarisierungsdaten benoetigt werden.
- [ ] Keine API-Keys, Tokens, AppCenter-Secrets oder private Appcast-Signing-Keys sind committed.

## Empfohlene Kriterien

### Dokumentation

- [ ] README beantwortet: Was ist das Projekt?
- [ ] README beantwortet: Warum existiert dieser Fork?
- [ ] README beantwortet: Wie baut man die App?
- [ ] README beantwortet: Wie testet man die App?
- [ ] README beantwortet: Wie installiert man die App lokal?
- [ ] README erklaert benoetigte macOS-Berechtigungen.
- [ ] README erklaert den Datenfluss grob.
- [ ] `docs/setup.md` enthaelt detailliertere Entwicklerhinweise.
- [ ] `ROADMAP.md` nennt bekannte Grenzen und naechste Schritte.
- [ ] `CONTRIBUTING.md`, `SUPPORT.md`, `SECURITY.md` und `CODE_OF_CONDUCT.md` sind vorhanden.

### Build-System und Projektdateien

- [ ] Die verwendete Xcode-Version ist dokumentiert.
- [ ] Swift-Version und macOS Deployment Target sind dokumentiert.
- [ ] CocoaPods, Swift Package Manager, XcodeGen oder andere Werkzeuge sind klar eingeordnet.
- [ ] XcodeGen wird nur als Standard verwendet, wenn ein vollstaendiges `project.yml` existiert.
- [ ] Generierte Dateien werden nicht blind ersetzt, wenn Upstream-Projektdateien komplexe Build-Phasen enthalten.
- [ ] CI baut denselben Pfad wie lokale Entwickler.

### Fork-Betrieb

- [ ] Der Fork kann unter eigenem Namen veroeffentlicht werden.
- [ ] Appcast, Website und Download-Links lassen sich auf eigene Infrastruktur umstellen.
- [ ] Versionierung und Release-Scripte sind nicht an Upstream-Tags gebunden.
- [ ] Maintainer-spezifische Automationen sind entfernt oder neutralisiert.
- [ ] GitHub Actions haben minimale Permissions.
- [ ] Dependabot oder vergleichbare Updates sind aktiviert.

## AltTab-Fork-Lektionen

Diese Punkte waren in der konkreten AltTab-Fork-Arbeit besonders wichtig:

- Eine letzte freie Version sollte als stabiler Ausgangspunkt getaggt werden, hier `v10.12.0`.
- Der Fork braucht einen eigenen Bundle Identifier, hier `com.gcolicig.alt-tab-old`.
- Auto-Update darf nicht unbemerkt wieder auf Upstream oder eine neuere kostenpflichtige Version zeigen.
- Sparkle-Feeds muessen geleert, deaktiviert oder auf eigene Infrastruktur umgestellt werden.
- AppCenter und Feedback-Code sollten optional sein, damit fehlende Maintainer-Accounts den Fork nicht brechen.
- Lokale Builds muessen ohne Apple Developer Certificate funktionieren.
- `/Applications/AltTab Old.app` ist ein sinnvoller Installationsname, weil er vom Original unterscheidbar ist.
- Ein laufender Build aus `DerivedData` sollte beendet werden, bevor man die installierte App testet.
- XcodeGen ist nur dann Standardvorgehen, wenn das Projekt wirklich aus `project.yml` generiert wird.
- Wenn kein `project.yml` existiert, bleibt die vorhandene `.xcodeproj` vorerst Source of Truth.
- `origin` sollte auf den eigenen Fork zeigen, `upstream` auf das Original.
- Pushes zu `upstream` sollten technisch verhindert werden, z. B. durch eine deaktivierte Push-URL.

## Scorecard-Vorlage

```markdown
## Fork-Friendly Score: <Projektname>

### Pflicht-Kriterien

- [ ] Lizenz klar
- [ ] Lokal buildbar
- [ ] Ohne private Zertifikate buildbar
- [ ] Ohne interne Dienste startbar
- [ ] Eigene Bundle-ID / Paket-ID
- [ ] Eigene Repository-Links
- [ ] Auto-Update deaktiviert oder umgestellt
- [ ] Keine Secrets im Repository
- [ ] Testpfad dokumentiert
- [ ] Installationspfad dokumentiert

### Empfohlene Kriterien

- [ ] README erklaert Zweck des Forks
- [ ] Setup-Dokumentation vorhanden
- [ ] Berechtigungen dokumentiert
- [ ] Datenfluss dokumentiert
- [ ] Roadmap vorhanden
- [ ] Contribution-/Support-/Security-Dateien vorhanden
- [ ] CI baut den Fork
- [ ] Dependabot aktiviert
- [ ] Release-Prozess dokumentiert
- [ ] Upstream-Remote gegen versehentliches Pushen gesichert

### Ergebnis

Pflicht: __ / 10
Empfohlen: __ / 10

Einschaetzung:
- [ ] Fork-ready
- [ ] Fast fork-ready
- [ ] Anpassung noetig
- [ ] Nicht fork-ready
```

## Haeufige Warnsignale

- README beschreibt Features, aber keinen Build.
- Build funktioniert nur in Xcode, aber nicht reproduzierbar per Script.
- Release-Scripte erwarten private Zertifikate ohne Fallback.
- Auto-Update zeigt weiter auf Upstream.
- Crash-Reporting startet mit fremden oder fehlenden Secrets.
- Bundle-ID bleibt identisch mit dem Original.
- Support-, Feedback- oder Sponsoring-Links zeigen auf den alten Maintainer.
- App laesst sich zwar bauen, aber nicht sinnvoll parallel zum Original testen.
- Generierte Projektdateien werden ohne reproduzierbare Quelle committed.
- Der Fork kann unabsichtlich zum Upstream pushen.

## Minimaler Fork-Ready-Abschluss

Ein Projekt ist fuer einen pragmatischen Fork gut genug vorbereitet, wenn diese Befehle und Pruefungen erfolgreich sind:

```bash
git remote -v
./build.sh
./build.sh --run
./build.sh --install
```

Danach sollte klar sein:

- welche App gebaut wurde,
- welche Bundle-ID sie hat,
- wohin sie installiert wird,
- ob Updates deaktiviert sind,
- ob externe Dienste optional sind,
- wohin der Code gepusht wird.
