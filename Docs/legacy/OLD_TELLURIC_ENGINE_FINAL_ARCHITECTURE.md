# Telluric Engine — Architecture Finale de Référence

> **Document maître pour Codex, les agents IA et la conception long terme du moteur.**  
> **Version :** 0.1 — architecture cible consolidée  
> **Date :** 2026-06-19  
> **Statut :** document de vision technique, non figé, mais doit servir de boussole permanente.

---

## 0. Objet du document

Ce document centralise la vision finale du moteur **Telluric Engine** à partir des documents internes existants :

- `TELLURIC_BASE_SPECS.md`
- `TELLURIC_BIOME_TERRAIN_FORGE_ULTIMATE.md`
- `TELLURIC_MOTION_FORGE_ULTIMATE.md`
- `TELLURIC_PROCEDURAL_PARAMETRIC_AUDIO_ENGINE.md`
- `TELLURIC_METAL4_AI_ML_RPG_PIPELINE.md`

Les anciens noms `IsoWorld`, `IsoForge` ou `IsoForge Engine` doivent désormais être compris comme des noms historiques de travail. Le nom de référence est :

# **Telluric Engine**

Telluric Engine est un moteur de jeu custom orienté mondes procéduraux, déterministes, systémiques, haute qualité et performants, conçu en priorité pour Apple Silicon, Swift et Metal.

Ce document doit servir à :

1. garder une vision claire de l’architecture cible ;
2. guider Codex dans les choix d’implémentation ;
3. éviter les systèmes temporaires qui deviennent de la dette technique ;
4. maintenir la philosophie procédurale/déterministe du moteur ;
5. empêcher une simple copie d’Unreal, NVIDIA, Unity ou autres moteurs existants ;
6. structurer les futures phases de développement par vertical slices propres.

---

## 1. Philosophie non négociable

Telluric Engine ne doit pas devenir un “petit Unreal”.

Unreal est un moteur généraliste, editor-first, asset-heavy, pensé pour la production multi-plateforme et des workflows d’équipes larges. Telluric doit suivre une autre trajectoire :

```text
Telluric = seed-first + simulation-first + deterministic-first + systemic-first + Metal-first
```

La plus-value du moteur doit venir de sa capacité à générer des mondes :

- procéduraux ;
- déterministes ;
- cohérents géologiquement, écologiquement, hydrologiquement et topologiquement ;
- streamés autour du joueur ;
- compatibles avec une verticalité réelle ;
- liés au gameplay, au mouvement, à l’audio, aux matériaux et aux systèmes RPG ;
- performants via une architecture data-oriented, chunkée, virtualisée et profilée.

### 1.1 Règles absolues

1. **La seed est la vérité de départ.**  
   Le monde ne doit pas être stocké comme une scène géante d’objets sérialisés. Il doit être reconstructible à partir de seeds, recettes, versions de générateurs et deltas.

2. **EngineCore reste pur.**  
   Pas de SwiftUI, pas de Metal, pas d’API plateforme lourde dans le cœur logique déterministe.

3. **RenderCoreMetal reste séparé.**  
   Le rendu, la residency GPU, les shaders, le RenderGraph et les captures Metal vivent dans une couche distincte.

4. **Les tools ne doivent pas polluer le runtime.**  
   Les labs, éditeurs, viewers, validators et outils d’analyse vivent dans `TelluricTools`, pas dans l’app runtime.

5. **Pas de preview system permanent.**  
   Une slice minimale peut être simple, mais elle doit déjà respecter les contrats finaux.

6. **Pas de génération non testable.**  
   Tout système procédural doit être seedé, versionné, hashable, validable et comparable.

7. **Le ML n’est jamais autoritaire.**  
   Les modèles peuvent scorer, proposer, reformuler, compresser ou aider l’authoring. Ils ne doivent pas modifier seuls la vérité du monde.

8. **Un système visuel doit avoir une signification monde.**  
   Terrain, surface, végétation, audio, animation et gameplay doivent lire une vérité commune du monde.

---

## 2. Références externes et positionnement

Ce document tient compte des nouveautés Unreal Engine 5.8, notamment :

- Mesh Terrain ;
- World Partition ;
- One File Per Actor ;
- Procedural Vegetation Editor ;
- PCG, graphes et subgraphs ;
- virtualisation géométrique type Nanite ;
- workflows LLM/MCP et sandboxes.

Ces technologies ne doivent pas être copiées. Elles servent à identifier des problèmes réels de moteurs modernes : monde massif, streaming, authoring, terrain 3D, végétation complexe, collaboration, tooling et performances.

### 2.1 Ce que Telluric retient d’Unreal

| Technologie Unreal | Problème réel identifié | Adaptation Telluric |
|---|---|---|
| Mesh Terrain | Les heightfields 2.5D limitent tunnels, arches, surplombs et falaises | `Terrain Mesh Forge`, hybride fields + SDF + mesh chunké |
| World Partition | Les mondes ouverts nécessitent streaming, cellules, HLOD, debug | `World Residency Graph`, basé sur chunks, régions, prédiction et sémantique |
| OFPA | La collaboration nécessite des unités modifiables séparées | `One Delta Per Entity`, `One Patch Per Region`, pas une scène d’acteurs sérialisés |
| PVE | La végétation doit être générative, naturelle, variée et optimisée | `EcoGrowth Forge`, espèces, micro-habitats, croissance, état vivant |
| PCG Subgraphs | Les graphes doivent être réutilisables et encapsuler la complexité | `RecipeGraph IR`, graphes compilés, versionnés, seedés |
| Nanite | Les détails massifs exigent virtualisation et culling | `IVDS`, virtualisation custom Metal-first |
| MCP / LLM tools | Les agents IA peuvent aider à construire, tester, refactorer | `Agentic Validation`, pas d’autonomie non contrôlée |

