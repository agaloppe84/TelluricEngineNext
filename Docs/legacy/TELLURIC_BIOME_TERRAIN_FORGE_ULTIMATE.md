# IsoForge Engine — Biome Forge / Terrain Forge / World Ecology System

> **Document de référence pour Codex et pour la conception IsoWorld / IsoForge.**  
> Objectif : définir notre système ultime de biomes, sous-biomes, terrains, écotones, topologie, hydrologie, surfaces, props et streaming chunké, en reprenant les briques validées par le POC IsoWorld et en les intégrant proprement à l'architecture finale Metal 4 / procédurale / déterministe.

---

## 0. Résumé exécutif

IsoForge ne doit pas générer des mondes en choisissant simplement un biome par chunk, puis en posant une texture et quelques props. Ce modèle est trop pauvre, trop répétitif, et produit des frontières artificielles. La cible est un système **écologique**, **géologique**, **hydrologique**, **topologique**, **surface-aware**, **streamable**, **LOD-aware**, **déterministe**, capable de construire un monde autour du joueur par chunks tout en donnant l'impression d'un monde continu, naturel et cohérent.

Le système proposé s'appelle :

# **Biome Forge + Terrain Forge**

Il regroupe deux familles complémentaires :

1. **Terrain Forge** : génération de la topologie, des reliefs, de l'hydrologie, de l'érosion, des sols, de la verticalité, des features géologiques et des contraintes jouables.
2. **Biome Forge** : résolution des biomes, sous-biomes, micro-habitats, écotones, états écologiques, palettes de matériaux, densités de props, météo locale, faune et ambiance.

Le principe central :

```text
WorldSeed
  ↓
WorldGeoDNA + WorldClimateDNA + WorldBiomeDNA + WorldSurfaceDNA
  ↓
Continental / regional / local fields
  ↓
Terrain Feature Graph + Hydrology Graph + Climate Fields
  ↓
Topology-aware Biome Solver
  ↓
Sub-biome / Ecotone / Micro-habitat Resolver
  ↓
Chunk Terrain Payload + Biome Payload + Surface Payload + Prop Ecology Payload
  ↓
Streaming cache + LOD/Nanite-like virtualization + Surface Forge + Motion Forge
  ↓
Metal 4 RenderGraph + runtime gameplay + saves/deltas + tools validation
```

La règle absolue : **le terrain et les biomes ne sont jamais indépendants**. Un désert n'a pas le même relief qu'une toundra, une forêt humide n'a pas la même hydrologie qu'une steppe, une côte tropicale n'a pas les mêmes sous-biomes qu'une côte tempérée, et une montagne ne porte pas les mêmes biomes selon son altitude, sa pente, son exposition, son rain shadow, son sol et sa distance à l'eau.

---

## 1. Position dans l'architecture IsoForge ultime

### 1.1 Modules moteur concernés

```text
IsoForgeEngine/
├── EngineCore/
│   ├── Determinism/
│   ├── WorldDNA/
│   ├── Coordinates/
│   ├── Chunks/
│   ├── TerrainForge/
│   ├── BiomeForge/
│   ├── Hydrology/
│   ├── Ecology/
│   ├── Props/
│   ├── Settlements/
│   ├── SurfaceContracts/
│   ├── MotionContext/
│   └── PersistenceContracts/
├── RenderCoreMetal4/
│   ├── RenderGraph/
│   ├── TerrainRenderer/
│   ├── SurfaceRenderer/
│   ├── VirtualGeometry/
│   ├── TextureResidency/
│   └── DebugMarkers/
├── IsoTools/
│   ├── TerrainForgeLab/
│   ├── BiomeForgeLab/
│   ├── HydrologyLab/
│   ├── EcotoneDebugger/
│   ├── SurfaceForgeConnector/
│   ├── PropEcologyViewer/
│   ├── ChunkStreamingProfiler/
│   └── GoldenSeedValidator/
├── IsoAssets/
│   ├── Manifests/
│   ├── BiomeDefinitions/
│   ├── TerrainRecipes/
│   ├── SurfaceGraphs/
│   └── PropEcologyRules/
└── IsoRuntimeApp/
    ├── MainMenu/
    ├── LoadingPipeline/
    ├── DebugWorld/
    └── RealWorld/
```

### 1.2 Responsabilités strictes

`EngineCore` contient toutes les décisions déterministes : sélection biome, sous-biome, champs climatiques, hydrologie, topologie, contraintes terrain, payload chunk, stable IDs, versions et deltas. Il ne connaît ni SwiftUI, ni Metal, ni les outils graphiques.

`RenderCoreMetal4` consomme des snapshots et des payloads : mesh clusters, height samples, splat weights, material bindings, texture pages, debug views. Il ne décide pas quel biome existe, quelle rivière passe où, ou quel prop doit pousser à un endroit.

`IsoTools` édite, visualise, valide et exporte. Les outils peuvent avoir des previews GPU lourdes, mais le runtime réel doit rester léger.

`IsoAssets` stocke les définitions textuelles et manifests. Les gros assets PBR, meshes, packs runtime et caches peuvent vivre hors GitHub, référencés par manifest.

### 1.3 Relation avec les systèmes déjà proposés

```text
Terrain Forge
  → fournit hauteur, pente, courbure, hydrologie, verticalité, masks terrain

Biome Forge
  → fournit biome weights, sous-biomes, écotones, micro-habitats, états écologiques

Surface Forge
  → consomme terrain + biome + météo + deltas pour générer les matériaux PBR world-aware

Prop System
  → consomme biome/sub-biome/micro-habitat + terrain constraints pour placer végétation, rochers, débris, faune légère, ressources

Motion Forge
  → consomme TerrainSampleGrid + SurfaceState + BiomeTags pour contacts, marche, escalade, boue, neige, pentes, interactions

Nanite-like LOD / Virtual Geometry
  → consomme terrain/properties/features pour choisir clusters, HLOD, collision LOD, impostors et residency

Save System
  → persiste uniquement les deltas, mutations écologiques, overrides, caches reconstruisibles et versions
```

---

## 2. Principes non négociables

1. **Déterminisme complet des décisions de monde** : même seed + mêmes versions + mêmes deltas = même terrain, mêmes biomes, mêmes transitions, mêmes props candidats.
2. **Monde continu malgré les chunks** : les chunks sont une unité de streaming, pas une unité de vérité écologique.
3. **Topologie avant décor** : la forme du terrain, l'eau, les reliefs et les sols guident les biomes, pas l'inverse seul.
4. **Champs continus avant enums** : température, humidité, exposition, altitude, sol, distance à l'eau, perturbation, fertilité, salinité et saisonnalité sont des champs continus.
5. **Biomes pondérés, pas biome unique** : chaque sample peut contenir plusieurs influences de biomes et sous-biomes.
6. **Écotones explicites** : les zones de transition sont des entités à part entière, pas des artefacts de blending.
7. **Sous-biomes contextuels** : un biome contient des variations locales selon pente, eau, sol, altitude, ombre, perturbation, props voisins et civilisation.
8. **Hydrologie structurante** : rivières, lacs, marais, nappes, côtes, cascades et drainages organisent le monde.
9. **LOD et streaming conçus dès le départ** : le système sait produire low/mid/high fidelity sans changer de vérité monde.
10. **Cohérence avec Surface Forge** : biomes et terrains produisent directement les masques et états nécessaires aux matériaux procéduraux.
11. **Cohérence avec Motion Forge** : terrain/biome/surface exposent les informations de contact, friction, wetness, snow, mud, moss, danger.
12. **Outils de validation obligatoires** : aucun système de génération complexe sans debug views, golden seeds, seam tests, metrics et reports.
13. **Aucune génération lourde sur MainActor** : les jobs terrain/biome/props/surface sont planifiés hors UI/runtime critique.
14. **Cachabilité explicite** : chaque payload sait s'il est canonique, dérivé, reconstruisible, persistable ou purement GPU.
15. **Versioning strict** : toute règle générative a une version, un hash et une politique de migration.

