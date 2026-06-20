# CODEX.md — Telluric Engine Agent Rules

> **Projet :** Telluric Engine  
> **Rôle :** règles obligatoires pour Codex et tout agent automatique intervenant sur le repo.  
> **Objectif :** permettre l’implémentation du moteur Telluric sans jamais casser l’environnement Ruby-on-Rails local de la machine.  
> **Statut :** document opérationnel à placer à la racine du repo Telluric Engine sous le nom `CODEX.md`.

---

## 0. Priorité absolue

La machine de développement contient déjà un environnement Ruby-on-Rails fonctionnel. Cet environnement est prioritaire.

Codex doit considérer que toute action globale sur la machine peut casser Rails, Ruby, PostgreSQL, Homebrew, Bundler, rbenv/RVM/asdf/mise, ou les projets web existants.

Donc :

```text
Aucune commande globale.
Aucun changement système.
Aucune installation globale.
Aucun changement de shell profile.
Aucune modification des outils Ruby/Rails.
Tout doit rester local au repo Telluric Engine.
```

Cette règle est plus importante que la vitesse d’implémentation.

---

## 1. Philosophie Telluric Engine

Telluric Engine ne doit pas devenir un “petit Unreal”.

La philosophie cible est :

```text
seed-first + deterministic-first + systemic-first + simulation-first + Metal-first
```

Le moteur doit générer des mondes :

- procéduraux ;
- déterministes ;
- streamés autour du joueur ;
- systémiques ;
- cohérents géologiquement, écologiquement, hydrologiquement et topologiquement ;
- performants sur Apple Silicon ;
- architecturés proprement entre cœur logique, rendu, tools et runtime.

Codex doit lire et respecter le document :

```text
TELLURIC_ENGINE_FINAL_ARCHITECTURE.md
```

Ce document est la référence de vision long terme. `CODEX.md` est la référence opérationnelle de sécurité et d’intervention.

---

## 2. Règles strictes — environnement local

### 2.1 Interdictions absolues

Codex ne doit jamais exécuter :

```sh
sudo
xcode-select
xcode-select --switch
xcode-select --reset
brew update
brew upgrade
brew install
brew uninstall
brew cleanup
gem install
gem update
bundle update
bundle install --global
npm install -g
pnpm add -g
yarn global
asdf install
mise install
rbenv install
rvm install
```

Codex ne doit jamais modifier :

```text
~/.zshrc
~/.bashrc
~/.profile
~/.zprofile
~/.zshenv
~/.bash_profile
~/.rbenv
~/.rvm
~/.asdf
~/.mise
~/.gem
~/.bundle
/opt/homebrew
/usr/local
/Library/Developer
/Applications/Xcode.app
/Applications/Xcode-beta.app
```

Codex ne doit jamais modifier la configuration Ruby/Rails globale, même indirectement.

### 2.2 Commandes Ruby interdites

Même si le repo Telluric n’est pas un projet Ruby, Codex peut parfois détecter des outils Ruby par erreur. Il doit explicitement éviter :

```sh
ruby
rails
rake
bundle
bundle exec
gem
irb
```

Exception : une commande de lecture non destructive peut être autorisée seulement si l’utilisateur la demande explicitement, par exemple :

```sh
ruby -v
bundle -v
```

Mais Codex ne doit pas utiliser ces commandes pour installer, corriger ou configurer quoi que ce soit dans Telluric.

---

## 3. Règles strictes — Xcode, Swift, Metal

### 3.1 Ne jamais changer `xcode-select`

La machine peut garder `xcode-select` pointé vers CommandLineTools pour protéger l’environnement Ruby/Rails.

Pour Telluric, Codex doit utiliser Xcode complet uniquement via variable d’environnement locale :

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Cette variable doit être définie dans les scripts locaux, jamais dans le shell global.

### 3.2 Toujours utiliser les scripts safe

Codex ne doit pas lancer directement les commandes longues de build/test Swift/Xcode.

Commandes autorisées par défaut :