### 2.2 Ce que Telluric refuse

Telluric refuse :

- le monde comme collection centrale d’acteurs sauvegardés ;
- l’éditeur comme cœur du moteur ;
- les assets comme vérité principale ;
- les systèmes temporaires non testables ;
- une copie de Nanite ou de PVE ;
- un LLM qui décide du gameplay ;
- un runtime gonflé par les outils.

---

## 3. Architecture globale cible

```text
TelluricEngine/
├── EngineCore/
│   ├── Determinism/
│   ├── Math/
│   ├── Coordinates/
│   ├── WorldDNA/
│   ├── Fields/
│   ├── Chunks/
│   ├── TerrainForge/
│   ├── BiomeForge/
│   ├── Hydrology/
│   ├── SurfaceForge/
│   ├── Ecology/
│   ├── EcoGrowthForge/
│   ├── Props/
│   ├── Settlements/
│   ├── MotionCore/
│   ├── AudioCore/
│   ├── RPGCore/
│   ├── AIModelCore/
│   ├── Persistence/
│   ├── Simulation/
│   └── Validation/
│
├── RenderCoreMetal/
│   ├── Device/
│   ├── RenderGraph/
│   ├── ResourceGraph/
│   ├── PipelineCache/
│   ├── ShaderLibrary/
│   ├── TerrainRenderer/
│   ├── SurfaceRenderer/
│   ├── VegetationRenderer/
│   ├── PropRenderer/
│   ├── CharacterRenderer/
│   ├── VirtualGeometry/
│   ├── TextureResidency/
│   ├── GPUCulling/
│   ├── Lighting/
│   ├── Atmosphere/
│   ├── DebugMarkers/
│   └── CaptureIntegration/
│
├── AudioRuntime/
│   ├── BackendApple/
│   ├── DSPGraphRuntime/
│   ├── ProceduralSynths/
│   ├── SpatialAudio/
│   ├── MusicRuntime/
│   └── AudioBudgeting/
│
├── TelluricTools/
│   ├── TerrainForgeLab/
│   ├── BiomeForgeLab/
│   ├── SurfaceForgeLab/
│   ├── EcoGrowthLab/
│   ├── MotionForgeLab/
│   ├── AudioGraphLab/
│   ├── RPGSimulationLab/
│   ├── SeedAuditLab/
│   ├── GoldenSeedRunner/
│   ├── ChunkStreamingProfiler/
│   ├── AssetValidator/
│   ├── ShaderCompilerTool/
│   └── AgenticBuildValidator/
│
├── RuntimeApp/
│   ├── AppShell/
│   ├── Loading/
│   ├── DebugWorld/
│   ├── RealWorld/
│   └── MinimalHUD/
│
├── Shaders/
├── Tests/
├── AssetManifests/
├── SamplesTiny/
├── LocalAssets/        # ignored by Git
└── Docs/
```

---

## 4. Repo et séparation des responsabilités

### 4.1 Nouveau repo propre

Le POC existant peut être conservé comme preuve et laboratoire, mais l’architecture finale doit vivre dans un repo propre.

Le POC sert à :

- valider des idées ;
- comparer les comportements ;
- récupérer certains tests ;
- relire les décisions ;
- éviter de perdre les specs.

Le repo final doit refuser :

- les noms `V1`, `V2`, `V3` dans le code ;
- les backends historiques ;
- les previews permanents ;
- les hacks de debug comme architecture ;
- les tools dans le runtime ;
- les features non testables ;
- les pipelines renderer sans lifetime clair des ressources.

### 4.2 Structure Git recommandée

```text
GitHub
  -> code, docs, shaders, tests, manifests

Git LFS minimal
  -> quelques textures/meshes de test uniquement

LocalAssets/
  -> gros assets non commités

AssetManifests/
  -> manifest, licence, hash, provenance, validation
```

---

## 5. EngineCore

`EngineCore` est le cœur logique déterministe du moteur.

Il contient :

- génération du monde ;
- simulation ;
- systèmes RPG ;
- contrats de surface ;
- contrats de mouvement ;
- contrats audio ;
- persistence ;
- validation ;
- hashing ;
- scheduling logique.

Il ne contient pas :

- Metal ;
- SwiftUI ;
- AVAudioEngine ;
- CoreML runtime direct ;
- code d’éditeur ;
- code de rendu ;
- code plateforme non abstrait.

### 5.1 Déterminisme

Chaque système procédural doit respecter :

```text
same seed + same generator versions + same inputs = same outputs
```

Les sorties importantes doivent être hashables :

```swift
struct GenerationHash: Hashable, Codable {
    let systemID: String
    let generatorVersion: SemanticVersion
    let seed: UInt64
    let inputHash: UInt64
    let outputHash: UInt64
}
```

### 5.2 Randomness

Aucune génération ne doit utiliser un RNG global implicite.

Chaque système reçoit un contexte :

```swift
struct RandomContext {
    let worldSeed: UInt64
    let systemSalt: UInt64
    let chunkCoord: ChunkCoord?
    let entityID: StableWorldID?
    let generatorVersion: SemanticVersion
}
```

---

## 6. WorldDNA