---

## 3. Le concept clé : un monde = champs + graphes + contraintes + deltas

Un monde IsoForge n'est pas une grille de chunks contenant des biomes. C'est une superposition hiérarchique de champs et graphes :

```text
Continental scale
  → continents, océans, grandes chaînes de montagnes, grandes zones climatiques

Regional scale
  → bassins versants, rain shadows, plateaux, forêts, déserts, zones humides, zones volcaniques

Local scale
  → sous-biomes, pentes, rives, clairières, falaises, éboulis, mares, bosquets, chemins, ruines

Micro scale
  → micro-habitats, mousses, herbes, traces, roches, racines, débris, variations de surface
```

Chaque échelle est déterministe et peut être requêtée indépendamment.

### 3.1 Types de données

```text
Canonical world data
  WorldSeed, DNA, generator versions, feature graph definitions, save deltas

Derived CPU data
  TerrainSampleGrid, BiomeWeightGrid, HydrologyMask, PropCandidateGrid, SurfaceContextGrid

Derived GPU data
  terrain meshes, cluster pages, texture pages, material pages, debug buffers

Caches reconstructibles
  chunk payload cache, surface bake cache, prop build cache, LOD cluster cache

Persistent deltas
  player changes, terrain edits, destroyed props, ecological mutation, settlement changes
```

### 3.2 Pourquoi cette séparation est critique

Le terrain et les biomes vont être utilisés par :

- rendu ;
- collision ;
- navigation ;
- animation contact ;
- audio ;
- FX ;
- props ;
- settlements ;
- save/replay ;
- tools ;
- génération offline ;
- tests de déterminisme.

Il faut donc éviter que le renderer ou un tool devienne la source de vérité. Le renderer ne reçoit que des snapshots.

---

## 4. Architecture haut niveau

```text
BiomeTerrainForge
├── WorldGenerationDNA
│   ├── WorldGeoDNA
│   ├── WorldClimateDNA
│   ├── WorldBiomeDNA
│   ├── WorldHydrologyDNA
│   ├── WorldSurfaceDNA bridge
│   └── WorldEcologyDNA
├── FieldSystem
│   ├── ContinentalFieldProvider
│   ├── ClimateFieldProvider
│   ├── GeologyFieldProvider
│   ├── SoilFieldProvider
│   ├── HydrologyFieldProvider
│   ├── DisturbanceFieldProvider
│   └── CivilizationInfluenceFieldProvider
├── TerrainForge
│   ├── TerrainRecipeGraph
│   ├── TerrainFeatureGraph
│   ├── TerrainArchetypeResolver
│   ├── HydrologyGraph
│   ├── ErosionSolver
│   ├── VerticalitySolver
│   ├── TerrainConstraintSolver
│   └── TerrainChunkBuilder
├── BiomeForge
│   ├── BiomeRegistry
│   ├── BiomeDefinition
│   ├── SubBiomeDefinition
│   ├── BiomeCompatibilityGraph
│   ├── TopologyAwareBiomeSolver
│   ├── EcotoneResolver
│   ├── MicroHabitatResolver
│   ├── DynamicBiomeStateResolver
│   └── BiomeChunkBuilder
├── RuntimeIntegration
│   ├── ChunkGenerationPlanner
│   ├── ChunkStreamingCache
│   ├── LODPayloadResolver
│   ├── SurfaceContextExporter
│   ├── PropEcologyExporter
│   ├── MotionContactExporter
│   └── SaveDeltaApplier
└── ToolsAndValidation
    ├── TerrainForgeLab
    ├── BiomeForgeLab
    ├── EcotoneDebugger
    ├── HydrologyDebugger
    ├── SeamValidator
    ├── GoldenSeedGallery
    ├── ChunkStreamingProfiler
    └── BiomeTerrainReportExporter
```

---

## 5. World DNA : identité globale du monde

Le seed global ne doit pas seulement changer un bruit de hauteur. Il doit générer une identité complète du monde.

### 5.1 WorldGeoDNA

```swift
struct WorldGeoDNA: Codable, Hashable {
    let seed: UInt64
    let continentScale: Float
    let oceanCoverage: Float
    let mountainFrequency: Float
    let mountainSharpness: Float
    let plateauFrequency: Float
    let faultLineActivity: Float
    let volcanicActivity: Float
    let karstPotential: Float
    let canyonPotential: Float
    let glaciationStrength: Float
    let coastlineComplexity: Float
    let verticalityBias: Float
    let terrainDiversity: Float
}
```

### 5.2 WorldClimateDNA

```swift
struct WorldClimateDNA: Codable, Hashable {
    let globalTemperatureBias: Float
    let globalHumidityBias: Float
    let rainfallIntensity: Float
    let windStrength: Float
    let rainShadowStrength: Float
    let seasonalityStrength: Float
    let stormFrequency: Float
    let frostLineBias: Float
    let desertExpansion: Float
    let wetlandExpansion: Float
    let climateNoiseWarp: Float
}
```

### 5.3 WorldBiomeDNA

```swift
struct WorldBiomeDNA: Codable, Hashable {
    let biomeDiversity: Float
    let subBiomeDensity: Float
    let transitionSoftness: Float
    let ecotoneComplexity: Float
    let ecologicalStability: Float
    let rareBiomeRate: Float
    let anomalyRate: Float
    let corruptionRate: Float
    let alienness: Float
    let civilizationFootprint: Float
    let biomeMutationRate: Float
}
```

### 5.4 WorldHydrologyDNA

```swift
struct WorldHydrologyDNA: Codable, Hashable {
    let riverDensity: Float
    let lakeDensity: Float
    let wetlandBias: Float
    let groundwaterStrength: Float
    let waterfallFrequency: Float
    let riverMeanderStrength: Float
    let basinComplexity: Float
    let shorelineWetness: Float
    let floodplainStrength: Float
}
```

### 5.5 WorldEcologyDNA

```swift
struct WorldEcologyDNA: Codable, Hashable {
    let fertilityBias: Float
    let vegetationDensityBias: Float
    let forestContinuity: Float
    let speciesDiversity: Float
    let disturbanceFrequency: Float
    let fireRegimeStrength: Float
    let diseaseOrDecayRate: Float
    let wildlifePresence: Float
    let resourceDensity: Float
}
```

### 5.6 Pourquoi séparer ces DNA

Cette séparation permet de créer des mondes très variés sans tricher :

```text
Même climat + géologie différente
  → forêts tempérées sur collines douces vs forêts tempérées de falaises humides

Même géologie + climat différent
  → plateau rocheux aride vs plateau couvert de toundra humide

Même biome dominant + hydrologie différente
  → taiga sèche vs taiga marécageuse

Même terrain + civilisation différente
  → vallée sauvage vs vallée agricole vs vallée ruinée
```

---

## 6. Field System : la vérité continue du monde

Les champs sont des fonctions déterministes requêtables à toute coordonnée monde. Ils doivent être stables entre chunks et entre sessions.

### 6.1 ClimateSample

```swift
struct ClimateSample: Codable, Hashable {
    let temperature: Float          // -1 froid, +1 chaud
    let humidity: Float             // 0..1
    let precipitation: Float        // 0..1
    let aridity: Float              // 0..1
    let windExposure: Float         // 0..1
    let sunlight: Float             // 0..1
    let seasonality: Float          // 0..1
    let frostRisk: Float            // 0..1
    let stormFrequency: Float       // 0..1
}
```