```sh
./scripts/codex-preflight-safe.sh
./scripts/swift-test-engine-safe.sh
./scripts/xcodebuild-safe.sh build
./scripts/xcodebuild-safe.sh test
```

Si un script manque, Codex doit le créer localement dans `scripts/`, avec validation par petites étapes.

### 3.3 Commandes Swift/Xcode brutes interdites

Codex ne doit pas lancer directement :

```sh
swift test --package-path EngineCore
swift build --package-path EngineCore
xcodebuild build
xcodebuild test
xcrun xcodebuild build
```

À la place, il doit utiliser les scripts safe du repo, qui fixent :

- `DEVELOPER_DIR` localement ;
- `DerivedData` dans le repo ;
- `.build` dans le repo ;
- les chemins exacts du projet ;
- les destinations macOS ;
- les options de validation non destructives.

---

## 4. Structure cible du repo

Structure recommandée pour le nouveau repo propre :

```text
TelluricEngine/
├── CODEX.md
├── TELLURIC_ENGINE_FINAL_ARCHITECTURE.md
├── README.md
├── EngineCore/
│   ├── Package.swift
│   ├── Sources/
│   └── Tests/
├── RenderCoreMetal/
│   ├── Package.swift
│   ├── Sources/
│   └── Tests/
├── AudioRuntime/
│   ├── Package.swift
│   ├── Sources/
│   └── Tests/
├── RuntimeApp/
│   └── TelluricRuntimeApp.xcodeproj
├── TelluricTools/
├── Shaders/
├── Docs/
├── Scripts/
├── scripts/
├── SamplesTiny/
├── LocalAssets/
├── .build/
└── .gitignore
```

Notes :

- `EngineCore` est le cœur déterministe pur.
- `RenderCoreMetal` contient Metal, les shaders, le RenderGraph et la residency GPU.
- `RuntimeApp` contient l’app macOS SwiftUI minimale.
- `TelluricTools` contient les labs et outils de debug, jamais le runtime critique.
- `LocalAssets` doit être ignoré par Git.
- `.build` et DerivedData doivent rester locaux au repo.

---

## 5. Architecture non négociable

### 5.1 EngineCore

`EngineCore` doit rester pur.

Interdit dans `EngineCore` :

```swift
import SwiftUI
import AppKit
import UIKit
import Metal
import MetalKit
import RealityKit
import SceneKit
import SpriteKit
import GameController
import AVFoundation
```

Autorisé dans `EngineCore` :

```swift
import Foundation
import simd
```

`EngineCore` peut contenir :

- déterminisme ;
- math ;
- coordonnées ;
- seeds ;
- RNG stable ;
- WorldDNA ;
- Fields ;
- Chunks ;
- TerrainForge ;
- BiomeForge ;
- Hydrology ;
- SurfaceForge ;
- EcoGrowthForge ;
- MotionCore logique ;
- AudioCore logique ;
- RPGCore ;
- Persistence delta-first ;
- Validation ;
- Golden Seeds.

### 5.2 RenderCoreMetal

`RenderCoreMetal` est le seul module autorisé à importer :

```swift
import Metal
import MetalKit
```

Il peut contenir :

- RenderGraph ;
- ResourceGraph ;
- PipelineCache ;
- ShaderLibrary ;
- TerrainRenderer ;
- SurfaceRenderer ;
- VegetationRenderer ;
- VirtualGeometry / IVDS ;
- GPUCulling ;
- TextureResidency ;
- Lighting ;
- DebugMarkers ;
- CaptureIntegration.

### 5.3 RuntimeApp

`RuntimeApp` peut importer :

```swift
import SwiftUI
import AppKit
import GameController
```

Il orchestre :

- fenêtre macOS ;
- input ;
- manette PS5 ;
- debug HUD ;
- boucle runtime ;
- bridge vers `EngineCore` et `RenderCoreMetal`.

`RuntimeApp` ne doit pas contenir de logique monde profonde.

### 5.4 RealityKit

RealityKit ne doit pas être réintroduit comme renderer.

Interdit :

```swift
import RealityKit
```