`WorldDNA` définit l’identité globale du monde.

```text
WorldSeed
  -> WorldGeoDNA
  -> WorldClimateDNA
  -> WorldBiomeDNA
  -> WorldHydrologyDNA
  -> WorldEcologyDNA
  -> WorldRPGDNA
  -> WorldAudioDNA
  -> WorldThemeDNA
```

Chaque DNA est compact, versionné et stable.

### 6.1 WorldGeoDNA

Décrit :

- amplitude du relief ;
- style géologique ;
- taux de verticalité ;
- fréquence des montagnes ;
- propension aux grottes ;
- type de côtes ;
- distribution des bassins ;
- tectonique simplifiée ;
- érosion globale.

### 6.2 WorldClimateDNA

Décrit :

- température moyenne ;
- gradients latitudinaux ;
- humidité ;
- vents dominants ;
- saisonnalité ;
- rain shadows ;
- événements météo extrêmes.

### 6.3 WorldBiomeDNA

Décrit :

- palette de biomes ;
- rareté des biomes ;
- transitions ;
- compatibilités ;
- écotones ;
- signatures visuelles et écologiques.

### 6.4 WorldHydrologyDNA

Décrit :

- densité de rivières ;
- probabilité de lacs ;
- nappes, marais, zones humides ;
- cascades ;
- ruissellement ;
- érosion hydraulique.

### 6.5 WorldEcologyDNA

Décrit :

- espèces dominantes ;
- densité végétale ;
- compétition ;
- fertilité ;
- vitesse de croissance ;
- régénération ;
- perturbations naturelles.

---

## 7. Field System — la vérité continue du monde

Telluric ne doit pas décider le monde chunk par chunk. Les chunks sont des fenêtres d’évaluation sur des champs continus.

```text
World fields first, chunks second.
```

Les champs principaux :

- altitude ;
- pente ;
- courbure ;
- humidité ;
- température ;
- exposition solaire ;
- distance à l’eau ;
- débit hydrologique ;
- type de sol ;
- densité végétale ;
- biome weights ;
- traversabilité ;
- danger ;
- occupation humaine ;
- perturbation ;
- acoustique locale.

### 7.1 Samples de champ

```swift
struct ClimateSample {
    let temperature: Float
    let humidity: Float
    let rainfall: Float
    let windVector: SIMD3<Float>
    let seasonalPhase: Float
}

struct GeoHydroSample {
    let altitude: Float
    let slope: Float
    let curvature: Float
    let waterFlow: Float
    let distanceToWater: Float
    let erosion: Float
}

struct SurfaceContextSample {
    let biomeWeights: BiomeWeights
    let soilType: SoilType
    let moisture: Float
    let snowDepth: Float
    let mudDepth: Float
    let mossCoverage: Float
    let traversability: Float
    let audioMaterial: AudioMaterial
}
```

---

## 8. Terrain Mesh Forge

`Terrain Mesh Forge` est la réponse Telluric au problème moderne du terrain.

Il ne doit pas être un simple heightfield, ni une copie de Mesh Terrain Unreal. Il doit être un compilateur déterministe de topologie monde.

### 8.1 Objectif

Générer un terrain :

- 3D réel ;
- chunké ;
- streamable ;
- compatible verticalité ;
- compatible tunnels/grottes ;
- compatible surplombs/falaises ;
- compatible gameplay ;
- avec collision ;
- avec surface fields ;
- avec LOD/virtualisation ;
- sans seams.

### 8.2 Représentation hybride

```text
Macro Height/Field Layer
  + Terrain Feature Graph
  + Hydrology Graph
  + SDF Cave/Overhang Layer
  + Local Modifiers
  + Remesh/Tessellation Rules
  -> TerrainMeshPayload
```

Le moteur doit utiliser une représentation hybride :

1. champs continus pour le macro-relief ;
2. graphes de features pour montagnes, vallées, ravins, falaises ;
3. hydrologie pour rivières, lacs, cascades, érosion ;
4. SDF/volumes pour grottes, tunnels, arches, surplombs ;
5. mesh compilation par chunk ;
6. résolution variable selon intérêt sémantique.

### 8.3 TerrainMeshPayload

```swift
struct TerrainMeshPayload {
    let chunkCoord: ChunkCoord
    let generatorVersion: SemanticVersion
    let vertices: [TerrainVertex]
    let indices: [UInt32]
    let bounds: AABB
    let surfacePayload: SurfacePayload
    let collisionPayload: TerrainCollisionPayload
    let renderPayloadHint: RenderPayloadHint
    let hash: GenerationHash
}
```

### 8.4 Résolution adaptative sémantique

La résolution ne doit pas dépendre uniquement de la distance caméra.

```text
ResolutionScore =
  cameraProximity
+ gameplayImportance
+ slopeComplexity
+ hydrologyComplexity
+ caveEntrancePresence
+ settlementDensity
+ combatLikelihood
+ biomeTransitionSharpness
+ playerPathPrediction
```

### 8.5 TerrainModifier

Les modifications locales doivent être non destructives, seedées, versionnées et rejouables.

```swift
struct TerrainModifier {
    let stableID: ModifierID
    let kind: TerrainModifierKind
    let bounds: WorldBounds
    let priority: TerrainLayerPriority
    let seed: UInt64
    let version: SemanticVersion
}
```

Exemples :

- route ;
- grotte custom ;
- ruine ;
- pont ;
- terrassement ;
- cratère ;
- effondrement ;
- ravin ;
- biome scar ;
- intervention joueur persistante.

