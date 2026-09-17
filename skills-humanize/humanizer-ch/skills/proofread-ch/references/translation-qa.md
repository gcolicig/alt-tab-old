# Translation QA

Richte Quelle und Ziel zuerst über gemeinsame Segment-IDs, danach explizite Mappings und erst anschliessend strukturell aus. Weise `one_to_one`, `one_to_many`, `many_to_one`, Neuordnungen und nicht ausgerichtete Segmente aus.

Prüfe Zahlen, Einheiten, Namen, URLs, Normen, Negationen, Modalität, Auslassungen, Zusätze und Glossarterminologie. Unsichere Alignments verhindern semantische Vollständigkeitsurteile, aber nicht harte globale Token- oder Strukturchecks.

TranslateGemma darf optional eine Alternative für ein beanstandetes Segment erzeugen. Die Alternative durchläuft dieselben Invarianten und wird nie ungeprüft übernommen. Adapterausfall darf Translation QA nicht als bestanden oder fehlgeschlagen umdeuten.