Exception uniquement si l’utilisateur demande explicitement un outil de comparaison temporaire dans `TelluricTools/Experimental/`, clairement isolé, non branché au runtime principal.

---

## 6. Contrat procédural et déterministe

Tout système procédural doit être :

- seedé ;
- versionné ;
- hashable ;
- testable ;
- reproductible ;
- indépendant de l’heure système ;
- indépendant de l’ordre non déterministe des threads ;
- indépendant d’un RNG global.

Interdit :

```swift
Float.random(in:)
Double.random(in:)
Int.random(in:)
UUID()
Date()
DispatchQueue.concurrentPerform sans ordre stable
Dictionary iteration utilisée comme ordre logique
Set iteration utilisée comme ordre logique
```

Autorisé seulement si encapsulé dans un contrat stable :

```swift
StableRNG
StableWorldID
DeterministicHash
GeneratorVersion
ChunkCoord
WorldSeed
```

---

## 7. Tests obligatoires

Chaque implémentation importante doit ajouter ou mettre à jour les tests.

Catégories prioritaires :

```text
DeterminismTests
GoldenSeedTests
ChunkSeamTests
SurfaceFieldTests
TerrainPayloadTests
BiomeTransitionTests
WorldResidencyTests
PersistenceDeltaTests
PerformanceBudgetSmokeTests
```

Aucun système procédural ne doit être mergé sans test de reproductibilité minimal.

Exemple de règle :

```text
Same seed + same generator version + same chunk coord = same payload hash.
```

---

## 8. Scripts safe obligatoires

Les scripts ci-dessous doivent vivre dans `scripts/`.

### 8.1 `scripts/codex-preflight-safe.sh`

Objectif : vérifier l’état local sans modifier la machine.

Ce script doit :

- afficher `pwd` ;
- afficher `git status --short` ;
- vérifier l’existence des dossiers attendus ;
- vérifier Xcode via `DEVELOPER_DIR` local ;
- vérifier que le repo ne dépend pas de Ruby ;
- refuser si exécuté hors racine Telluric.

Il ne doit rien installer.

### 8.2 `scripts/swift-test-engine-safe.sh`

Objectif : tester `EngineCore` sans toucher à l’environnement global.

Comportement attendu :

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export SWIFTPM_BUILD_DIR="$ROOT/.build/swiftpm"

/usr/bin/xcrun swift test \
  --package-path EngineCore \
  --scratch-path "$ROOT/.build/EngineCore"
```

### 8.3 `scripts/xcodebuild-safe.sh`

Objectif : compiler/tester l’app macOS sans DerivedData global.

Comportement attendu :

```sh
#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-build}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

PROJECT_PATH="RuntimeApp/TelluricRuntimeApp.xcodeproj"
SCHEME="TelluricRuntimeApp"
DERIVED_DATA="$ROOT/.build/xcode/DerivedData"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "Missing Xcode project: $PROJECT_PATH" >&2
  exit 1
fi