---

## 9. Biome Forge

`Biome Forge` résout les biomes, sous-biomes, écotones et micro-habitats.

Un biome ne doit jamais être une simple texture ou un ID par chunk.

```text
Biome = climate + topology + hydrology + soil + ecology + history + disturbance
```

### 9.1 Biome weights

Chaque point du monde peut avoir plusieurs poids de biome.

```swift
struct BiomeWeights {
    let primary: BiomeID
    let weights: [BiomeID: Float]
    let ecotoneStrength: Float
}
```

Pourquoi garder plusieurs poids :

- transitions naturelles ;
- matériaux mélangés ;
- végétation hybride ;
- audio progressif ;
- météo locale ;
- gameplay plus subtil.

### 9.2 Écotones

Les écotones sont des transitions naturelles entre biomes.

Ils doivent dépendre de :

- compatibilité des biomes ;
- pente ;
- humidité ;
- altitude ;
- type de sol ;
- distance à l’eau ;
- exposition ;
- perturbation ;
- échelle régionale.

### 9.3 Micro-habitats

Exemples :

- pied humide de falaise ;
- crête sèche exposée au vent ;
- rive boueuse ;
- clairière ;
- sous-bois dense ;
- entrée de grotte ;
- talus rocheux ;
- zone brûlée ;
- ruine envahie par la végétation.

Ces micro-habitats alimentent végétation, props, audio, animation, FX et gameplay.

---

## 10. Surface Truth Layer / Surface Forge

`Surface Forge` est une couche centrale.

La surface n’est pas seulement un matériau visuel. Elle est la signification locale du sol et des objets.

```text
Geometry says: here is the shape.
Surface says: here is what this place means.
```

### 10.1 SurfacePayload

```swift
struct SurfacePayload {
    let chunkCoord: ChunkCoord
    let materialWeights: MaterialWeightMap
    let physicalSurfaceMap: PhysicalSurfaceMap
    let audioSurfaceMap: AudioSurfaceMap
    let traversalMap: TraversalMap
    let vegetationSuitabilityMap: VegetationSuitabilityMap
    let weatherInteractionMap: WeatherInteractionMap
}
```

### 10.2 Usages

La même surface doit nourrir :

- matériaux PBR ;
- shader blending ;
- pas procéduraux ;
- traces ;
- glissade ;
- boue ;
- poussière ;
- neige ;
- végétation ;
- IA ;
- Motion Forge ;
- particules ;
- météo ;
- gameplay RPG.

### 10.3 Living Materials

Les matériaux doivent pouvoir évoluer :

- humidité ;
- mousse ;
- neige ;
- poussière ;
- cendres ;
- boue ;
- usure ;
- brûlure ;
- passage répété ;
- corruption/magie/faction.

---

## 11. EcoGrowth Forge

`EcoGrowth Forge` est la réponse Telluric à la végétation procédurale.

Il ne doit pas seulement “placer des arbres”. Il doit résoudre une écologie locale cohérente.

### 11.1 Pipeline

```text
BiomeForge
  -> MicroHabitat Resolver
  -> Species Suitability Field
  -> EcoGrowth Simulation
  -> Plant Architecture Generator
  -> Mesh/Skeleton/Wind Payload
  -> Placement + Interaction + Decay
```

### 11.2 SpeciesDNA

```swift
struct SpeciesDNA {
    let speciesID: SpeciesID
    let climateRange: ClimateRange
    let soilPreferences: SoilPreferences
    let waterDependency: Float
    let shadeTolerance: Float
    let competitionStrategy: CompetitionStrategy
    let growthPattern: GrowthPattern
    let branchGrammar: BranchGrammar
    let windResponse: WindProfile
    let gameplayTags: Set<GameplayTag>
}
```

### 11.3 Placement écologique

```text
PlacementProbability =
  speciesSuitability
- competitionPressure
+ waterAccess
+ soilAffinity
+ shadeCompatibility
- slopePenalty
+ disturbanceResponse
+ microHabitatBonus
```

### 11.4 Living Vegetation State

Toutes les plantes ne doivent pas être persistées individuellement.

- herbes, petits buissons, végétation distante : stateless, régénérés par seed ;
- arbres importants, plantes gameplay, ressources récoltées : état persistant léger.

```swift
struct VegetationState {
    let stableID: StableWorldID
    var age: Float
    var health: Float
    var hydration: Float
    var seasonPhase: Float
    var damage: DamageState
    var burned: Bool
    var harvested: Bool
}
```

### 11.5 R&D propre Telluric

Telluric doit pousser plus loin que les outils classiques :

- forêts qui influencent visibilité, audio et IA ;
- saisons qui changent réellement les surfaces et sons ;
- incendies dépendant humidité/vent/densité ;
- végétation qui colonise ruines et perturbations ;
- arbres proches avec squelettes/vent avancé ;
- végétation distante en HLOD sémantique.

---

## 12. World Residency Graph

Le monde doit être streamé autour du joueur, mais pas par simple grille naïve.

### 12.1 Niveaux séparés

```text
World Region      = macro zone : vallée, bassin, massif, côte
Streaming Cell    = unité de residency mémoire
Simulation Chunk  = unité de génération déterministe
Render Cluster    = unité GPU / culling / LOD
```

Ces quatre niveaux ne doivent pas être confondus.

### 12.2 Priorité de residency