### 6.2 GeoHydroSample

```swift
struct GeoHydroSample: Codable, Hashable {
    let altitude: Float
    let slope: Float
    let aspect: Float
    let curvature: Float
    let distanceToOcean: Float
    let distanceToRiver: Float
    let distanceToLake: Float
    let waterDepth: Float
    let drainage: Float
    let floodRisk: Float
    let groundwater: Float
    let shoreInfluence: Float
    let cliffInfluence: Float
    let mountainInfluence: Float
}
```

### 6.3 SoilSample

```swift
struct SoilSample: Codable, Hashable {
    let soilKind: SoilKind
    let fertility: Float
    let drainage: Float
    let salinity: Float
    let organicMatter: Float
    let rockiness: Float
    let sandiness: Float
    let clayness: Float
    let snowRetention: Float
    let erosionSensitivity: Float
}
```

### 6.4 DisturbanceSample

```swift
struct DisturbanceSample: Codable, Hashable {
    let fireHistory: Float
    let floodHistory: Float
    let landslideRisk: Float
    let windDamage: Float
    let animalActivity: Float
    let civilizationWear: Float
    let pollution: Float
    let magicalCorruption: Float
    let playerImpact: Float
}
```

### 6.5 SurfaceContextSample

Ce sample est l'interface vers Surface Forge et Motion Forge.

```swift
struct SurfaceContextSample: Codable, Hashable {
    let biomeWeights: BiomeWeights
    let subBiomeWeights: SubBiomeWeights
    let terrainMasks: TerrainFeatureMasks
    let climate: ClimateSample
    let hydro: GeoHydroSample
    let soil: SoilSample
    let disturbance: DisturbanceSample
    let surfaceState: SurfaceState
    let materialHints: SurfaceMaterialHints
    let contactHints: MotionContactHints
}
```

---

## 7. Terrain Forge : génération de terrains infinis et cohérents

Terrain Forge doit pouvoir générer une infinité de types de terrains sans partir dans une infinité de cas spéciaux. La solution : **recettes + graphes + champs + contraintes**.

### 7.1 TerrainRecipeGraph

Un terrain n'est pas un seul noise. C'est une recette qui combine :

```text
base elevation
continental mask
mountain ridges
plateaus
faults
valleys
river carving
lakes
coastline
erosion layers
cliffs
micro relief
volumetric patches
attached meshes
```

Exemple de recette :

```json
{
  "id": "terrain.mountain_temperate_glacial",
  "version": 1,
  "archetypes": ["mountain", "glacier", "valley", "river"],
  "features": ["ridge_network", "glacial_valleys", "scree_slopes", "alpine_lakes"],
  "constraints": {
    "minAltitudeBias": 0.55,
    "snowLine": 0.72,
    "riverCarving": 0.68,
    "verticality": 0.74
  }
}
```

### 7.2 TerrainFeatureGraph

Le FeatureGraph décrit les grandes structures qui traversent plusieurs chunks.

```text
TerrainFeatureGraph
├── MountainRangeFeature
├── RiverFeature
├── LakeFeature
├── CanyonFeature
├── CliffBandFeature
├── CoastlineFeature
├── GlacierFeature
├── VolcanicFeature
├── KarstCaveFeature
├── FaultLineFeature
├── PlateauFeature
├── DuneFieldFeature
└── SettlementTerrainModificationFeature
```

Chaque feature possède :

```swift
struct TerrainFeatureDescriptor: Codable, Hashable {
    let id: StableFeatureID
    let kind: TerrainFeatureKind
    let seed: UInt64
    let bounds: WorldBounds
    let influenceRadius: Float
    let priority: Int
    let generatorVersion: GeneratorVersion
    let parameters: FeatureParameterBlock
}
```

### 7.3 Représentation hybride

```text
Heightfield principal
  → terrain large, performant, streamable, LOD friendly

SDF / volumetric patches locaux
  → grottes, arches, tunnels, surplombs, cavités, racines géantes, ruines semi-enterrées

Meshes procéduraux attachés
  → falaises détaillées, corniches, rochers, cascades, ponts naturels, formations cristallines

Decals/micro surfaces
  → boue, traces, mousses, feuilles, neige, cendres, sel, algues
```

Le heightfield reste la base canonique pour beaucoup de systèmes, mais il ne doit pas empêcher la verticalité et les formes complexes.

### 7.4 Pipeline par chunk

```text
Input:
  worldSeed
  chunkCoord
  chunkLODRequest
  generatorVersions
  activeSaveDeltas

1. Query global fields
2. Resolve intersecting terrain features
3. Build coarse terrain shape
4. Apply hydrology graph and water masks
5. Apply erosion layers
6. Resolve verticality and traversal classes
7. Resolve biome/sub-biome/ecotone weights
8. Build surface context and material masks
9. Generate prop ecology candidates
10. Build collision/nav/motion contact payloads
11. Build render payload / cluster requests
12. Store chunk cache entries with version/hash
```

### 7.5 Infinité de terrains par composition

Les terrains générables ne sont pas une liste fermée. Ils émergent de combinaisons :

```text
TerrainArchetype
  + climate band
  + geology
  + hydrology
  + erosion
  + biome influence
  + civilization influence
  + rare anomaly
  + seed variation
```

Exemples :

```text
plain + humid + fertile + river meanders
  → prairie inondable, cultures possibles, bosquets riverains

mountain + cold + high precipitation + glaciation
  → vallée alpine, lacs glaciaires, moraines, toundra alpine

plateau + arid + sandstone + canyon erosion
  → mesas, canyons, arches, ravins secs

coast + tropical + volcanic + high rainfall
  → falaises noires, jungle côtière, cascades vers océan

karst + temperate + high groundwater
  → dolines, grottes, rivières souterraines, forêts humides

volcanic + corrupted + low vegetation
  → cendres, fissures chaudes, roches sombres, biomes anormaux
```

---

## 8. Biome Forge : biomes, sous-biomes et écotones

### 8.1 Définitions

**Biome global** : grande identité écologique d'une région : taiga, savane, désert, forêt tempérée, toundra, marais, côte, montagne, etc.

**Sous-biome** : variation locale cohérente : clairière humide, lisière de forêt, rive boueuse, pente rocheuse, pinède sèche, zone de mousses, dune stabilisée, marais saumâtre.

**Écotone** : zone de transition naturelle entre biomes ou sous-biomes. Ce n'est pas un simple blend visuel : c'est une vraie zone avec règles propres.

**Micro-habitat** : petite zone écologique dépendant de détails locaux : pied d'arbre, rocher ombragé, berge, tronc mort, trou d'eau, fissure humide, éboulis.

### 8.2 BiomeDefinition

```swift
struct BiomeDefinition: Codable, Hashable {
    let id: BiomeID
    let displayName: String
    let domain: BiomeDomain
    let climateEnvelope: ClimateEnvelope
    let topologyEnvelope: TopologyEnvelope
    let hydrologyEnvelope: HydrologyEnvelope
    let soilEnvelope: SoilEnvelope
    let allowedSubBiomes: [SubBiomeID]
    let materialPalette: BiomeMaterialPaletteID
    let propEcologyRules: PropEcologyRuleSetID
    let faunaRules: FaunaRuleSetID?
    let weatherProfile: BiomeWeatherProfileID
    let motionSurfaceTags: [MotionSurfaceTag]
    let audioAmbienceProfile: AudioAmbienceProfileID
    let transitionPolicy: BiomeTransitionPolicy
    let rarity: BiomeRarity
    let generatorVersion: GeneratorVersion
}
```

### 8.3 ClimateEnvelope

