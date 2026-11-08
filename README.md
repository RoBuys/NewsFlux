# NewsFlux

Agrégateur de flux RSS / Atom pour macOS, léger et natif (Swift + SwiftUI).

## Fonctionnalités

- Interface trois colonnes : flux → articles → lecture
- Vues « Tous les articles », « Non lus » et « Favoris » (⌘D), compteurs de non lus
- Dossiers de flux (clic droit sur un flux → Déplacer vers)
- Icône de chaque site dans la barre latérale et la liste d'articles
- Ajout d'un flux à partir de l'adresse du site : le flux RSS / Atom est trouvé automatiquement
- Lecture en mode **Résumé** (mise en page éditoriale) ou **Page web** intégrée
- Recherche dans les titres et résumés
- Articles conservés entre deux lancements (30 jours, favoris gardés indéfiniment)
- Icône dans la barre des menus avec les derniers non lus (désactivable dans Réglages, ⌘,)
- Notifications des nouveaux articles, à activer flux par flux (clic droit → Activer les notifications)
- Actualisation parallèle de tous les flux au lancement, puis toutes les 15 min (⌘R pour forcer)
- Données sauvegardées dans `~/Library/Application Support/NewsFlux/`

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
│   ├── FeedDiscovery.swift  Téléchargement, découverte de flux, icônes
│   ├── FeedStore.swift      État, actualisation, persistance
│   └── Notifier.swift       Notifications
├── Views/                   Barre latérale, liste, lecture, ajout de flux, barre des menus
└── Support/ViewState.swift  Alias de @State (voir ci-dessous)
```

## Note sur `@ViewState`

Sur le SDK macOS 27, `@State` est une macro dont le plugin n'est fourni qu'avec Xcode.
Pour compiler avec les seules Command Line Tools, le projet utilise l'alias `@ViewState`,
identique à `@State`. Si Xcode est installé, vous pouvez revenir à `@State`.

## Licence

Distribué sous licence MIT. Voir [LICENSE](LICENSE).