```text
ResidencyPriority =
  distanceToPlayer
+ cameraDirection
+ playerVelocity
+ predictedPath
+ visibilityPotential
+ questImportance
+ roadRiverConnectivity
+ combatRisk
+ teleportOrFastTravelTarget
+ audioImportance
```

### 12.3 États d’un chunk

```text
Unseen
  -> Requested
  -> Generating
  -> GeneratedCPU
  -> UploadingGPU
  -> ResidentGPU
  -> Active
  -> CoolingDown
  -> EvictedGPU
  -> CachedCPU
```

### 12.4 Anti-thrashing

Le moteur doit éviter de charger/décharger en boucle.

Règles :

- hysteresis ;
- cooldown ;
- prediction ;
- budget mémoire ;
- limite d’uploads par frame ;
- priorité explicite ;
- debug view obligatoire.

---

## 13. Persistence — Seed + Versions + Deltas

Le moteur ne doit pas sauvegarder le monde complet.

```text
SavedWorld = worldSeed + generatorVersions + playerState + deltas + ledger
```

### 13.1 Delta-first Save System

```swift
struct WorldDelta {
    let targetStableID: StableWorldID
    let operation: WorldOperation
    let timestamp: WorldTick
    let payload: DeltaPayload
    let source: DeltaSource
}
```

Exemples :

```text
tree_4392 cut
rock_882 moved
soil_patch_12 burned
bridge_2 built
cave_wall_19 destroyed
npc_faction_7 relation changed
quest_seed_42 resolved
```

### 13.2 One Delta Per Entity / One Patch Per Region

Telluric doit reprendre l’idée de collaboration fine d’OFPA, mais pas le modèle “acteur fichier”.

Pour les outils :

- un fichier par recipe ;
- un fichier par patch régional ;
- un fichier par modifier ;
- un fichier par species profile ;
- un fichier par graph audio/motion/biome.

Pour le runtime :

- seed + versions + deltas ;
- aucun besoin de sauver chaque instance générée.

---

## 14. IVDS — Iso/Telluric Virtual Detail System

`IVDS` est la virtualisation de détail Telluric.

Il est inspiré conceptuellement par Nanite, mais doit rester custom, Metal-first, chunk-aware et sémantique.

### 14.1 Objectif

Rendre de très grandes quantités de détails :

- terrain ;
- rochers ;
- falaises ;
- props ;
- végétation ;
- ruines ;
- objets naturels ;
- détails de surface.

### 14.2 Principes

- clusters GPU ;
- culling hiérarchique ;
- LOD continu ou discret ;
- streaming de ressources ;
- HLOD ;
- impostors ;
- budgets stricts ;
- debug visible ;
- liens avec World Residency.

### 14.3 Semantic HLOD

Un HLOD Telluric ne doit pas être seulement un mesh simplifié.

Il peut contenir :

```text
visual proxy
collision proxy
audio proxy
biome proxy
AI traversal proxy
weather interaction proxy
```

Exemple : une forêt distante peut devenir :

- volume visuel ;
- silhouettes d’arbres ;
- occlusion audio ;
- densité écologique ;
- coût de traversée IA ;
- influence météo.

---

## 15. RenderCoreMetal

`RenderCoreMetal` est la couche rendu Apple-native.

### 15.1 Principes

- Metal-first ;
- RenderGraph natif dès le départ ;
- ResourceGraph et lifetime explicites ;
- pipeline cache ;
- shader cache ;
- debug markers ;
- capture/profiling via outils Apple ;
- aucun overlay SwiftUI lourd en runtime ;
- séparation stricte du logique et du rendu.

### 15.2 RenderGraph

```text
FrameInput
  -> WorldVisibility
  -> GPUCulling
  -> TerrainPass
  -> VegetationPass
  -> PropPass
  -> CharacterPass
  -> ShadowPasses
  -> Lighting
  -> Atmosphere/Fog
  -> PostFX
  -> DebugOverlays
  -> Present
```

### 15.3 ResourceGraph

Chaque ressource GPU doit avoir :

- owner ;
- lifetime ;
- residency state ;
- memory budget ;
- upload path ;
- eviction policy ;
- debug label ;
- frame usage.

### 15.4 Rendu terrain

Le renderer terrain doit consommer `TerrainMeshPayload` et `SurfacePayload`, pas recalculer la logique monde.

### 15.5 Rendu végétation

Le renderer végétation doit supporter :

- instancing ;
- GPU culling ;
- wind shader ;
- LOD ;
- impostors ;
- skeleton optionnel pour arbres proches ;
- variation déterministe ;
- liens avec EcoGrowth.

### 15.6 Lighting

Objectif long terme : monde dynamique et crédible, mais budgets réalistes.

Priorités :

1. lumière directionnelle stable ;
2. ombres terrain/végétation ;
3. ambient/sky model ;
4. probes/irradiance fields custom ;
5. fog/atmosphere ;
6. éclairage local optimisé ;
7. options de qualité progressives.

---

## 16. Motion Forge

`Motion Forge` est le système d’animation procédurale/world-aware.

Il ne doit pas être une simple forêt de clips et de blend trees.

```text
Player Input / AI / World Event / Smart Object
        -> MotionIntent
        -> Motion Planner + Primitive Resolver
        -> Smart Primitive / Latent Motion / Contact Plan
        -> Pose Generator + Warping + IK + Physics Correction
        -> AnimationFrameSnapshot
        -> Metal GPU Skinning + FX + Audio + Gameplay
```

### 16.1 Principes