```swift
struct ClimateEnvelope: Codable, Hashable {
    let temperatureRange: ClosedRange<Float>
    let humidityRange: ClosedRange<Float>
    let precipitationRange: ClosedRange<Float>
    let aridityRange: ClosedRange<Float>
    let frostRiskRange: ClosedRange<Float>
    let seasonalityRange: ClosedRange<Float>
    let idealPoint: ClimateVector
    let tolerance: ClimateVector
}
```

### 8.4 TopologyEnvelope

```swift
struct TopologyEnvelope: Codable, Hashable {
    let altitudeRange: ClosedRange<Float>
    let slopeRange: ClosedRange<Float>
    let curvatureRange: ClosedRange<Float>
    let distanceToWaterRange: ClosedRange<Float>
    let cliffInfluenceRange: ClosedRange<Float>
    let shoreInfluenceRange: ClosedRange<Float>
    let mountainInfluenceRange: ClosedRange<Float>
    let allowedTerrainArchetypes: [TerrainArchetype]
}
```

### 8.5 Biome selection : affinité pondérée

Biome Forge ne choisit pas un biome par seuil unique. Il calcule une affinité :

```text
affinity = climateFit
         * topologyFit
         * hydroFit
         * soilFit
         * worldDNAWeight
         * adjacencyCompatibility
         * disturbanceModifier
         * rarityModifier
```

Puis il garde plusieurs poids :

```swift
struct BiomeWeights: Codable, Hashable {
    let primary: WeightedBiome
    let secondary: WeightedBiome?
    let tertiary: WeightedBiome?
    let normalizedLayers: [WeightedBiome] // max 4 pour runtime/surface
    let ecotoneStrength: Float
    let confidence: Float
}
```

### 8.6 Pourquoi garder plusieurs poids

Les poids servent à :

- transitions visuelles ;
- matériaux terrain ;
- densités props ;
- météo locale ;
- sons ambiants ;
- faune ;
- gameplay traversal ;
- Motion Forge contacts ;
- Surface Forge masks ;
- sauvegarde de deltas écologiques.

Un sample peut être :

```text
temperate_broadleaf_forest 0.58
wetland 0.31
river_corridor 0.11
```

Ce n'est pas juste une forêt. C'est une forêt humide de bord de rivière.

---

## 9. Sous-biomes : cohérence locale

### 9.1 SubBiomeDefinition

```swift
struct SubBiomeDefinition: Codable, Hashable {
    let id: SubBiomeID
    let parentBiome: BiomeID
    let localEnvelope: LocalEnvironmentEnvelope
    let terrainRequirements: TerrainRequirementSet
    let hydrologyRequirements: HydrologyRequirementSet
    let propRules: PropEcologyRuleSetID
    let surfaceModifiers: SurfaceModifierSet
    let microHabitats: [MicroHabitatDefinition]
    let rarity: Float
    let minPatchSize: Float
    let maxPatchSize: Float
    let transitionPolicy: SubBiomeTransitionPolicy
}
```

### 9.2 Exemples de sous-biomes

```text
temperate_broadleaf_forest
  ├── dense_canopy
  ├── open_glade
  ├── mossy_floor
  ├── riverbank_woods
  ├── rocky_slope_forest
  ├── fallen_tree_zone
  ├── fern_understory
  └── old_growth_core

taiga
  ├── dry_pine_ridge
  ├── wet_spruce_lowland
  ├── moss_bog_edge
  ├── snow_patch_forest
  ├── burned_regrowth
  └── lichen_rock_field

hot_sandy_desert
  ├── dune_field
  ├── interdune_plain
  ├── dry_wadi
  ├── oasis_edge
  ├── salt_flat_margin
  └── rocky_outcrop

wetland
  ├── reed_bed
  ├── mud_flat
  ├── shallow_marsh
  ├── peat_bog
  ├── willow_thicket
  └── stagnant_pool

mountain_temperate
  ├── alpine_meadow
  ├── scree_slope
  ├── cliff_ledge
  ├── snowline_transition
  ├── glacial_moraine
  └── high_pass
```

### 9.3 Patch solver

Les sous-biomes doivent former des patches naturels, pas du bruit pixelisé.

```text
1. Déterminer les zones candidates via envelopes locales.
2. Générer des seeds de patches stables en coordonnées monde.
3. Étendre les patches selon pente, eau, ombre, sol et obstacles.
4. Appliquer min/max patch size.
5. Fusionner ou supprimer les patches non crédibles.
6. Générer des écotones internes.
7. Exposer des poids continus par sample.
```

---

## 10. Écotones : transitions naturelles entre biomes

### 10.1 Principe

Un écotone est une zone de transition avec identité propre. Exemple : forêt → prairie ne doit pas devenir un simple gradient vert/jaune. Il faut :

```text
lisière
arbustes
herbes hautes
jeunes arbres
sol plus lumineux
densité de débris différente
faune différente
ambiance sonore différente
contact sol différent
```

### 10.2 EcotoneDefinition

```swift
struct EcotoneDefinition: Codable, Hashable {
    let id: EcotoneID
    let biomeA: BiomeID
    let biomeB: BiomeID
    let compatibility: Float
    let naturalWidthRange: ClosedRange<Float>
    let widthDrivers: EcotoneWidthDrivers
    let materialBlendPolicy: MaterialBlendPolicy
    let propBlendPolicy: PropBlendPolicy
    let subBiomePolicy: EcotoneSubBiomePolicy
    let motionSurfacePolicy: MotionSurfacePolicy
    let audioBlendPolicy: AudioBlendPolicy
    let rarityModifiers: [EcotoneModifier]
}
```

### 10.3 Largeur d'écotone

La largeur dépend de :

```text
pente
humidité
contraste climatique
contraste hydrologique
densité végétation
stabilité écologique
perturbations
civilisation
WorldBiomeDNA.transitionSoftness
```

Exemples :

```text
forêt tempérée → prairie
  écotone large, lisière progressive

falaise rocheuse → forêt
  transition courte, contrainte par pente

désert → oasis
  transition organisée par distance à l'eau

taiga → toundra
  transition altitudinale/climatique large

marais → forêt
  transition hydrologique, sol spongieux, racines, roseaux
```

### 10.4 BiomeCompatibilityGraph

```text
BiomeCompatibilityGraph
├── natural adjacency
├── rare adjacency
├── forbidden adjacency
├── requires ecotone
├── requires terrain feature
├── requires hydrology feature
└── requires anomaly/corruption/civilization
```

Ce graphe empêche les combinaisons absurdes sauf si le monde DNA contient une anomalie explicite.

### 10.5 Seam safety

Les écotones doivent être stables aux frontières de chunks :

- requêtes en coordonnées monde ;
- ghost margin autour du chunk ;
- aucun random local au chunk ;
- stable IDs pour patches ;
- topological ordering canonique ;
- tests de bord partagé ;
- hashing des payloads voisins.

---

## 11. Taxonomie des biomes et sous-biomes

Cette liste sert de base de design, pas de promesse d'implémentation immédiate. Chaque biome doit devenir une définition data-driven.

### 11.1 Forêts tropicales et subtropicales humides

- `rainforest_lowland`
  - dense_canopy
  - flooded_forest
  - river_gallery
  - liana_dense_zone
  - giant_tree_cluster
  - fern_floor
  - fallen_log_rot_zone
  - misty_understory
- `cloud_forest_tropical`
  - moss_cloud_slope
  - orchid_canopy
  - fog_ridge
  - dripping_cliff_forest
  - high_epiphyte_zone

### 11.2 Forêts tropicales sèches et savanes

- `tropical_dry_forest`
  - dry_leaf_litter
  - thorn_scrub_edge
  - seasonal_stream_corridor
  - rocky_dry_slope
