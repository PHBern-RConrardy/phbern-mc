# PHBern Multiple Choice

Eigenständige Quarto-Erweiterung für Multiple-Choice-Fragen. Dieser Ordner ist
bewusst von `phbern-quarto-extension` getrennt und enthält seine eigenen
Beispiele.

## Lokal prüfen

Im Ordner ausführen:

```bash
quarto render
```

Das rendert die drei Beispiele als HTML, Reveal.js und Typst/PDF.

## Verwendung

```yaml
format:
  phbern-mc-html: default
  phbern-mc-revealjs: default
  phbern-mc-typst: default
```

## Syntax

`:::phbern-mc` ist für genau eine richtige Antwort,
`:::phbern-mc-multiple` für mehrere. Die Frage und die Antworttexte dürfen
gewöhnliches Markdown enthalten. `[x]` markiert eine richtige, `[ ]` eine
falsche Antwort. Nach `::` folgt der kurze Hinweis, der online nach dem Prüfen
und im Typst-Anhang bei der richtigen Antwort erscheint.

````markdown
:::phbern-mc
**Wie lautet die Hauptstadt von Frankreich?**

- [ ] Berlin :: Das ist die Hauptstadt von Deutschland.
- [x] **Paris** :: Dort steht der Eiffelturm.
:::
````

Die drei Beispiele liegen in [`examples/`](examples/).

## Ort des Lösungsteils

Ohne weiteren Eintrag setzt Typst die Lösungen ans Dokumentende und erzeugt
die Überschrift `# Lösungen`. Für einen eigenen Ort wird ein leerer Platzhalter
gesetzt. Dort erzeugt die Erweiterung keine Überschrift; sie kann also nach
einer eigenen Überschrift wie `# Anhang` oder `# Lösungen` stehen:

````markdown
# Anhang

:::phbern-mc-solutions
:::
````