- intent-driven ;
- contact-aware ;
- world-aware ;
- physics-informed ;
- deterministic decisions ;
- runtime Apple-native ;
- ML uniquement borné et validé ;
- tools séparés du runtime.

### 16.2 Motion Context

Motion Forge doit lire :

- pente ;
- surface ;
- humidité ;
- boue ;
- neige ;
- type de sol ;
- obstacles ;
- props ;
- smart objects ;
- danger ;
- hauteur de marche ;
- stabilité du sol.

### 16.3 Smart Primitives

Exemples :

- marche ;
- course ;
- saut ;
- escalade ;
- franchissement ;
- glissade ;
- interaction porte/coffre ;
- ramassage ;
- attaque ;
- esquive ;
- chute ;
- nage ;
- traversée de boue/neige/eau.

---

## 17. Audio Procedural Engine

Le moteur audio Telluric doit être un système procédural/paramétrique world-aware.

Il ne doit pas être seulement un lecteur de samples.

### 17.1 Architecture

```text
AudioCore contracts in EngineCore
  -> AudioEvent
  -> AudioRecipe
  -> AudioGraph
  -> DSP Runtime
  -> Apple Backend
  -> Spatialization / Mix / Output
```

### 17.2 Principes

- Core Audio / AVAudioEngine / Audio Unit / PHASE comme backend possible ;
- cœur DSP custom ;
- zéro allocation dans le thread audio temps réel ;
- graphes audio data-driven ;
- paramètres monde ;
- variations déterministes ;
- LOD audio ;
- budgets CPU stricts.

### 17.3 World-aware audio

Un son doit pouvoir dépendre de :

- matériau ;
- humidité ;
- pente ;
- météo ;
- biome ;
- sous-biome ;
- heure ;
- saison ;
- densité végétale ;
- altitude ;
- cavité ;
- occlusion ;
- vitesse de l’objet ;
- masse ;
- fatigue ;
- tension RPG.

### 17.4 Synthèses prioritaires

- FootstepSynth ;
- ImpactSynth ;
- FrictionSynth ;
- NatureSynth ;
- WeatherAudioSystem ;
- AmbienceSystem ;
- CreatureVoiceSynth ;
- MusicSystem procédural.

---

## 18. RPGCore et AIModelCore

Telluric peut intégrer du ML, mais uniquement avec garde-fous.

### 18.1 Rôle autorisé du ML

Le ML peut :

- scorer une quête ;
- proposer une variation ;
- reformuler un dialogue ;
- classifier un lieu ;
- auditer une seed ;
- détecter une incohérence ;
- compresser une représentation ;
- aider l’authoring offline.

Le ML ne doit pas :

- décider seul d’un état monde ;
- modifier les deltas sans validator ;
- générer une quête canonique sans règles ;
- rendre une partie non reproductible ;
- remplacer les systèmes déterministes.

### 18.2 Pattern recommandé

```text
Deterministic system
  -> stable compact snapshot
  -> model proposal/scoring
  -> deterministic validator
  -> accepted decision
  -> WorldStateLedger / SaveDelta
```

### 18.3 Modèles utiles

Priorité possible :

1. `QuestCoherenceScorer`
2. `NPCIntentModel`
3. `DialogueStyleRewriter`
4. `FactionReactionScorer`
5. `SeedQualityAuditor`
6. `NarrativePlaceClassifier`
7. `RuntimeSimilarityEmbedding`

---

## 19. Tools et Labs

Telluric doit être tools-first, mais runtime-light.

### 19.1 Labs prioritaires

```text
TerrainForgeLab        -> inspecter relief, chunks, seams, SDF, hydrologie
BiomeForgeLab          -> biomes, sous-biomes, écotones, micro-habitats
SurfaceForgeLab        -> matériaux, audio surfaces, traversabilité
EcoGrowthLab           -> espèces, végétation, densité, compétition
MotionForgeLab         -> intents, contacts, primitives, IK, locomotion
AudioGraphLab          -> recettes audio, graphes DSP, variations
RPGSimulationLab       -> factions, quêtes, PNJ, storylets
SeedAuditLab           -> qualité de monde par seed
GoldenSeedRunner       -> tests visuels/perf/déterminisme
ChunkStreamingProfiler -> residency, uploads, cache, thrashing
```

### 19.2 Agentic Build Validation

Codex et les agents doivent pouvoir lancer des validations reproductibles.

```text
generate seed A/B/C
compile 25 chunks
check seams
check collision
check vegetation density
check surface maps
capture frame
compare performance budget
export debug report
```

---

## 20. Validation et Golden Seeds

Chaque système majeur doit avoir des golden seeds.

### 20.1 Tests obligatoires

- déterminisme exact ;
- absence de seams terrain ;
- continuité biomes/écotones ;
- stabilité hydrologie ;
- collision raisonnable ;
- pas de chunk thrashing ;
- budgets mémoire ;
- budgets CPU ;
- budgets GPU ;
- densité végétale bornée ;
- audio sans allocations runtime ;
- sauvegarde/deltas reproductibles.

### 20.2 Golden Seeds proposées

```text
SEED_FLATLAND_BASELINE
SEED_MOUNTAIN_VERTICALITY
SEED_RIVER_VALLEY
SEED_COASTAL_COMPLEX
SEED_CAVE_SYSTEM
SEED_DENSE_FOREST
SEED_SNOW_MOUNTAIN
SEED_DESERT_CANYON
SEED_SETTLEMENT_EDGE
SEED_STRESS_STREAMING
```