- `savanna`
  - tall_grass_plain
  - acacia_scatter
  - termite_mound_field
  - seasonal_waterhole
  - burned_grass_regrowth

### 11.3 Forêts tempérées

- `temperate_broadleaf_forest`
  - dense_canopy
  - open_glade
  - fern_understory
  - mossy_rock_floor
  - riverbank_woods
  - old_growth_core
  - autumn_leaf_floor
- `temperate_conifer_forest`
  - pine_ridge
  - shaded_needles_floor
  - mossy_trunk_zone
  - rocky_conifer_slope
- `temperate_rainforest`
  - giant_conifer_moss
  - nurse_log_zone
  - rain_soaked_floor
  - fern_valley
  - misty_creek_corridor

### 11.4 Prairies, steppes et landes

- `temperate_grassland`
  - shortgrass_plain
  - tallgrass_field
  - wildflower_patch
  - grazing_disturbed_zone
  - river_meadow
- `steppe`
  - dry_grass_plain
  - rocky_steppe
  - shrub_steppe
  - wind_exposed_ridge
- `heathland_moorland`
  - heather_patch
  - peat_pool
  - wind_swept_grass
  - rocky_moor

### 11.5 Biomes boréaux

- `taiga`
  - dry_pine_ridge
  - wet_spruce_lowland
  - moss_bog_edge
  - lichen_rock_field
  - burned_regrowth
  - snow_patch_forest
- `boreal_wetland`
  - peat_bog
  - black_spruce_swamp
  - sphagnum_carpet
  - cold_marsh_pool

### 11.6 Toundra et polaire

- `tundra`
  - lichen_plain
  - dwarf_shrub_patch
  - permafrost_polygon
  - snowbed
  - wet_tundra
- `polar_desert`
  - ice_gravel_plain
  - wind_scoured_rock
  - sparse_lichen_rock
  - frozen_salt_flat

### 11.7 Déserts et milieux arides

- `hot_sandy_desert`
  - dune_field
  - interdune_flat
  - dry_wadi
  - oasis_edge
  - salt_flat_margin
- `rocky_desert`
  - boulder_plain
  - desert_pavement
  - canyon_rim
  - dry_cliff_face
  - sparse_scrub_outcrop
- `cold_desert`
  - gravel_steppe
  - dry_snow_patch
  - frost_cracked_soil
  - wind_cut_ridge

### 11.8 Montagnes et haute altitude

- `mountain_temperate`
  - alpine_meadow
  - scree_slope
  - cliff_ledge
  - montane_forest_edge
  - snowline_transition
  - glacial_moraine
- `mountain_arid`
  - dry_ridge
  - canyon_wall
  - sparse_juniper_slope
  - talus_field
- `mountain_tropical`
  - cloud_slope
  - high_moss_forest
  - orchid_cliff
  - wet_ridge

### 11.9 Eau douce, rivières, lacs, marais

- `river_corridor`
  - gravel_bar
  - muddy_bank
  - riparian_forest
  - reed_edge
  - waterfall_spray_zone
  - floodplain_meadow
- `lake`
  - sandy_shore
  - rocky_shore
  - reed_bed
  - deep_water_edge
  - algae_shallow
- `wetland`
  - reed_marsh
  - peat_bog
  - mud_flat
  - willow_thicket
  - stagnant_pool
  - floating_vegetation

### 11.10 Littoraux et océans

- `coast_temperate`
  - rocky_shore
  - pebble_beach
  - dune_grass
  - tide_pool
  - salt_marsh
  - cliff_coast
- `coast_tropical`
  - white_sand_beach
  - mangrove_edge
  - coral_shallow
  - palm_dune
  - tidal_lagoon
- `ocean`
  - shallow_shelf
  - kelp_forest
  - reef_zone
  - deep_water

### 11.11 Souterrain, grottes, karst

- `cave_system`
  - limestone_cavern
  - underground_river
  - crystal_chamber
  - mushroom_cave
  - collapsed_sinkhole
  - bat_roost
- `karst_surface`
  - limestone_pavement
  - sinkhole_field
  - dry_valley
  - spring_outflow

### 11.12 Volcanique et géothermique

- `volcanic`
  - basalt_plain
  - ash_field
  - lava_tube
  - geothermal_pool
  - sulfur_slope
  - black_sand_coast

### 11.13 Biomes anthropisés / civilisation

- `rural`
  - field_margin
  - orchard_edge
  - pasture
  - hedgerow
  - irrigation_channel
- `urban_light`
  - garden_patch
  - cobblestone_moss
  - disturbed_soil
  - roadside_weeds
- `industrial`
  - polluted_soil
  - slag_heap
  - dust_yard
  - rust_water_runoff

### 11.14 Post-catastrophe / ruines / fantastique / alien

- `post_apocalyptic`
  - overgrown_ruins
  - ash_wasteland
  - cracked_road
  - toxic_pool
- `enchanted_forest`
  - glowing_moss
  - ancient_tree_circle
  - fairy_glade
  - luminous_stream
- `corrupted_land`
  - blackened_soil
  - thorn_growth
  - dead_tree_zone
  - purple_crystal_patch
- `alien_crystal`
  - crystal_spires
  - glassy_sand
  - mineral_growth
  - strange_mist_basin
- `alien_bioluminescent`
  - glowing_fungal_forest
  - pulse_grass
  - wet_neon_marsh
  - floating_spore_zone

---

## 12. Taxonomie des terrains générables

### 12.1 Plaines et surfaces douces

- plain_fertile
- plain_dry
- floodplain
- meadow_plain
- rolling_plain
- salt_flat
- tundra_flat
- ash_plain
- mud_plain
- alluvial_fan

### 12.2 Collines et ondulations

- rolling_hills
- drumlin_field
- dune_hills
- forested_hills
- dry_scrub_hills
- moorland_hills
- volcanic_hummocks

### 12.3 Montagnes

- alpine_range
- old_eroded_mountains
- sharp_fault_mountains
- volcanic_mountains
- tropical_mountains
- glacial_valleys
- high_plateau_mountains
- snowline_ridges

### 12.4 Falaises et verticalité naturelle

- sea_cliffs
- canyon_cliffs
- basalt_columns
- limestone_cliffs
- glacial_headwall
- overhanging_rock_wall
- cliff_ledge_system
- broken_escarpment

### 12.5 Canyons, gorges, ravins

- river_canyon
- slot_canyon
- dry_wadi
- badlands_ravines
- jungle_gorge
- glacial_gorge
- volcanic_rift

### 12.6 Hydrologie

- meandering_river
- braided_river
- mountain_stream
- waterfall_chain
- marsh_delta
- inland_lake
- crater_lake
- glacial_lake
- oxbow_lake
- underground_river

### 12.7 Déserts et aridité

- dune_sea
- rocky_desert_plain
- desert_pavement
- mesa_badlands
- dry_salt_basin
- scrubland
- canyon_desert

### 12.8 Glace et neige

- glacier_valley
- icefield
- frozen_lake
- permafrost_polygon_field
- snow_drift_slope
- avalanche_chute
- moraine_field

### 12.9 Volcanisme et géothermie

- lava_plain
- ash_slope
- caldera
- geothermal_pool_field
- lava_tube_network
- black_sand_beach
- basalt_column_coast

### 12.10 Karst, grottes, souterrain

- sinkhole_field
- limestone_pavement
- cave_network
- collapsed_cavern
- underground_lake
- karst_spring

### 12.11 Côtes

- sandy_beach
- rocky_coast
- cliff_coast
- tidal_marsh
- mangrove_coast
- coral_lagoon
- fjord
- delta

### 12.12 Anthropisé / semi-naturel

