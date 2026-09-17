---
name: humanizer-ch-maintainer
description: Führt die kanonischen Vertrags-, Test-, Skill-, Bundle- und Releaseprüfungen des humanizer-ch-Repositories aus und berichtet Blocker. Nur explizit für Wartung, Migration und Releasevorbereitung verwenden; nicht für normale Textbearbeitung.
---

# Humanizer CH Maintainer

## Auftrag

Orchestriere ausschliesslich die im Repository definierten Prüfungen. Erfinde keine Ersatztests und ändere keine Produktregel nur, damit ein Test besteht.

## Ablauf

1. Lies `SPECIFICATION.md`, `BACKLOG.md` und die betroffenen Contracts nur soweit für die angeforderte Prüfung nötig.
2. Führe `PYTHONDONTWRITEBYTECODE=1 python3 scripts/verify.py --compact` im Repository-Root aus.
3. Behandle `failed` als Blocker. Behandle `skipped` nie als bestanden; unterscheide optionale und erforderliche Prüfungen.
4. Bei Skill-Änderungen führe zusätzlich den Skill-Creator-Validator für beide Produkt-Skills aus, sofern dessen Entwicklungsabhängigkeiten verfügbar sind.
5. Bei Plugin- oder Bundle-Änderungen führe zusätzlich den Plugin-Validator aus.
6. Melde Vertragsversionen, bestandene, fehlgeschlagene und übersprungene Prüfungen sowie den kleinsten sicheren nächsten Schritt.

## Stoppbedingungen

- Keine Installation von Abhängigkeiten, kein Netzaufruf und kein Modelllauf ohne ausdrücklichen Auftrag.
- Keine Marketplace-, Plugin- oder Nutzerkonfiguration verändern.
- Keine fehlgeschlagene Pflichtprüfung durch eine manuelle Einschätzung ersetzen.
- Modell-Evaluationen nur mit fixierter Modellrevision, Routingprofil und Kostenfreigabe ausführen.

## Auslieferungsgrenze

Dieser Skill ist Entwicklungswerkzeug. Er darf nicht in das Nutzer-Plugin, das Release-Bundle oder dessen Marketplace-Eintrag aufgenommen werden.