---

## 21. Performance budgets initiaux

Les budgets devront évoluer, mais Codex doit toujours raisonner en budget.

### 21.1 CPU

- génération chunk async ;
- aucune génération lourde sur le thread frame principal ;
- jobs annulables ;
- caches par système ;
- hashing et métriques.

### 21.2 GPU

- uploads limités par frame ;
- RenderGraph explicite ;
- culling avant draw ;
- virtualisation progressive ;
- debug markers ;
- pipeline cache.

### 21.3 Mémoire

- budget cellules résidentes ;
- budget textures ;
- budget meshes ;
- budget audio ;
- eviction policy ;
- outils de visualisation.

### 21.4 Audio

- aucune allocation dans callback audio ;
- graphes précompilés ;
- LOD audio ;
- nombre de sources borné ;
- synthèses lourdes pré-rendues si nécessaire.

---

## 22. Data contracts essentiels

### 22.1 ChunkCoord

```swift
struct ChunkCoord: Hashable, Codable {
    let x: Int32
    let y: Int32
    let z: Int32
    let lod: UInt8
}
```

### 22.2 StableWorldID

```swift
struct StableWorldID: Hashable, Codable {
    let namespace: String
    let seedPath: UInt64
    let localIndex: UInt32
    let generatorVersion: SemanticVersion
}
```

### 22.3 ChunkPayload

```swift
struct ChunkPayload {
    let coord: ChunkCoord
    let terrain: TerrainMeshPayload
    let surface: SurfacePayload
    let biome: BiomePayload
    let vegetation: VegetationPayload
    let props: PropPayload
    let audio: AudioEnvironmentPayload
    let motion: MotionContextPayload
    let hash: GenerationHash
}
```

### 22.4 FrameWorldSnapshot

```swift
struct FrameWorldSnapshot {
    let visibleChunks: [ChunkCoord]
    let activeEntities: [EntitySnapshot]
    let playerContext: PlayerContext
    let weatherContext: WeatherContext
    let audioContext: AudioFrameContext
    let motionContext: MotionFrameContext
    let renderHints: RenderFrameHints
}
```

---

## 23. Pipeline monde par frame

```text
Input / AI / Simulation Events
  -> Update WorldStateLedger
  -> Predict Player Movement
  -> World Residency Graph
  -> Request Missing Chunks
  -> Async Generate ChunkPayloads
  -> Validate / Hash
  -> Upload Render Payloads
  -> Build FrameWorldSnapshot
  -> Motion Forge
  -> Audio Event Graph
  -> RenderGraph
  -> Present
```

---

## 24. Pipeline génération chunk

```text
ChunkCoord
  -> Evaluate World Fields
  -> Terrain Feature Graph
  -> Hydrology Solver
  -> SDF / Cave / Overhang Layer
  -> Terrain Mesh Compiler
  -> Surface Field Compiler
  -> Biome / Ecotone Resolver
  -> EcoGrowth Placement
  -> Prop Placement
  -> Collision Payload
  -> Audio Environment Payload
  -> Motion Context Payload
  -> Hash + Validation
```

---

## 25. Roadmap par vertical slices

### Phase 0 — Repo propre et contrats

Objectif : poser la structure finale sans dette.

À faire :

- créer repo Telluric propre ;
- créer modules vides mais bien nommés ;
- définir `EngineCore`, `RenderCoreMetal`, `RuntimeApp`, `TelluricTools` ;
- ajouter tests déterminisme ;
- ajouter golden seeds ;
- ajouter conventions Codex ;
- ajouter ce document dans `/Docs`.

### Phase 1 — World Core minimal

- seed ;
- coordonnées ;
- chunks ;
- RNG déterministe ;
- fields simples ;
- terrain minimal ;
- hash payload ;
- tests.

### Phase 2 — RenderCoreMetal minimal final-compatible

- fenêtre runtime ;
- device Metal ;
- RenderGraph minimal ;
- pipeline cache ;
- terrain mesh simple ;
- debug chunks ;
- capture labels.

### Phase 3 — Terrain Mesh Forge v0

- height/field terrain ;
- mesh par chunk ;
- normals ;
- collision simple ;
- seam tests ;
- surface payload minimal.

### Phase 4 — World Residency Graph

- streaming autour joueur ;
- cache CPU ;
- upload GPU ;
- eviction ;
- anti-thrashing ;
- debug view.

### Phase 5 — Biome + Surface Forge

- climate fields ;
- biome weights ;
- écotones ;
- material weights ;
- audio surfaces ;
- traversability.

### Phase 6 — EcoGrowth v0

- species DNA ;
- vegetation placement ;
- instancing ;
- wind simple ;
- LOD simple ;
- density validation.

### Phase 7 — Motion Forge v0

- MotionIntent ;
- terrain context ;
- foot placement simple ;
- locomotion surface-aware ;
- animation snapshot.

### Phase 8 — Audio Engine v0

- AudioEvent ;
- AudioRecipe ;
- FootstepSynth minimal ;
- ambience biome ;
- backend Apple ;
- deterministic variation.

### Phase 9 — Persistence / Deltas

- SaveDelta ;
- WorldStateLedger ;
- entity IDs ;
- replay hash ;
- compatibility tests.

### Phase 10 — R&D avancée

- SDF caves ;
- adaptive terrain resolution ;
- semantic HLOD ;
- procedural settlements ;
- advanced vegetation growth ;
- RPG systems ;
- bounded ML tools.

---