- terraced_hillside
- farm_valley
- quarry
- mining_pit
- old_road_cut
- ruin_overgrown_terrain
- canal_network
- defensive_earthworks

---

## 13. Intégration avec les chunks et le streaming

### 13.1 Les chunks ne décident pas le monde

Un chunk est une fenêtre de calcul. Les champs et features sont globaux. Donc :

```text
chunkCoord
  → query world fields
  → query intersecting features
  → build local payload
```

Jamais :

```text
chunkCoord
  → random biome local
```

### 13.2 Chunk payloads

```swift
struct BiomeTerrainChunkPayload: Codable, Hashable {
    let chunkCoord: ChunkCoord
    let generatorVersions: GeneratorVersionTable
    let terrainGrid: TerrainSampleGrid
    let biomeGrid: BiomeWeightGrid
    let subBiomeGrid: SubBiomeWeightGrid
    let ecotoneGrid: EcotoneGrid
    let hydrologyGrid: HydrologyGrid
    let soilGrid: SoilGrid
    let surfaceContextGrid: SurfaceContextGrid
    let propEcologyGrid: PropEcologyGrid
    let traversalGrid: TraversalGrid
    let motionContactGrid: MotionContactGrid
    let featureRefs: [StableFeatureID]
    let cacheSignature: ChunkCacheSignature
}
```

### 13.3 Streaming rings

```text
Ring 0 — gameplay immediate
  terrain high fidelity, collision, motion contacts, props interactive, surface pages resident

Ring 1 — near visual
  terrain high/mid, props visible, surface mid, collision simplified

Ring 2 — mid distance
  terrain LOD, HLOD props, surface macro, no detailed interactions

Ring 3 — far vista
  terrain low, biome color fields, HLOD silhouettes, atmospheric composition

Ring 4 — planning/prewarm
  CPU fields only, no GPU upload unless predicted path requires it
```

### 13.4 Cache hierarchy

```text
L0 memory hot cache
  active chunks and neighbors

L1 memory warm cache
  recently visited chunks, compressed payloads

L2 disk cache
  derived CPU payloads, rebuildable by version/hash

L3 asset/runtime cache
  surface pages, prop packs, LOD clusters

Canonical save
  only seed + versions + deltas + explicit player/world mutations
```

### 13.5 Job priorities

```text
P0 player current chunk collision/contact
P1 immediate neighbor terrain/collision
P2 visible render chunks
P3 surface/material pages
P4 prop detail materialization
P5 far LOD/HLOD
P6 analysis/debug/tool-only jobs
```

### 13.6 Invalidations

Un cache devient stale si :

- générateur version change ;
- WorldDNA change ;
- terrain recipe changes ;
- biome definition changes ;
- save delta touches region ;
- asset manifest hash changes ;
- surface graph version changes ;
- LOD policy changes.

---

## 14. Intégration avec le LOD custom inspiré de Nanite

### 14.1 Principe

Le terrain et les props doivent être virtualisés par clusters/pages. On ne charge pas un monde complet ; on charge les représentations nécessaires à la distance, au budget, à la visibilité, au gameplay et au debug.

### 14.2 Données LOD terrain

```text
TerrainLOD0
  full sample grid, collision, contacts, high material masks

TerrainLOD1
  reduced grid, collision simplified, material masks mid

TerrainLOD2
  cluster mesh, no fine collision, macro materials

TerrainLOD3
  HLOD terrain patch, biome color + silhouette

TerrainLOD4
  far field impostor / height panorama / atmospheric card
```

### 14.3 Cluster payload

```swift
struct TerrainClusterPage: Codable, Hashable {
    let pageID: ClusterPageID
    let chunkCoord: ChunkCoord
    let lod: TerrainLODLevel
    let bounds: WorldBounds
    let sourceSignature: ChunkCacheSignature
    let materialPageRefs: [SurfacePageID]
    let biomeSignature: BiomeSignature
    let errorMetric: Float
    let seamPolicy: ClusterSeamPolicy
}
```

### 14.4 Biome-aware LOD

Le LOD ne doit pas détruire la lecture écologique. À distance, on doit encore comprendre :

- forêt vs prairie ;
- côte vs marais ;
- snowline ;
- rivières ;
- falaises ;
- anomalies ;
- zones civilisées ;
- couleurs globales cohérentes.

Donc le far LOD conserve un `BiomeMacroField` et un `SurfaceMacroColorField`.

### 14.5 Seam policy

Les transitions LOD doivent respecter :

- frontières heightfield ;
- continuité de rivières ;
- continuité des écotones ;
- continuité des splats matériaux ;
- bordures de collision proche ;
- transitions visuelles progressives.

---

## 15. Intégration avec Surface Forge

Surface Forge consomme le contexte monde pour générer les matériaux.

```text
BiomeTerrainForge
  → SurfaceContextGrid
  → SurfaceGraph inputs
  → PBR maps / masks / runtime bindings
```

### 15.1 SurfaceContext export

```swift
struct SurfaceContextExport: Codable, Hashable {
    let biomeWeights: BiomeWeights
    let subBiomeWeights: SubBiomeWeights
    let ecotoneStrength: Float
    let terrainFeatureMasks: TerrainFeatureMasks
    let hydrologyMasks: HydrologyMasks
    let soil: SoilSample
    let climate: ClimateSample
    let disturbance: DisturbanceSample
    let slope: Float
    let altitude: Float
    let wetness: Float
    let snow: Float
    let dust: Float
    let moss: Float
    let mud: Float
}
```

### 15.2 Material rules

Exemples :

```text
slope > 0.72 + cliffInfluence high
  → rock material dominant, triplanar, less vegetation, more scree props

distanceToRiver low + humidity high + soil clay
  → mud/shore material, wetness high, reed props, splash footsteps

altitude above snowline + low sunlight
  → snow material accumulation, icy roughness response, snow footstep decals

forest old_growth + high organicMatter
  → leaf litter, moss, dark soil, fungi micro-props

coast + salinity high
  → sand/pebble/seaweed/salt crust materials
```

### 15.3 Surface pages

Surface Forge doit pouvoir générer des pages par signature :

```text
SurfacePageKey:
  worldSeed
  graphHash
  biomeSignature
  subBiomeSignature
  terrainFeatureSignature
  chunkCoord or regionCoord
  lod
  resolution
  surfaceStateVersion
```

---

## 16. Intégration avec les props, végétation et faune

Le Prop System ne doit pas choisir les props uniquement par biome dominant. Il consomme des champs de densité.

### 16.1 PropEcologyGrid

```swift
struct PropEcologySample: Codable, Hashable {
    let vegetationDensity: Float
    let treeDensity: Float
    let shrubDensity: Float
    let grassDensity: Float
    let rockDensity: Float
    let deadWoodDensity: Float
    let fungalDensity: Float
    let resourceDensity: Float
    let microPropDensity: Float
    let faunaHabitatScore: Float
    let placementConstraints: PlacementConstraintMask
}
```

### 16.2 Règles contextuelles

```text
forest old_growth
  → gros arbres, troncs morts, champignons, mousse, faible herbe directe

forest edge ecotone
  → arbustes, jeunes arbres, herbes hautes, fleurs, faune plus visible

scree_slope
  → rochers, cailloux, lichens, peu d'arbres, collision prudente

riverbank
  → roseaux, boue, racines, galets, insectes, sons eau

dry_wadi
  → galets, bois mort, végétation rare, traces d'écoulement

corrupted_land
  → arbres morts, cristaux, ronces, sol sombre, anomalies FX/audio
```

### 16.3 Props et biomes rares

Les biomes rares ne doivent pas être seulement une couleur. Ils doivent modifier :