/usr/bin/xcrun xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  "$ACTION"
```

Si les chemins réels diffèrent, Codex doit mettre à jour ce script localement, jamais utiliser une commande globale brute.

---

## 9. Git et hygiène d’intervention

Codex doit :

- commencer par `git status --short` ;
- ne jamais écraser un fichier modifié par l’utilisateur ;
- faire des changements petits, lisibles, testables ;
- expliquer les fichiers modifiés ;
- mettre à jour la doc quand l’architecture change ;
- ne jamais faire de commit sans demande explicite de l’utilisateur ;
- ne jamais faire de push sans demande explicite de l’utilisateur.

Interdit sans demande explicite :

```sh
git reset --hard
git clean -fd
git checkout -- .
git rebase
git push --force
git commit
git push
```

---

## 10. Process d’implémentation obligatoire

Pour toute tâche non triviale, Codex doit répondre avec :

```text
1. Objectif exact
2. Fichiers à modifier
3. Contrats ajoutés ou modifiés
4. Impact déterminisme
5. Impact performance
6. Impact environnement local
7. Tests à ajouter
8. Commandes safe de validation
9. Risques
10. Plan d’implémentation par petites étapes
```

Codex doit explicitement indiquer si une tâche touche :

- `EngineCore` ;
- `RenderCoreMetal` ;
- `RuntimeApp` ;
- `TelluricTools` ;
- scripts ;
- documentation.

---

## 11. Impact sur le process Telluric Engine

Cette contrainte Ruby/Rails change le process du projet.

### 11.1 Ce qu’on ne fait plus

On ne fait plus :

- installation automatique de dépendances ;
- correction globale de toolchain ;
- `xcode-select --switch` ;
- setup Homebrew ;
- installation de packages système ;
- usage de scripts qui écrivent dans `$HOME` ;
- build Xcode avec DerivedData global ;
- tests SwiftPM avec caches par défaut si cela crée des effets de bord globaux.

### 11.2 Ce qu’on fait à la place

On fait :

- repo autonome ;
- scripts safe ;
- caches locaux ;
- DerivedData local ;
- `DEVELOPER_DIR` local par commande ;
- validation progressive ;
- documentation de chaque hypothèse ;
- refus des changements environnementaux ;
- tests déterministes dès le début.

### 11.3 Conséquence sur la roadmap

Avant de coder les grosses features moteur, il faut une phase 0 solide :

```text
Phase 0 — Safe Foundation
1. Créer repo propre TelluricEngine.
2. Ajouter CODEX.md.
3. Ajouter TELLURIC_ENGINE_FINAL_ARCHITECTURE.md.
4. Ajouter .gitignore safe.
5. Ajouter scripts safe.
6. Ajouter EngineCore minimal.
7. Ajouter premier test déterministe.
8. Ajouter RuntimeApp minimal seulement après validation EngineCore.
9. Ajouter RenderCoreMetal minimal seulement après séparation propre.
```

Cette phase protège la machine et empêche la dette technique.

---

## 12. .gitignore recommandé

Le repo doit ignorer :

```gitignore
# Xcode / Swift local build outputs
.build/
DerivedData/
*.xcuserdata/
*.xcuserstate
*.moved-aside
*.ipa
*.dSYM.zip
*.dSYM

# Local assets and generated heavy files
LocalAssets/
GeneratedAssets/
Captures/
Recordings/
ProfilingDumps/

# macOS
.DS_Store

# Editor
.vscode/
.idea/