## 26. Codex Operating Contract

Codex doit suivre ce contrat à chaque intervention.

### 26.1 Toujours faire

- lire ce document avant de proposer une architecture ;
- préserver la séparation `EngineCore` / `RenderCoreMetal` / `Tools` / `RuntimeApp` ;
- ajouter ou mettre à jour les tests ;
- préserver le déterminisme ;
- préférer les contrats stables aux hacks ;
- documenter les décisions ;
- ajouter des debug views propres ;
- raisonner en budgets ;
- refuser les systèmes temporaires qui contredisent l’architecture cible.

### 26.2 Ne jamais faire

- mettre Metal dans `EngineCore` ;
- mettre SwiftUI lourd dans le runtime ;
- créer un système `V2`, `V3`, `NewNewRenderer` ;
- sauvegarder le monde entier comme scène sérialisée ;
- utiliser un RNG global ;
- introduire un modèle ML autoritaire ;
- copier une architecture Unreal/NVIDIA sans adaptation ;
- ajouter un outil dans le runtime ;
- ignorer les tests de déterminisme ;
- casser l’environnement Ruby/Rails local.

### 26.3 Format de réponse attendu de Codex

Pour toute grosse implémentation, Codex doit répondre avec :

```text
1. Objectif exact
2. Fichiers à modifier
3. Nouveaux contrats ajoutés
4. Tests ajoutés
5. Impact déterminisme
6. Impact performance
7. Risques
8. Étapes d’implémentation
9. Commandes de validation
10. Documentation mise à jour
```

---

## 27. Principes R&D propres à Telluric

### 27.1 Topology-Aware World Partition

Partitionner par grille ne suffit pas.

Telluric doit intégrer :

- bassins hydrologiques ;
- vallées ;
- grottes ;
- routes ;
- lignes de visibilité ;
- zones gameplay ;
- régions écologiques.

### 27.2 Surface Truth Layer

Chaque point du monde doit pouvoir répondre :

```text
What am I?
wet mossy rock / dry gravel / muddy grass / snow crust / ash / shallow water / root-covered soil
```

Cette réponse doit être partagée par rendu, audio, motion, IA et gameplay.

### 27.3 Eco-Differentiable Placement

Pas besoin de ML lourd pour une végétation crédible.

Un solveur écologique déterministe peut déjà produire une qualité forte :

```text
species suitability
- competition
- shade
- water distance
- slope
- soil
- altitude
- wind exposure
- disturbance
= placement probability
```

### 27.4 Semantic HLOD

Réduire un objet lointain ne veut pas dire supprimer sa signification.

Une forêt lointaine doit encore exister pour :

- l’occlusion audio ;
- l’IA ;
- la météo ;
- les silhouettes ;
- le gameplay régional.

### 27.5 Agentic Validation

Le moteur doit être conçu pour être audité par agents :

- capture automatique ;
- rapports de seeds ;
- comparaison de hashes ;
- visualisation de budgets ;
- détection de seams ;
- recommandations non destructives.

---

## 28. Non-objectifs immédiats

Ne pas commencer par :

- un éditeur complet ;
- un clone de Nanite ;
- un clone de PVE ;
- un système RPG massif ;
- un LLM runtime ;
- une simulation physique complète ;
- un système de destruction avancé ;
- des assets AAA lourds ;
- une UI outil trop ambitieuse.

Commencer par :

- contrats ;
- déterminisme ;
- chunks ;
- fields ;
- terrain mesh minimal ;
- render graph ;
- debug ;
- tests ;
- budgets.

---

## 29. Résumé ultime

Telluric Engine doit être un moteur :

```text
procédural
+ déterministe
+ systémique
+ world-aware
+ surface-aware
+ chunk-streamed
+ Metal-first
+ toolable
+ testable
+ agent-auditable
```

La promesse n’est pas seulement de générer des cartes différentes.

La promesse est de générer des mondes cohérents où :

- le terrain influence les biomes ;
- les biomes influencent la végétation ;
- les surfaces influencent l’audio et le mouvement ;
- la météo transforme les matériaux ;
- les actions du joueur deviennent des deltas ;
- les systèmes RPG lisent l’état réel du monde ;
- le rendu reste performant grâce à la residency et à la virtualisation ;
- chaque seed peut être rejouée, auditée et améliorée.

La vision finale :

# **Telluric Engine — un moteur de mondes vivants, déterministes et systémiques.**

---

## 30. Références internes consolidées

- `TELLURIC_BASE_SPECS.md`
- `TELLURIC_BIOME_TERRAIN_FORGE_ULTIMATE.md`
- `TELLURIC_MOTION_FORGE_ULTIMATE.md`
- `TELLURIC_PROCEDURAL_PARAMETRIC_AUDIO_ENGINE.md`
- `TELLURIC_METAL4_AI_ML_RPG_PIPELINE.md`

---

## 31. Références externes utiles

- Unreal Engine 5.8 — announcement: https://www.unrealengine.com/news/unreal-engine-5-8-is-now-available
- Unreal Engine 5.8 — Mesh Terrain documentation: https://dev.epicgames.com/documentation/unreal-engine/mesh-terrain-in-unreal-engine
- Unreal Engine 5.8 — World Partition documentation: https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine
- Unreal Engine 5.8 — Procedural Vegetation Editor documentation: https://dev.epicgames.com/documentation/unreal-engine/procedural-vegetation-editor-pve-in-unreal-engine
- Apple Metal developer portal: https://developer.apple.com/metal/