- familles de props ;
- matériaux ;
- audio ;
- FX ;
- motion contacts ;
- loot/resources ;
- navigation ;
- météo ;
- comportement faune.

---

## 17. Intégration avec Motion Forge

Motion Forge a besoin de terrain et surfaces fiables.

### 17.1 MotionContactHints

```swift
struct MotionContactHints: Codable, Hashable {
    let surfaceClass: TraversalSurfaceClass
    let friction: Float
    let compliance: Float
    let wetness: Float
    let mudDepth: Float
    let snowDepth: Float
    let waterDepth: Float
    let looseRock: Float
    let vegetationObstruction: Float
    let slopeNormal: Vec3
    let stepHeight: Float
    let ledgeScore: Float
    let climbability: Float
    let danger: Float
}
```

### 17.2 Exemples d'effets sur animation

```text
wet_mud
  → pas plus lents, glissements légers, splash FX, traces persistantes

scree_slope
  → appuis courts, équilibre bras, pierres qui roulent, friction variable

snow
  → enfoncement, cadence modifiée, empreintes, audio mat

forest_understory
  → évitement racines, pas haut, collision végétation légère

cliff_ledge
  → motion cautious, IK précis, ledge contact candidates

river_shallow
  → water resistance, splash, surface normal perturbée
```

---

## 18. Dynamic Biome State : biomes vivants et deltas persistants

Les biomes peuvent évoluer, mais la base reste déterministe.

### 18.1 États possibles

```text
normal
wet
flooded
dry
burned
regrowing
snow_covered
frozen
diseased
corrupted
polluted
cultivated
overgrown
trampled
player_modified
```

### 18.2 DynamicBiomeState

```swift
struct DynamicBiomeState: Codable, Hashable {
    let regionID: RegionID
    let biomeState: BiomeStateKind
    let intensity: Float
    let startWorldTime: WorldTime
    let durationPolicy: DurationPolicy
    let source: BiomeStateSource
    let affectsMaterials: Bool
    let affectsProps: Bool
    let affectsMotion: Bool
    let affectsAudio: Bool
    let version: GeneratorVersion
}
```

### 18.3 Déterminisme temporel

Pour éviter des saves énormes :

```text
Base deterministic state
  → calculé depuis seed + saison + météo + world time discret

Persistent deltas
  → incendie déclenché, pont construit, zone polluée, joueur a coupé arbres

Regeneration
  → fonction déterministe à partir de delta + temps
```

---

## 19. Save system et migrations

### 19.1 Ce qui est persisté

```text
WorldSeed
GeneratorVersionTable
WorldDNA snapshots
player/world deltas
terrain edits explicites
biome state deltas
destroyed/modified props
settlement modifications
surface overrides rares
migration history
```

### 19.2 Ce qui n'est pas persisté

```text
height grids reconstructibles
biome grids reconstructibles
surface bake pages reconstructibles
render clusters reconstructibles
prop candidates reconstructibles
motion contact grids reconstructibles
```

### 19.3 Migration

Chaque définition data-driven a :

```text
id
version
schemaVersion
generatorVersion
compatibilityPolicy
migrationStrategy
```

Si une définition change, le système doit savoir :

- conserver les saves existantes ;
- migrer les deltas ;
- invalider les caches ;
- marquer les golden seeds comme nécessitant rebaseline ;
- exporter un rapport.

---

## 20. Formats de fichiers proposés

```text
.isoworlddna
  ADN global monde : geo, climate, biome, hydrology, ecology, surface

.isoterrainrecipe
  recette terrain data-driven

.isofeaturegraph
  graph de features terrain/hydrologie

.isobiome
  définition d'un biome

.isosubbiome
  définition d'un sous-biome

.isoecotone
  définition de transition entre biomes/sous-biomes

.isoecologyrules
  règles props/faune/micro-habitats

.isosurfacecontext
  bridge vers Surface Forge

.isogoldenseed
  scénario de validation monde

.isobiometerrainreport
  rapport outil/CI
```

Tous ces formats doivent être textuels ou Codable stable, diffables autant que possible, et compatibles avec Codex.

---

## 21. Outils à construire

### 21.1 World DNA Designer

Permet de générer et comparer des identités monde :

- monde froid/sec ;
- monde tropical humide ;
- monde volcanique ;
- monde fortement vertical ;
- monde post-catastrophe ;
- monde alien ;
- monde très hydrologique ;
- monde très forestier.

### 21.2 Terrain Forge Lab

Fonctions :

- visualiser terrain recipe ;
- preview chunk/région ;
- afficher height/slope/curvature ;
- afficher feature graph ;
- debugger hydrologie ;
- inspecter routes verticales ;
- exporter rapports de seams ;
- comparer LOD.

### 21.3 Biome Forge Lab

Fonctions :

- éditer BiomeDefinition ;
- éditer SubBiomeDefinition ;
- éditer ClimateEnvelope et TopologyEnvelope ;
- visualiser biome weights ;
- visualiser sous-biomes ;
- visualiser écotones ;
- inspecter compatibilité ;
- détecter biomes impossibles ;
- comparer seeds.

### 21.4 Ecotone Debugger

Debug views :

- primary biome ;
- secondary biome ;
- ecotone strength ;
- transition width ;
- material blend ;
- prop blend ;
- audio blend ;
- motion contact transition.

### 21.5 Hydrology Lab

Fonctions :

- bassins versants ;
- direction d'écoulement ;
- rivières ;
- lacs ;
- marais ;
- cascades ;
- flood risk ;
- river carving ;
- shoreline masks.

### 21.6 Prop Ecology Viewer

Fonctions :

- densité arbres/herbes/rochers ;
- raisons de placement/refus ;
- patches végétation ;
- rare props ;
- ressources ;
- micro-props ;
- export report.

### 21.7 Surface Context Inspector

Bridge avec Surface Forge :

- wetness/snow/dust/moss/mud ;
- material hints ;
- surface page signature ;
- biome-driven material result ;
- texture residency needs.

### 21.8 Motion Terrain Contact Inspector

Bridge avec Motion Forge :

- friction ;
- compliance ;
- snow depth ;
- mud depth ;
- climbability ;
- ledge score ;
- terrain class ;
- footstep material.

### 21.9 Chunk Streaming Profiler

- chunk states ;
- job queue ;
- cache hit/miss ;
- CPU generation time ;
- GPU upload time ;
- memory budget ;
- surface page residency ;
- cluster page residency ;
- invalidation reasons.

### 21.10 Golden Seed Gallery

Un corpus de seeds de validation :

```text
flat_temperate_seed
mountain_snow_seed
river_delta_seed
desert_oasis_seed
coast_cliff_seed
wetland_forest_seed
volcanic_seed
karst_cave_seed
alien_biome_seed
civilized_valley_seed
extreme_chunk_seam_seed
negative_coordinate_seed
```

---

## 22. Validation automatique

### 22.1 Tests déterministes

- même seed, même résultat ;
- coordonnées négatives ;
- bordures chunks ;
- ordre de génération indépendant ;
- génération parallèle stable ;
- versions/hashes stables ;
- save/load stable.

### 22.2 Tests écologiques

- biome compatible avec climat ;
- sous-biome compatible avec parent ;
- désert pas au milieu d'un marais sans anomalie ;
- snowline cohérente ;
- rain shadow cohérent ;
- rivières suivent topologie ;
- zones humides proches hydrologie ;
- forêt dense pas sur pente impossible sauf variante spécifique.

### 22.3 Tests terrain

- pas de cracks chunk borders ;
- pentes bornées selon règles ;
- collision disponible Ring 0 ;
- hydrologie continue ;
- routes verticales jouables ;
- lakes sans fuites évidentes ;
- features intersectent les chunks correctement.

