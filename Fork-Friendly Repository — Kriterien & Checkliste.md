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
- [ ] Lokale Builds koennen ohne Apple Developer Account signiert werden.
- [ ] Fuer macOS-Apps mit TCC-Berechtigungen gibt es eine stabile lokale Signatur, damit Accessibility, Screen Recording und aehnliche Rechte ueber Rebuilds hinweg erhalten bleiben.
- [ ] Ad-hoc signing bleibt nur Fallback fuer lokale Builds, wenn keine lokale Signier-Identitaet vorhanden ist.
- [ ] Der lokale Ad-hoc-Fallback warnt klar, dass TCC-Berechtigungen wie Accessibility und Screen Recording nach einem Rebuild erneut erforderlich sein koennen.
- [ ] Lokale Builds laufen im normalen User-Kontext; `sudo` wird hoechstens fuer den finalen Kopiervorgang nach `/Applications` verwendet.
- [ ] Release- und Distributionsbuilds brechen ohne die vorgesehene Signatur ab, statt unbemerkt ad-hoc zu signieren.
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
- [ ] Lokale selbstsignierte Zertifikate werden nicht committed, sondern bei Bedarf reproduzierbar erzeugt.
- [ ] Der Name der lokalen Signier-Identitaet ist dokumentiert und wird vom Build-Script automatisch verwendet.
- [ ] Signing-Scripte verwenden kein Shell-Tracing wie `set -x`, wenn Passwoerter, Zertifikate oder Schluessel verarbeitet werden.
- [ ] Zufaellige Exportpasswoerter und temporaere private Schluessel werden auch bei einem Scriptfehler sicher aufgeraeumt.
- [ ] TCC-relevante macOS-Berechtigungen werden gegen stabile App-Identitaet getestet, nicht nur gegen App-Name und Bundle-ID.
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
- Der Fork braucht einen eigenen Bundle Identifier, hier `com.gcolicig.alttab-plus`.
- Auto-Update darf nicht unbemerkt wieder auf Upstream oder eine neuere kostenpflichtige Version zeigen.
- Sparkle-Feeds muessen geleert, deaktiviert oder auf eigene Infrastruktur umgestellt werden.
- AppCenter und Feedback-Code sollten optional sein, damit fehlende Maintainer-Accounts den Fork nicht brechen.
- Lokale Builds muessen ohne Apple Developer Certificate funktionieren.
- Lokale AltTab+-Entwicklungsbuilds sollten mit `AltTab+ Local Codesign` signiert werden, sobald dieses Zertifikat im Login-Schluesselbund existiert.
- Reines ad-hoc signing kann macOS-TCC verwirren: System Settings zeigt dann Berechtigungen als aktiv, waehrend die neu gebaute App intern als andere Binary gilt und `Not allowed` meldet.
- Der Ad-hoc-Fallback ist trotzdem sinnvoll, damit ein frischer Checkout ohne Apple Developer Account und ohne vorheriges Schluesselbund-Setup gebaut werden kann; er ist kein geeigneter Release-Fallback.
- Der Build selbst sollte nicht mit `sudo` laufen, weil die private Signier-Identitaet an den Login-Schluesselbund des normalen Users gekoppelt ist. Erhoehte Rechte gehoeren nur an den Installationsschritt.
- Das lokale Codesign-Zertifikat darf nicht im Repo liegen; `scripts/codesign/setup_local.sh` erzeugt es reproduzierbar und raeumt temporaere Dateien wieder auf.
- Codesign-Scripte duerfen nicht mit `set -x` laufen: Sonst koennen zufaellige PKCS#12-Passwoerter im Terminal- oder CI-Protokoll landen.
- `/Applications/AltTab+.app` ist ein sinnvoller Installationsname, weil er vom Original unterscheidbar ist.
- Ein laufender Build aus `DerivedData` sollte beendet werden, bevor man die installierte App testet.
- Wenn `DerivedData`-Frameworks beim Bauen gesperrt sind, laeuft wahrscheinlich noch eine alte App-Instanz; fuer Verifikation hilft ein frischer `DERIVED_DATA_PATH`.
- XcodeGen ist nur dann Standardvorgehen, wenn das Projekt wirklich aus `project.yml` generiert wird.
- Wenn kein `project.yml` existiert, bleibt die vorhandene `.xcodeproj` vorerst Source of Truth.
- `origin` sollte auf den eigenen Fork zeigen, `upstream` auf das Original.
- Pushes zu `upstream` sollten technisch verhindert werden, z. B. durch eine deaktivierte Push-URL.

## Wiederverwendbares Rezept: Lokale Signier-Identitaet

Die drei Scripts unter `scripts/codesign/` (setup_local, generate_selfsigned_certificate,
import_certificate_into_main_keychain) sind projektunabhaengig und wurden bereits nach
Blitztegschter uebernommen. Fuer ein neues Projekt:

1. `scripts/codesign/` kopieren und den Default-Identitaetsnamen in `setup_local.sh` anpassen
   (`<Projekt> Local Codesign` — pro Projekt eine eigene Identitaet, damit Widerruf oder
   Erneuerung andere Projekte nicht beruehrt).
2. Im Build-Script eine `sign_app`-Funktion: signiert mit der Identitaet, wenn
   `security find-identity` sie findet, sonst ad-hoc mit Hinweis auf das Setup-Script.
3. In `docs/setup.md` dokumentieren, inklusive der einmaligen Folgekosten: nach dem ersten
   signierten Build sieht macOS einmal einen neuen Signer — TCC-Berechtigungen neu erteilen,
   Keychain-Prompt mit "Immer erlauben" beantworten, danach dauerhaft stabil.

Was das Rezept loest: Ad-hoc-Signaturen haben keinen stabilen Signer, jeder Rebuild ist fuer
macOS eine andere App — TCC-Grants (Bedienungshilfen, Mikrofon, Automation) und Keychain-ACLs
brechen bei jedem Build. `security add-trusted-cert -d` ist der einzige Schritt, der einmalig
Adminrechte braucht.

## Scorecard-Vorlage

```markdown
## Fork-Friendly Score: <Projektname>

### Pflicht-Kriterien

- [ ] Lizenz klar
- [ ] Lokal buildbar
- [ ] Ohne private Zertifikate buildbar
- [ ] Stabile lokale Signatur fuer macOS-Berechtigungen
- [ ] Dokumentierter Ad-hoc-Fallback fuer lokale Builds
- [ ] Kein stiller Ad-hoc-Fallback fuer Release-Builds
- [ ] Kein kompletter Build unter `sudo`
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

Pflicht: __ / 14
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
- Release-Builds fallen bei fehlender Signier-Identitaet unbemerkt auf ad-hoc signing zurueck.
- Lokale Builds muessen komplett mit `sudo` laufen, obwohl die Signier-Identitaet im User-Schluesselbund liegt.
- Lokale macOS-Apps werden nur ad-hoc signiert, obwohl sie Accessibility, Screen Recording oder Input Monitoring brauchen.
- System Settings zeigt Berechtigungen als aktiv, aber die App meldet sie als fehlend; haeufiges Zeichen fuer instabile Signatur oder wechselnden Build-Pfad.
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
