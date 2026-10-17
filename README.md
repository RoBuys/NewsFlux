# NewsFlux

Agrégateur de flux RSS / Atom pour macOS, léger et natif (Swift + SwiftUI).

## Fonctionnalités

- Interface trois colonnes : flux → articles → lecture
- Vues « Tous les articles » et « Non lus », compteurs de non lus
- Lecture en mode **Résumé** (mise en page éditoriale) ou **Page web** intégrée
- Recherche dans les titres et résumés
- Ajout / suppression de flux, « tout marquer comme lu »
- Actualisation parallèle de tous les flux au lancement, puis toutes les 15 min (⌘R pour forcer)
- Flux et état lu/non lu sauvegardés dans `~/Library/Application Support/NewsFlux/state.json`

## Prérequis

macOS 14 ou plus, et les Command Line Tools (`xcode-select --install`). Xcode n'est pas obligatoire.

## Lancer en développement

```bash
swift run
```

## Construire l'application

```bash
./scripts/build-app.sh
open build/NewsFlux.app
```

## Structure

```
Sources/NewsFlux/
├── NewsFluxApp.swift        Point d'entrée, fenêtre et menus
├── Models/Models.swift      Feed, Article, SidebarItem
├── Services/
│   ├── FeedParser.swift     Parseur RSS 2.0 / Atom (XMLParser)
│   └── FeedStore.swift      État, réseau, persistance
├── Views/                   Barre latérale, liste, lecture, ajout de flux
└── Support/ViewState.swift  Alias de @State (voir ci-dessous)
```

## Note sur `@ViewState`

Sur le SDK macOS 27, `@State` est une macro dont le plugin n'est fourni qu'avec Xcode.
Pour compiler avec les seules Command Line Tools, le projet utilise l'alias `@ViewState`,
identique à `@State`. Si Xcode est installé, vous pouvez revenir à `@State`.

## Licence

Distribué sous licence MIT. Voir [LICENSE](LICENSE).