### 22.4 Tests LOD/streaming

- LOD transitions sans seams critiques ;
- biome macro conservé à distance ;
- cache invalidation correcte ;
- budgets respectés ;
- no MainActor generation ;
- GPU resources labelisées.

### 22.5 Metrics

```text
biomeDiversityScore
subBiomePatchQuality
transitionNaturalnessScore
hydrologyContinuityScore
terrainSeamError
surfaceContextCompleteness
propEcologyCoherence
motionContactCompleteness
chunkGenerationCost
cacheHitRate
LODVisualContinuity
```

---

## 23. Runtime pipeline complet

```text
WorldPreparePipeline
  1. Normalize seed
  2. Generate WorldDNA
  3. Build global feature indexes
  4. Resolve spawn region candidates
  5. Prewarm Ring 0/Ring 1 fields
  6. Validate terrain/biome/hydrology spawn
  7. Generate initial chunks CPU payloads
  8. Request surface pages and cluster pages
  9. Open RealWorld only when requirements are satisfied

Frame runtime
  1. Update player/camera intent
  2. Predict streaming direction
  3. Schedule chunk jobs
  4. Apply completed payloads
  5. Update Surface Forge residency
  6. Update Prop materialization
  7. Update Motion Forge contact context
  8. Build RenderWorldSnapshot
  9. RenderCoreMetal4 executes RenderGraph
  10. Save system records deltas/autosave if needed
```

---

## 24. Roadmap version ultime

### STEP 1 — Foundations DNA & determinism

- `WorldSeed`
- `GeneratorVersionTable`
- `WorldGeoDNA`
- `WorldClimateDNA`
- `WorldBiomeDNA`
- `WorldHydrologyDNA`
- golden seed harness
- tests déterminisme coordinates/seeds

### STEP 2 — Field System canonical

- `ClimateFieldProvider`
- `GeologyFieldProvider`
- `HydrologyFieldProvider`
- `SoilFieldProvider`
- `DisturbanceFieldProvider`
- debug field sampler
- tests continuité chunk borders

### STEP 3 — TerrainRecipeGraph minimal but final-shaped

- graph data model
- terrain archetypes
- feature refs
- constraints
- validator
- `.isoterrainrecipe`

### STEP 4 — TerrainFeatureGraph world-scale

- mountain ranges
- rivers
- lakes
- cliffs
- coastlines
- plateaus
- feature index spatial
- stable IDs

### STEP 5 — Chunk Terrain Builder

- `TerrainSampleGrid`
- height/slope/curvature
- ghost margin
- seams validation
- collision base
- traversal base

### STEP 6 — Hydrology Graph

- drainage
- rivers
- lakes
- shore masks
- wetlands
- waterfalls placeholders
- hydrology debugger

### STEP 7 — Biome Registry & BiomeDefinition

- `.isobiome`
- climate/topology/hydro/soil envelopes
- biome affinity solver
- weighted top-N biomes
- 8-12 starter biomes

### STEP 8 — SubBiome System

- `.isosubbiome`
- local envelopes
- patch solver
- micro-habitat hooks
- sub-biome debug

### STEP 9 — Ecotone System

- `BiomeCompatibilityGraph`
- `.isoecotone`
- transition width resolver
- prop/material/audio/motion transition policies
- ecotone debugger

### STEP 10 — Surface Context bridge

- `SurfaceContextGrid`
- material hints
- wetness/snow/dust/moss/mud exports
- Surface Forge page keys
- validators

### STEP 11 — Prop Ecology bridge

- `PropEcologyGrid`
- density fields
- biome/sub-biome prop rules
- micro-prop hooks
- Prop Ecology Viewer

### STEP 12 — Motion Contact bridge

- `MotionContactGrid`
- friction/compliance/wetness/snow/mud
- ledge/climbability
- Motion Terrain Contact Inspector

### STEP 13 — Chunk streaming production policy

- rings
- job priorities
- hot/warm/disk caches
- invalidation signatures
- profiler

### STEP 14 — Terrain LOD & cluster pages

- LOD grids
- cluster page descriptors
- seam policies
- far macro biome fields
- RenderCoreMetal4 bridge

### STEP 15 — Terrain materials production path

- terrain layered PBR inputs
- triplanar rules
- macro/micro variation
- material LOD
- residency integration

### STEP 16 — Dynamic Biome State

- wet/flooded/burned/snow/corrupted/cultivated states
- deterministic time resolver
- persistent deltas
- save/load tests

### STEP 17 — Advanced terrain features

- caves/SDF patches
- overhangs
- arches
- karst
- volcanic features
- attached mesh features

### STEP 18 — Advanced hydrology

- basins
- floodplains
- groundwater
- deltas
- river seasonal states
- shore erosion

### STEP 19 — World-scale ecology

- species/resource zones
- ecological succession
- disturbance/regrowth
- fauna habitats
- rare biome anomalies

### STEP 20 — Tools production suite

- Terrain Forge Lab
- Biome Forge Lab
- Hydrology Lab
- Ecotone Debugger
- Prop Ecology Viewer
- Surface Context Inspector
- Chunk Streaming Profiler
- Golden Seed Gallery

### STEP 21 — CI / validation gates

- golden seed reports
- visual snapshots
- seam metrics
- budget metrics
- save migration tests
- Codex checklist

### STEP 22 — Large world polish

- world map summaries
- far vista composition
- biome macro navigation
- streaming prediction
- memory pressure policies

### STEP 23 — Authoring pipeline

- data-driven definitions
- import/export
- asset manifests
- validation hints
- docs for designers/Codex

### STEP 24 — RPG/settlement integration

- civilization fields
- cultivated biomes
- ruins overgrowth
- roads/paths influencing ecology
- resources and economy hooks

### STEP 25 — Final production hardening

- profiling Metal 4
- cache stress tests
- save migration corpus
- deterministic replay
- release profiles codex/dev/full

---

## 25. Codex implementation rules

Codex doit respecter :

```text
1. Ne jamais mettre de logique biome/terrain dans RenderCoreMetal4.
2. Ne jamais choisir de biome par chunk local random.
3. Toujours utiliser WorldSeed + GeneratorVersionTable.
4. Toujours prévoir tests coordonnées négatives et chunk borders.
5. Tout nouveau generator doit avoir stable hash/version.
6. Tout cache doit déclarer s'il est rebuildable.
7. Tout nouveau format doit être Codable/diffable si possible.
8. Tout bridge Surface/Props/Motion doit passer par contracts EngineCore.
9. Aucun asset lourd requis pour tests Codex.
10. Chaque Step doit mettre à jour docs + tracker + decisions.
```

---

## 26. Définition finale

**Biome Forge** est le système qui transforme des champs climatiques, géologiques, hydrologiques et écologiques en biomes, sous-biomes, écotones, micro-habitats, états de surface, densités de props, ambiances, règles de motion contact et matériaux world-aware.

**Terrain Forge** est le système qui transforme le seed, le WorldGeoDNA, les recettes de terrain, les feature graphs, l'hydrologie, l'érosion et les contraintes jouables en un terrain infini, streamable, LOD-aware, cohérent avec la topologie et compatible avec le gameplay.

Ensemble, ils deviennent la colonne vertébrale du monde IsoForge :

```text
WorldSeed
  → terrains crédibles
  → biomes cohérents
  → sous-biomes naturels
  → transitions vivantes
  → surfaces procédurales
  → props écologiques
  → contacts animation
  → audio/FX contextuels
  → saves légères
  → streaming moderne
  → rendu Metal 4 scalable
```

La cible n'est pas seulement de générer beaucoup de terrains. La cible est de générer des mondes où chaque zone semble avoir une raison d'exister.