# Ruby/Rails safety: Telluric must not vendor or alter Ruby deps
.bundle/
vendor/bundle/
Gemfile.lock
```

Note : si un jour Telluric contient volontairement un outil Ruby, cette section devra être revue explicitement. Par défaut, Telluric ne doit pas être un projet Ruby.

---

## 13. Gestion des dépendances

Par défaut, Telluric doit éviter les dépendances externes.

Priorité :

```text
Swift standard library
Foundation
simd
Metal / MetalKit uniquement dans RenderCoreMetal
GameController uniquement dans RuntimeApp
AVFoundation uniquement dans AudioRuntime si nécessaire
```

Toute nouvelle dépendance doit être justifiée par :

```text
1. Pourquoi elle est nécessaire
2. Pourquoi elle ne peut pas être codée simplement en interne
3. Impact déterminisme
4. Impact performance
5. Impact build
6. Impact environnement local
7. Alternative sans dépendance
```

Codex ne doit jamais ajouter une dépendance externe automatiquement.

---

## 14. Règles spécifiques aux idées inspirées d’Unreal/NVIDIA/autres moteurs

Codex peut s’inspirer de concepts externes, mais ne doit pas copier l’architecture.

Adaptations Telluric attendues :

| Concept externe | Version Telluric attendue |
|---|---|
| Mesh Terrain | `Terrain Mesh Forge` hybride fields + SDF + mesh chunké |
| World Partition | `World Residency Graph`, topology-aware, prédictif, chunké |
| OFPA | `One Delta Per Entity`, `One Patch Per Region` |
| Procedural Vegetation Editor | `EcoGrowth Forge`, écologique, seedé, systémique |
| Nanite | `IVDS`, virtualisation Metal-first custom |
| PCG Graphs | `RecipeGraph IR`, versionné, déterministe, testable |

Codex doit toujours demander :

```text
Est-ce cohérent avec seed-first / deterministic-first / systemic-first ?
```

Si la réponse est non, l’idée doit être rejetée ou adaptée.

---

## 15. Règles de performance

Toute feature doit annoncer son budget approximatif :

```text
CPU
GPU
RAM
VRAM / residency GPU
I/O
latence de streaming
coût de génération chunk
```

Codex doit éviter :

- allocations massives par frame ;
- génération bloquante sur le main thread ;
- rebuild complet du monde pour une modification locale ;
- textures ou meshes géants non streamés ;
- structures orientées objets lourdes pour des millions d’entités ;
- usage non contrôlé de dictionnaires/sets dans les chemins chauds.

---

## 16. Règles de debug

Toute vertical slice doit inclure des debug views simples.

Priorités :

```text
Chunk grid
Chunk coord labels
Seed display
FPS / frame time
CPU generation time
GPU frame time
Loaded cells
Resident render clusters
Surface field debug
Biome weight debug
Collision debug
Vegetation density debug
```

Debug ne doit pas polluer `EngineCore` avec SwiftUI ou Metal.

---

## 17. Règles de documentation

Codex doit mettre à jour la documentation quand :

- un contrat public change ;
- une architecture change ;
- un script safe est ajouté/modifié ;
- une limitation est découverte ;
- une décision R&D est prise ;
- une phase de roadmap est complétée.

Docs prioritaires :

```text
TELLURIC_ENGINE_FINAL_ARCHITECTURE.md
Docs/ROADMAP.md
Docs/DECISIONS.md
Docs/SAFE_ENVIRONMENT.md
Docs/VALIDATION.md
```

---

## 18. Réponse attendue en cas de blocage

Si Codex rencontre un problème de toolchain, il ne doit pas proposer de commande globale.

Mauvaise réponse :

```text
Run sudo xcode-select --switch...
Run brew install...
Run bundle update...
```

Bonne réponse :

```text
Le script safe échoue.
Je ne modifie pas l’environnement global.
Voici le diagnostic local.
Voici les fichiers/scripts locaux concernés.
Voici une correction locale possible.
Voici ce que l’utilisateur doit vérifier manuellement si nécessaire.
```

---

## 19. Checklist avant modification

Avant toute modification, Codex doit vérifier mentalement :

```text
Est-ce local au repo ?
Est-ce que ça touche Ruby/Rails ?
Est-ce que ça touche Homebrew ?
Est-ce que ça touche xcode-select ?
Est-ce que ça écrit dans $HOME ?
Est-ce que ça respecte EngineCore pur ?
Est-ce déterministe ?
Est-ce testable ?
Est-ce compatible avec l’architecture finale ?
```

Si une réponse est dangereuse, Codex doit s’arrêter et proposer une alternative locale.

---

## 20. Résumé ultime pour Codex

```text
Tu travailles dans un repo Swift/Metal custom.
Tu ne touches jamais à l’environnement Ruby/Rails.
Tu ne changes jamais la toolchain globale.
Tu utilises uniquement des scripts safe locaux.
Tu gardes EngineCore pur et déterministe.
Tu sépares RenderCoreMetal, RuntimeApp et TelluricTools.
Tu testes les seeds, les chunks et les contrats.
Tu ne copies pas Unreal : tu adaptes les idées à Telluric.
Tu fais des petites étapes propres, documentées, validables.
```

---

## 21. Références utiles

- `TELLURIC_ENGINE_FINAL_ARCHITECTURE.md`
- `Docs/SAFE_ENVIRONMENT.md`
- `Docs/VALIDATION.md`
- Bundler configuration locale : https://bundler.io/man/bundle-config.1.html
- `xcode-select` / `DEVELOPER_DIR` : https://www.manpagez.com/man/1/xcode-select/
- `xcodebuild` usage : https://www.manpagez.com/man/1/xcodebuild/
