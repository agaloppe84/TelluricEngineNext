# IsoForge Engine — Motion Forge / ProtoMotion Lab / World-Aware Procedural Animation

> **Document de référence pour Codex et pour la conception IsoWorld / IsoForge.**  
> Objectif : définir notre version interne, ambitieuse et moderne, inspirée par MotionBricks et ProtoMotions, mais conçue pour un moteur Apple Silicon / Metal 4, procédural, déterministe, chunké, streamé autour du joueur, et intégré à nos systèmes terrain, props, LOD, Surface Forge, save, tools et runtime.

---

## 0. Résumé exécutif

IsoForge ne doit pas construire un système d'animation classique basé sur une forêt de clips, de blend trees, de transitions manuelles et de correctifs IK ajoutés à la fin. Pour notre moteur, la bonne cible est un système **intent-driven**, **world-aware**, **contact-aware**, **physics-informed**, **seeded/deterministic**, capable de piloter les personnages, créatures et interactions à partir d'intentions haut niveau, de primitives intelligentes, de contacts, de style, de trajectoire et de contexte monde.

La technologie cible s'appelle ici :

# **Motion Forge**

Motion Forge regroupe deux grands sous-systèmes :

1. **IsoMotion Runtime** : runtime natif Swift/Metal 4, déterministe, data-oriented, qui produit les poses, les contacts, les interactions et les snapshots d'animation utilisés par le rendu, l'audio, les FX, le gameplay et les saves.
2. **ProtoMotion Lab** : laboratoire offline inspiré de ProtoMotions pour importer, retargeter, analyser, entraîner, valider et exporter des motion packs, policies, primitives et datasets internes. Il peut utiliser Python/PyTorch/ONNX/CoreML en outil, mais le runtime du jeu reste natif et contrôlé.

Le principe central :

```text
Player Input / AI / World Event / Smart Object
        ↓
MotionIntent
        ↓
Motion Planner + Primitive Resolver
        ↓
Smart Primitive / Latent Motion / Contact Plan
        ↓
Pose Generator + Warping + IK + Physics Correction
        ↓
AnimationFrameSnapshot
        ↓
Metal 4 GPU Skinning + FX + Audio + Gameplay
```

Ce système doit être conçu dès le départ pour le monde IsoWorld :

- monde procédural construit autour du joueur ;
- chunks streamés et mis en cache ;
- terrain vertical, hydrologie, surfaces et biomes ;
- props procéduraux interactifs ;
- LOD/virtualisation custom inspirée de Nanite ;
- Surface Forge pour matériaux/surfaces world-aware ;
- Apple Silicon / Metal 4-first ;
- tools séparés du runtime ;
- déterminisme, versioning et save spine solides.

---

## 1. Sources et inspirations

### 1.1 Inspirations externes

Ce document s'inspire conceptuellement de :

- **MotionBricks** — Scalable Real-Time Motions with Modular Latent Generative Model and Smart Primitives. Le projet annonce un framework de motion generation temps réel, un backbone latent modulaire, des smart primitives, une interface plug-and-play pour navigation et interactions objet/scène, et des résultats de 15 000 FPS / 2 ms de latence / 350 000+ motion skills dans leur contexte NVIDIA/UE5/recherche.
- **ProtoMotions 3** — framework GPU-accelerated pour apprendre des contrôleurs d'humanoïdes / digital humans physiquement simulés, avec retargeting, motion imitation, RL, multi-simulateurs, export ONNX et terrain navigation.
- **Apple Metal 4** — API bas niveau moderne pour GPU Apple, avec intégration rendering/compute/ML, MetalFX, MPS/MPSGraph, pipeline/shader compilation plus efficace, et outils natifs de profiling/debug/capture.
- **Unreal Nanite** — inspiration conceptuelle pour notre virtualisation LOD/cluster/streaming, mais sans copier l'implémentation. Notre système reste custom, adapté à Metal 4 et au monde chunké d'IsoForge.

### 1.2 Contraintes internes IsoForge

Les fichiers projet relus posent déjà les principes à conserver :

- `EngineCore` pur, sans SwiftUI, sans Metal.
- `RenderCoreMetal4` séparé, Metal 4-first.
- `IsoRuntimeApp` minimal : menu, loading, debug world, real world.
- `IsoTools` séparé du runtime.
- RenderGraph, ResourceGraph, residency, shader/pipeline cache dès le départ.
- Apple GPU tools comme source officielle pour debug/profiling bas niveau.
- Pas de preview system permanent qui devient de la dette.
- GitHub pour code/specs/manifests/tests, assets lourds hors repo ou via profils de bootstrap.
- Seed + versions + deltas pour tout système procédural persistant.

### 1.3 Règle de licence / usage

Motion Forge ne doit pas être une copie directe de MotionBricks ou ProtoMotions. C'est une architecture interne inspirée par leurs idées : motion features, primitives intelligentes, latent motion, retargeting, policy lab, motion imitation, contacts et contrôle par intention.

Règles :

- Le code externe ne doit pas être importé sans audit licence explicite.
- Les poids pré-entraînés et datasets ne doivent jamais être supposés libres commercialement.
- Les datasets AMASS, BONES-SEED, mocap, avatars, rigs, meshes ou checkpoints doivent être audités séparément.
- Les formats internes `.isomotion`, `.isoprimitive`, `.isomotionpack`, `.isomodelmanifest` doivent être indépendants.
- Le runtime IsoForge doit rester compilable/testable sans assets ou modèles NVIDIA.

---

## 2. Vision ultime du moteur

IsoForge doit devenir un moteur procédural moderne avec une colonne vertébrale cohérente :

```text
WorldSeed
  ↓
WorldDNA / RPG DNA / Surface DNA / Motion DNA
  ↓
Chunked World Generation
  ↓
Terrain + Biomes + Props + Settlements + Surfaces
  ↓
Virtualized Geometry + Surface Residency + Motion Context
  ↓
Runtime Snapshots
  ↓
Metal 4 RenderGraph / GPU Skinning / FX / Audio
  ↓
Save Deltas + Replay + Tools Validation
```

Motion Forge n'est pas un module isolé. Il dépend du monde et nourrit le monde.

Exemple : un personnage marche dans un marais enneigé près d'un vieux pont.

```text
TerrainSampleGrid
  → pente, hauteur, waterDepth, mud, shore, cliff
BiomeWeights
  → marais 0.68 + taiga 0.32
SurfaceState
  → wetness 0.72, snow 0.18, moss 0.44
PropSystem
  → racines, pierres, passerelle, roseaux
SettlementSystem
  → vieux pont, bois humide, garde-corps cassé
MotionIntent
  → traverse carefully, speed 0.8, cautious style
Motion Forge
  → pas courts, appuis testés, bras équilibrés, trajectoire contourne racine, footstep splash/mud audio, decals de traces
```

Ce niveau d'intégration est impossible avec une animation graph classique purement clip-based.

---

## 3. Principes non négociables

### 3.1 Intent-driven, pas clip-driven

Le système doit commencer par une intention :

```swift
struct MotionIntent {
    let actorID: ActorID
    let intentKind: MotionIntentKind
    let desiredVelocity: SIMD3<Float>
    let desiredHeading: Float
    let target: MotionTarget?
    let style: MotionStyleDescriptor
    let urgency: Float
    let constraints: MotionConstraintSet
    let deterministicSeed: UInt64
    let version: MotionGeneratorVersion
}
```

Le clip ne doit être qu'une ressource possible parmi d'autres. Le runtime choisit/génère/adapte une motion en fonction du contexte.

### 3.2 Contact-aware partout

Le contact n'est pas un correctif cosmétique. Le contact est une donnée moteur centrale : pieds, mains, genoux, corps, outils, armes, surfaces, props, eau, neige, boue, escalade, portes, coffres, véhicules, animaux.

### 3.3 Monde comme entrée du mouvement

Chaque motion doit pouvoir consommer :

- pente ;
- hauteur ;
- normale terrain ;
- friction ;
- wetness ;
- snow ;
- mud ;
- moss ;
- obstacle bas ;
- affordances de props ;
- anchors de traversal ;
- zones dangereuses ;
- densité de végétation ;
- LOD/collision representation ;
- tags gameplay/RPG.

### 3.4 Déterminisme strict côté décisions

Les décisions doivent être reproductibles :

```text
same seed
+ same world generator versions
+ same motion graph version
+ same actor DNA
+ same context quantization
+ same intent stream
= same selected primitives / contact plan / motion IDs / save-visible outcome
```

Le rendu de pose GPU peut être “visuellement stable”, mais les décisions gameplay/save doivent être issues de chemins CPU déterministes, versionnés et testables.

### 3.5 Runtime Apple-native

Pas de runtime Python, CUDA, MuJoCo ou PyTorch dans l'app finale. Ces technologies peuvent exister dans ProtoMotion Lab offline, mais le runtime est :

```text
Swift / C++ minimal si nécessaire / Metal 4 / MPSGraph ou Core ML optionnel / Apple Silicon-first
```

### 3.6 Tools-first, runtime-light

Les outils lourds doivent vivre dans `IsoTools`, pas dans le runtime de jeu.

Le runtime contient :

- motion packs compilés ;
- primitive graph compilé ;
- policies validées ;
- tables compactes ;
- buffers GPU ;
- debugging markers légers.

Les tools contiennent :

- éditeurs ;
- previews ;
- validators ;
- importers ;
- retargeting ;
- training lab ;
- benchmark lab ;
- visual diff.

---

## 4. Architecture globale IsoForge

```text
IsoForgeEngine
├── EngineCore
│   ├── World
│   ├── Chunks
│   ├── Terrain
│   ├── Biomes
│   ├── Props
│   ├── Settlements
│   ├── Characters
│   ├── MotionForge
│   ├── SurfaceForge
│   ├── RPG
│   ├── Save
│   └── Validation
├── RenderCoreMetal4
│   ├── RenderGraph
│   ├── ResourceGraph
│   ├── GeometryVirtualization
│   ├── SurfaceResidency
│   ├── Skinning
│   ├── MotionDebugRender
│   ├── FX
│   └── MetalToolsIntegration
├── IsoTools
│   ├── WorldLab
│   ├── TerrainLab
│   ├── SurfaceForgeLab
│   ├── MotionForgeLab
│   ├── ProtoMotionLab
│   ├── CharacterLab
│   ├── PropLab
│   ├── LODLab
│   ├── SaveInspector
│   ├── SeedGallery
│   └── BenchmarkLab
├── IsoRuntimeApp
│   ├── AppShell
│   ├── MainMenu
│   ├── LoadingPipeline
│   ├── DebugWorld
│   └── RealWorld
└── IsoAssets
    ├── Manifests
    ├── SamplesTiny
    ├── BootstrapProfiles
    └── Validators
```

Motion Forge est dans `EngineCore/MotionForge` pour les contrats purs et dans `RenderCoreMetal4/Skinning` pour l'exécution GPU. Les tools dédiés sont séparés.

---

## 5. Monde procédural autour du joueur

### 5.1 World Prepare Pipeline

Le monde réel ne doit jamais s'ouvrir directement depuis le menu. Il passe par un pipeline de préparation :

```text
Main Menu
  ↓
Seed Input / Save Continue
  ↓
WorldPreparePipeline
  ↓
WorldSession
  ↓
RealWorldRuntime
```

Préparation minimale :

- normaliser le seed ;
- générer `WorldDNA` ;
- générer `WorldSurfaceDNA` ;
- générer `WorldMotionDNA` ;
- résoudre un spawn praticable ;
- construire les chunks initiaux ;
- préchauffer render pipelines et motion packs critiques ;
- précharger root LOD geometry ;
- précharger surfaces proches ;
- précharger motion primitives de base ;
- valider collisions et traversal autour du spawn ;
- publier une progression pondérée.

### 5.2 Chunk Model

```swift
struct ChunkCoordinate: Hashable, Codable {
    let x: Int32
    let z: Int32
}

struct ChunkRuntimeRecord {
    let coord: ChunkCoordinate
    let generationVersion: GeneratorVersionTable
    let biomeSignature: BiomeSignature
    let terrainState: TerrainChunkState
    let propState: PropChunkState
    let settlementState: SettlementChunkState?
    let surfaceState: SurfaceChunkState
    let traversalState: TraversalChunkState
    let motionAffordanceState: MotionAffordanceChunkState
    let lodState: ChunkLODState
    let persistenceState: ChunkPersistenceState
}
```

### 5.3 Streaming robuste

Le streaming doit être multi-couches :

```text
Candidate Ring
  → chunks potentiellement nécessaires bientôt
Simulation Ring
  → chunks nécessaires gameplay/collision/navigation
Render Ring
  → chunks visibles ou proches du visible
Motion Ring
  → chunks dont les affordances/contact data sont nécessaires
Asset Ring
  → pages geometry/surface/motion à précharger
Persistence Ring
  → régions dirty à flush/compacter
```

### 5.4 États d'un chunk

```text
unseen
seedKnown
metadataReady
cpuGenerated
collisionReady
motionAffordancesReady
renderPayloadReady
surfacePagesRequested
geometryPagesRequested
resident
visible
simulated
dirty
evictable
coldCached
persisted
```

### 5.5 Anti-thrashing

Stratégies :

- hysteresis radius ;
- budgets par frame ;
- priorité par distance, visibilité, vitesse joueur, direction caméra, intent joueur ;
- deadline scheduling ;
- root resident fallback ;
- LOD fallback acceptable ;
- cache disque rebuildable ;
- invalidation par versions de générateurs ;
- métriques de churn ;
- préfetch directionnel selon trajectoire.

---

## 6. IVDS — LOD/Props inspiré Nanite

Notre système LOD/props s'appelle :

# **IVDS — Iso Virtual Detail System**

Objectif : virtualiser le détail géométrique et prop-level autour du joueur, sans exploser CPU/GPU/mémoire.

### 6.1 Concept

```text
Procedural Geometry Source
  ↓
Cluster Builder
  ↓
VirtualClusterTree
  ↓
GeometryPage Cache
  ↓
GPU Culling / LOD Selection
  ↓
Indirect Draw / Meshlet Path
```

### 6.2 Données principales

```swift
struct VirtualGeometryAsset {
    let id: VirtualGeometryAssetID
    let sourceHash: ContentHash
    let clusterTreeRoot: ClusterNodeID
    let bounds: AABB
    let materialBindings: [MaterialBindingID]
    let collisionProxyID: CollisionProxyID
    let buildVersion: GeometryBuildVersion
}

struct VirtualCluster {
    let id: ClusterID
    let parent: ClusterID?
    let children: [ClusterID]
    let bounds: AABB
    let cone: BackfaceCone
    let screenError: Float
    let geometryPageID: GeometryPageID
    let materialRange: MaterialRange
}
```

### 6.3 Domaine terrain

Le terrain ne doit pas être traité comme un mesh monolithique. Il faut :

- clipmaps / quadtree terrain ;
- chunks edge-preserving ;
- transitions crack-free ;
- water/shore/cliff masks ;
- collision LOD séparé ;
- traversal LOD conservateur ;
- virtual displacement/micro-geometry près du joueur ;
- fallback bas coût pour far field.

### 6.4 Domaine props

Catégories :

- rochers : clusters parfaits pour IVDS ;
- arbres : pipeline mixte trunk clusters + foliage impostors ;
- bâtiments : HLOD par façade/toit/étage/groupe ;
- settlements : HLOD par îlots, rues, silhouettes ;
- objets interactifs : root LOD toujours collision/interaction-ready ;
- personnages : pas Nanite-like principal, plutôt skinned LOD + impostors lointains.

### 6.5 Interaction avec Motion Forge

Motion Forge consomme une représentation gameplay indépendante du LOD rendu :

```text
Render LOD peut être simplifié.
Motion/Traversal collision doit rester fiable.
Smart Object affordances doivent exister même si le mesh haute résolution n'est pas résident.
```

Pour chaque prop interactif :

```swift
struct MotionAffordanceDescriptor {
    let affordanceID: AffordanceID
    let propID: PropInstanceID
    let kind: MotionAffordanceKind
    let sockets: [MotionSocket]
    let approachZones: [ApproachZone]
    let contactTargets: [ContactTarget]
    let requiredPrimitiveTags: [MotionPrimitiveTag]
    let collisionProxy: CollisionProxyID
    let lodMinimum: InteractionLOD
}
```

---

## 7. Motion Forge — vue d'ensemble

Motion Forge est composé de 11 sous-systèmes :

```text
Motion Forge
├── 1. Motion Intent Layer
├── 2. Motion Context Layer
├── 3. Smart Primitive Graph
├── 4. Motion Feature Representation
├── 5. Latent Motion / Motion Tokens
├── 6. Contact Planner
├── 7. Pose Generator
├── 8. Warping + IK + Inertialization
├── 9. Physics Bridge / Active Body Layer
├── 10. Determinism & Save Record
└── 11. Motion Debug & Validation Suite
```

### 7.1 Flux par frame

```text
Input / AI / Event
  ↓
IntentCollector
  ↓
WorldMotionContextBuilder
  ↓
PrimitiveResolver
  ↓
TrajectoryPlanner
  ↓
ContactPlanner
  ↓
MotionCandidateGenerator
  ↓
PoseGenerator
  ↓
ProceduralCorrectionStack
  ↓
PhysicsBridge
  ↓
AnimationFrameSnapshot
  ↓
RenderCoreMetal4 + Audio + FX + Gameplay
```

### 7.2 Flux événementiel

Pour les interactions longues :

```text
Interaction Request
  ↓
SmartObjectResolver
  ↓
Approach Plan
  ↓
Phase Graph
  ↓
Contact Schedule
  ↓
Motion Execution State
  ↓
Success / Fail / Interrupt / Recover
```

---

## 8. Motion Intent Layer

### 8.1 Intent kinds

```swift
enum MotionIntentKind: Codable {
    case idle
    case locomotion
    case traversal
    case smartObjectInteraction
    case combat
    case toolUse
    case social
    case reaction
    case fall
    case recover
    case swim
    case mount
    case scriptedCinematic
}
```

### 8.2 Intent priority

Les intentions peuvent être concurrentes :

```text
joueur avance
+ regarde cible
+ porte objet
+ marche dans boue
+ évite obstacle
+ reçoit impact léger
```

Il faut un resolver :

```text
Hard constraints
  → collisions, death, fall, root lock, interaction lock
Gameplay constraints
  → input, combat, traversal, inventory
Soft style constraints
  → mood, fatigue, injury, weather, personality
Cosmetic constraints
  → idle fidgets, gaze, breathing
```

### 8.3 Motion Style Descriptor

```swift
struct MotionStyleDescriptor: Codable, Hashable {
    let base: MotionStyleBase
    let energy: Float
    let caution: Float
    let injury: InjuryState
    let fatigue: Float
    let emotion: EmotionState
    let equipmentLoad: Float
    let biomeAdaptation: Float
    let weatherAdaptation: Float
    let characterDNAInfluence: Float
}
```

Styles possibles :

- neutral ;
- cautious ;
- injured leg ;
- injured torso ;
- exhausted ;
- stealth ;
- combat ready ;
- panic ;
- confident ;
- heavy load ;
- slippery ground ;
- snow walk ;
- mud walk ;
- climbing ;
- swimming ;
- social idle ;
- ritual / fantasy / creature style.

---

## 9. Motion Context Layer

Le contexte motion agrège les informations monde nécessaires.

```swift
struct WorldMotionContext {
    let actor: ActorMotionState
    let terrain: TerrainMotionContext
    let surfaces: SurfaceMotionContext
    let props: NearbyMotionAffordances
    let traversal: TraversalContext
    let settlement: SettlementMotionContext?
    let hazards: HazardContext
    let camera: CameraMotionContext
    let lod: MotionLODContext
    let deterministicFrame: SimulationTick
}
```

### 9.1 Terrain context

```swift
struct TerrainMotionContext {
    let sampleGridID: TerrainSampleGridID
    let localHeight: Float
    let localNormal: SIMD3<Float>
    let slope: Float
    let curvature: Float
    let waterDepth: Float
    let cliffMask: Float
    let shoreMask: Float
    let obstacleCandidates: [ObstacleCandidate]
    let ledgeCandidates: [LedgeCandidate]
}
```

### 9.2 Surface context

```swift
struct SurfaceMotionContext {
    let primaryMaterial: TerrainMaterialKind
    let secondaryMaterial: TerrainMaterialKind?
    let friction: Float
    let compliance: Float
    let wetness: Float
    let snow: Float
    let mud: Float
    let moss: Float
    let dust: Float
    let soundSurfaceTag: AudioSurfaceTag
    let fxSurfaceTag: FXSurfaceTag
}
```

### 9.3 Prop and smart object context

```swift
struct NearbyMotionAffordances {
    let byPriority: [MotionAffordanceDescriptor]
    let byDistance: [MotionAffordanceDescriptor]
    let visibleOnly: [MotionAffordanceDescriptor]
    let interactionReachable: [MotionAffordanceDescriptor]
}
```

---

## 10. Smart Primitive Graph

Le Smart Primitive Graph est notre version interne de l'idée MotionBricks : assembler des primitives intelligentes au lieu de câbler à la main des centaines de transitions.

### 10.1 Primitive categories

```text
SmartLocomotionPrimitive
SmartTraversalPrimitive
SmartObjectPrimitive
SmartCombatPrimitive
SmartToolUsePrimitive
SmartSocialPrimitive
SmartReactionPrimitive
SmartCreaturePrimitive
SmartVehicleMountPrimitive
```

### 10.2 Smart Locomotion

Entrées :

- vitesse désirée ;
- heading désiré ;
- direction caméra ;
- style ;
- surface ;
- pente ;
- obstacle court terme ;
- fatigue/injury ;
- équipement ;
- character DNA.

Sorties :

- trajectoire root ;
- pas planifiés ;
- contact schedule ;
- pose stream ;
- gait state ;
- footstep events ;
- correction budget.

### 10.3 Smart Traversal

Primitives :

- step up ;
- step down ;
- vault ;
- hop ;
- jump ;
- mantle ;
- climb ledge ;
- climb ladder/rope ;
- squeeze through ;
- balance beam ;
- slide slope ;
- recover slip ;
- swim enter/exit ;
- shore transition.

### 10.4 Smart Objects

Le Smart Object ne donne pas un clip. Il décrit une interaction.

```json
{
  "id": "object.chest.wooden_small.open",
  "kind": "smartObjectPrimitive",
  "phases": ["approach", "align", "reach", "contact", "actuate", "recover"],
  "requiredSockets": ["right_hand", "left_foot", "right_foot"],
  "approachZones": ["front_arc"],
  "contactTargets": ["handle_socket"],
  "styleTags": ["utility", "low_height", "wood"],
  "interruptPolicy": "recoverable"
}
```

Interactions :

- ouvrir coffre ;
- ouvrir porte ;
- tirer levier ;
- ramasser objet ;
- poser objet ;
- s'asseoir ;
- se relever ;
- inspecter plante ;
- boire à une source ;
- couper arbre ;
- miner roche ;
- forger ;
- grimper à une corde ;
- utiliser échelle ;
- pousser caisse ;
- tirer corde ;
- allumer feu ;
- dormir ;
- cuisiner ;
- dialoguer ;
- soigner ;
- ritualiser.

### 10.5 Primitive Graph schema

```swift
struct MotionPrimitiveGraph: Codable {
    let id: MotionPrimitiveGraphID
    let version: MotionPrimitiveGraphVersion
    let nodes: [MotionPrimitiveNode]
    let edges: [MotionPrimitiveEdge]
    let parameters: [MotionGraphParameter]
    let validationRules: [MotionGraphValidationRule]
}
```

---

## 11. Motion Feature Representation

La représentation doit séparer root motion, body motion, contacts et contexte.

### 11.1 Frame representation

```swift
struct IsoMotionFrame: Codable {
    let frameIndex: Int32
    let rootPosition: SIMD3<Float>
    let rootHeading: Float
    let rootVelocityLocal: SIMD3<Float>
    let rootAngularVelocity: Float
    let pelvisHeight: Float
    let jointRotations6D: [JointRotation6D]
    let jointPositionsModel: [SIMD3<Float>]
    let jointVelocitiesModel: [SIMD3<Float>]
    let contacts: MotionContactBits
    let surfaceTags: MotionSurfaceTags
    let phase: MotionPhase
}
```

### 11.2 Motion feature vector

```swift
struct MotionFeatureVector {
    let trajectorySamples: [TrajectorySample]
    let rootFeatures: RootFeatureBlock
    let jointFeatures: JointFeatureBlock
    let contactFeatures: ContactFeatureBlock
    let styleFeatures: StyleFeatureBlock
    let environmentFeatures: EnvironmentFeatureBlock
}
```

### 11.3 Contacts

Contacts par défaut :

- left foot heel ;
- left foot toe ;
- right foot heel ;
- right foot toe ;
- left hand palm ;
- right hand palm ;
- knees ;
- hips/pelvis ;
- back/shoulder for falls ;
- held item contacts ;
- weapon/tool contact.

### 11.4 Environment features

- slope ;
- height delta next 1m/2m ;
- friction ;
- waterDepth ;
- obstacle height ;
- clearance ;
- ledge presence ;
- target socket relative pose ;
- approach arc ;
- support polygon confidence.

---

## 12. Latent Motion et Motion Tokens

Le système ultime peut utiliser des modèles latents, mais avec discipline.

### 12.1 Trois niveaux de génération

```text
Level A — deterministic procedural / clip adapted
Level B — latent motion tokens from internal packs
Level C — neural pose/root model offline or runtime-assisted
```

### 12.2 MotionToken

```swift
struct MotionToken: Codable, Hashable {
    let tokenID: UInt32
    let vocabularyID: MotionVocabularyID
    let durationTicks: UInt16
    let tags: MotionTokenTags
    let contactSignature: ContactSignature
    let rootDeltaClass: RootDeltaClass
}
```

### 12.3 Runtime strategy

Le runtime peut sélectionner des tokens/primitives de manière déterministe, puis générer une pose :

```text
Intent + Context
  ↓
Token candidates
  ↓
Scoring deterministic
  ↓
Token sequence
  ↓
Pose decode / procedural adaptation
```

### 12.4 ML boundary

Le ML ne doit pas prendre des décisions non traçables pour les saves. Il peut :

- proposer des poses ;
- décoder des tokens ;
- générer du motion fill ;
- servir d'outil offline ;
- faire du denoising pose ;
- aider au retargeting ;
- générer des variations.

Mais le save record doit enregistrer :

- primitive ID ;
- token IDs ;
- seed ;
- model version ;
- context quantized ;
- interaction phase ;
- contact targets.

---

## 13. Contact Planner

### 13.1 Rôle

Le Contact Planner est le cœur de la qualité. Il planifie où et quand les pieds, mains et objets entrent en contact avec le monde.

### 13.2 ContactPatch

```swift
struct ContactPatch: Codable {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let tangent: SIMD3<Float>
    let material: SurfaceMaterialID
    let friction: Float
    let compliance: Float
    let wetness: Float
    let stability: Float
    let walkability: Float
    let tags: ContactPatchTags
}
```

### 13.3 Footstep scoring

Score de contact :

```text
height continuity
+ normal alignment
+ friction confidence
+ slope safety
+ obstacle clearance
+ gait phase match
+ style match
+ surface preference
+ gameplay safety
- water penalty
- mud sink penalty
- edge risk
- collision overlap
```

### 13.4 Hand contact scoring

Pour smart objects :

```text
socket reachability
+ arm comfort
+ torso orientation
+ grip type match
+ approach phase
+ collision clearance
+ tool state
- hyperextension
- occluded target
```

---

## 14. Pose Generator

### 14.1 Sources de pose

Le Pose Generator peut combiner :

- clips importés ;
- motion matching ;
- token decoder ;
- procedural gait ;
- smart primitive phase pose ;
- ML model output ;
- active ragdoll feedback ;
- key poses d'interaction ;
- additive styles.

### 14.2 Sortie

```swift
struct GeneratedPose {
    let localJointTransforms: [JointTransform]
    let rootMotion: RootMotionDelta
    let contacts: ContactSchedule
    let confidence: Float
    let source: GeneratedPoseSource
    let deterministicRecord: MotionDeterminismRecord
}
```

---

## 15. Warping, IK et corrections procédurales

Ordre recommandé :

```text
1. Intent + base pose
2. Root trajectory adjustment
3. Motion warping
4. Stride warping
5. Orientation warping
6. Slope warping
7. Foot placement
8. Pelvis compensation
9. Spine balance
10. Hand IK / object contacts
11. Look/gaze/aim
12. Inertialization
13. Physics bridge correction
14. Final pose constraints
```

### 15.1 Règles

- Les corrections doivent être bornées et mesurables.
- Si le budget de correction dépasse un seuil, il faut replanifier plutôt que tordre le squelette.
- Toute correction importante doit être exposée aux outils.
- Les corrections doivent produire des events FX/audio cohérents.

---

## 16. Physics Bridge / ProtoMotion Runtime Layer

Le Physics Bridge est notre pont entre animation et physique. Il ne doit pas rendre le jeu injouable, mais il apporte crédibilité : poids, équilibre, contacts, impacts, chutes, récupération.

### 16.1 Modes

```text
kinematic
animation-driven
physics-assisted
active ragdoll partial
full ragdoll
recovery policy
```

### 16.2 Balance controller

Inputs :

- centre de masse ;
- support polygon ;
- vitesse root ;
- contacts actifs ;
- pente ;
- friction ;
- force externe ;
- fatigue/injury.

Outputs :

- posture compensation ;
- arm swing for balance ;
- step correction ;
- stumble trigger ;
- fall trigger ;
- recovery intent.

### 16.3 ProtoMotion Lab linkage

ProtoMotion Lab peut entraîner/tester des policies de récupération, marche terrain difficile, balance et imitation, mais le runtime doit consommer des exports validés, pas dépendre du lab.

---

## 17. ProtoMotion Lab — outil offline inspiré ProtoMotions

ProtoMotion Lab est un outil interne, pas une dépendance runtime.

### 17.1 Objectifs

- importer des mocaps ;
- retargeter vers le skeleton IsoForge ;
- calculer features motion ;
- générer motion tokens ;
- entraîner/tester des policies ;
- simuler terrain difficile ;
- valider contact/foot sliding ;
- exporter motion packs ;
- exporter modèles optionnels ONNX/CoreML ;
- produire des rapports qualité.

### 17.2 Architecture

```text
ProtoMotionLab
├── DatasetImporter
├── SkeletonMapper
├── RetargetSolver
├── MotionFeatureExtractor
├── ContactAnnotator
├── TerrainScenarioGenerator
├── PolicyTrainingHarness
├── MotionTokenizer
├── MotionPackCompiler
├── ONNX/CoreML Export Bridge
├── QualityValidator
└── ReportGenerator
```

### 17.3 Retargeting

Étapes :

```text
source skeleton
  ↓
joint mapping
  ↓
scale / morphology fit
  ↓
root transform normalization
  ↓
feet/hands contact preservation
  ↓
joint limits
  ↓
IsoSkeleton output
  ↓
validation
```

### 17.4 Training terrain

Scénarios générés :

- pente douce ;
- pente forte ;
- escaliers irréguliers ;
- rochers ;
- boue ;
- neige ;
- sol glissant ;
- eau peu profonde ;
- racines ;
- pont cassé ;
- falaise ;
- chute/récupération ;
- pousser/tirer ;
- porter charge.

### 17.5 Exports

```text
.isomotionpack
.isoprimitivepack
.isomotiontokens
.isopolicy
.isoskeletonmap
.isomotionreport
```

---

## 18. Motion Forge Lab — outil auteur/runtime preview

Motion Forge Lab est l'outil interactif pour designer et déboguer les primitives.

### 18.1 Vues

- Primitive Graph Editor ;
- Motion Timeline ;
- Contact Track Viewer ;
- Footstep Planner Debug ;
- Smart Object Authoring ;
- Terrain Interaction Sandbox ;
- Style Mixer ;
- Character DNA Motion Preview ;
- LOD/Motion Cost View ;
- Determinism Replay View ;
- Motion Pack Browser ;
- Motion Regression Diff.

### 18.2 Smart Object Authoring

L'éditeur permet de placer :

- approach zones ;
- stance zones ;
- hand sockets ;
- foot sockets ;
- gaze targets ;
- tool sockets ;
- collision proxy ;
- phase markers ;
- interrupt/recovery policy ;
- affordance tags.

### 18.3 Validation

Chaque primitive doit passer :

- reachability ;
- collision clearance ;
- joint limit ;
- foot sliding ;
- contact stability ;
- phase continuity ;
- deterministic replay ;
- LOD fallback ;
- save/load roundtrip ;
- runtime budget.

---

## 19. Metal 4 integration

### 19.1 Rendu animation

`RenderCoreMetal4/Skinning` doit gérer :

- GPU skinning ;
- skeleton palette buffers ;
- morph targets éventuels ;
- cloth/hair proxy plus tard ;
- motion vectors ;
- animation debug overlays GPU ;
- character LOD ;
- impostors lointains ;
- indirect draw pour crowd ;
- resource residency.

### 19.2 ML / MPS / MPSGraph

Usage recommandé :

```text
Authoritative decisions
  → CPU deterministic, EngineCore.

Pose decode optional
  → MPSGraph/CoreML/Metal ML path if stable and versioned.

Tools/training
  → Python/PyTorch offline, possible export ONNX/CoreML.

Runtime fallback
  → deterministic non-neural path mandatory.
```

### 19.3 Metal developer tools

Le moteur doit émettre des labels GPU lisibles :

```text
MotionSkinningPass[player][LOD0]
MotionCrowdSkinningPass[settlement_market][128 actors]
MotionDebugContactPass[chunk 12,-4]
MotionPoseDecodePass[policy humanoid_v03]
MotionVectorPass[character]
```

Le debug bas niveau se fait avec :

- Xcode Metal debugger ;
- Metal Performance HUD ;
- Metal System Trace ;
- API/shader validation ;
- `gpucapture` ;
- `gpudebug` ;
- `metalperftrace`.

Overlay custom minimal :

- frame time ;
- actor count ;
- skinning cost ;
- active primitives ;
- contact failures ;
- LOD motion tier ;
- seed/replay ID.

---

## 20. Save system et déterminisme

### 20.1 Ce qu'on sauvegarde

On ne sauvegarde pas chaque pose frame par frame sauf replay/debug. On sauvegarde :

```swift
struct MotionSaveRecord: Codable {
    let actorID: ActorID
    let currentIntent: MotionIntentSnapshot
    let activePrimitiveID: MotionPrimitiveID
    let primitivePhase: MotionPhase
    let deterministicSeed: UInt64
    let motionGraphVersion: MotionPrimitiveGraphVersion
    let motionPackVersion: MotionPackVersion
    let tokenSequenceWindow: [MotionToken]
    let contactTargetIDs: [ContactTargetID]
    let elapsedTicks: UInt64
    let interruptState: MotionInterruptState
}
```

### 20.2 Replays

Pour debug :

```text
Intent Stream
+ Quantized Context Stream
+ Selected Primitive IDs
+ Contact Decisions
+ Pose Hashes
```

### 20.3 Versioning

Tout pack doit contenir :

- generator version ;
- skeleton version ;
- motion feature version ;
- primitive graph version ;
- model version ;
- dataset source manifest ;
- license manifest ;
- content hash.

---

## 21. Interaction avec Surface Forge

Motion Forge et Surface Forge doivent échanger des données.

### 21.1 Surface → Motion

Surface Forge fournit :

- friction ;
- compliance ;
- wetness ;
- snow depth ;
- mud sink ;
- moss slipperiness ;
- dust ;
- sound surface tag ;
- FX surface tag.

### 21.2 Motion → Surface

Motion Forge produit :

- footprints ;
- mud deformation deltas ;
- snow compression masks ;
- trample maps ;
- wet splash decals ;
- dust puffs ;
- scratch/scorch/wear interactions.

### 21.3 Runtime loop

```text
Motion contact event
  ↓
FX event + Audio event
  ↓
Surface delta candidate
  ↓
Save dirty region
  ↓
Surface page invalidation/rebuild if needed
```

---

## 22. Interaction avec Props et Settlements

### 22.1 Props interactifs

Chaque prop interactif doit exposer :

```text
stable ID
collision proxy
affordance descriptor
approach zones
sockets
state machine
motion primitive tags
surface tags
audio/FX tags
save delta support
```

### 22.2 Settlements

Les settlements génèrent des affordances :

- portes ;
- escaliers ;
- bancs ;
- comptoirs ;
- forges ;
- lits ;
- échelles ;
- ponts ;
- fenêtres ;
- palissades ;
- quais ;
- puits ;
- autels ;
- ateliers ;
- mines.

Motion Forge ne doit pas connaître la génération bâtiment en détail. Il consomme des descriptors.

---

## 23. Interaction avec RPG DNA

Les personnages doivent bouger selon leur identité procédurale :

- âge ;
- taille ;
- morphologie ;
- force ;
- fatigue ;
- blessures ;
- culture ;
- métier ;
- équipement ;
- faction ;
- émotion ;
- météo ;
- terrain familier ou non.

Exemple :

```text
Mineur local en montagne
→ marche stable sur roche, posture lourde, connaît les pentes.

Marchand urbain en marais
→ hésitation, pas prudents, risque de glissade plus fort.
```

---

## 24. Audio et FX liés au mouvement

Motion Forge génère des events :

```swift
struct MotionEvent {
    let actorID: ActorID
    let kind: MotionEventKind
    let position: SIMD3<Float>
    let surface: SurfaceMaterialID
    let intensity: Float
    let seed: UInt64
    let tick: SimulationTick
}
```

Events :

- footstep ;
- hand contact ;
- slide ;
- splash ;
- mud suction ;
- snow crunch ;
- cloth rustle ;
- armor clink ;
- weapon scrape ;
- fall impact ;
- climb grip ;
- prop contact ;
- tool hit ;
- breath effort.

---

## 25. Crowds et NPCs

### 25.1 Motion LOD

```text
LOD0 — full body, full contacts, IK, physics assist
LOD1 — simplified IK, reduced contact checks
LOD2 — clip/token playback, sparse contact validation
LOD3 — impostor/crowd pose, no per-frame IK
LOD4 — simulation-only marker / offscreen state
```

### 25.2 Crowd scheduling

- actor priority ;
- camera relevance ;
- gameplay relevance ;
- interaction relevance ;
- audio relevance ;
- update frequency tiers ;
- pose cache reuse ;
- GPU skinning batches.

### 25.3 NPC smart behavior

Les NPC utilisent les mêmes primitives que le joueur, avec des intents IA :

- patrol ;
- flee ;
- work ;
- carry ;
- socialize ;
- fight ;
- sleep ;
- craft ;
- gather ;
- pray ;
- inspect ;
- trade.

---

## 26. Character system requis

Motion Forge nécessite un Character System sérieux :

- skeleton canonique ;
- retargeting maps ;
- morphology profile ;
- sockets ;
- collision capsule + body parts ;
- equipment slots ;
- footwear profile ;
- hand grip profiles ;
- locomotion capabilities ;
- injury state ;
- animation LOD profile ;
- GPU skinning data.

### 26.1 Skeleton minimal humanoïde

- pelvis ;
- spine 1/2/3 ;
- neck/head ;
- clavicles ;
- upper/lower arms ;
- hands/fingers simplified ;
- upper/lower legs ;
- feet/toes ;
- optional twist bones ;
- weapon/tool sockets.

---

## 27. Outils nécessaires

### 27.1 IsoTools global

Tous les outils listés ci-dessous doivent pouvoir s'ouvrir sans lancer le Real World complet.

### 27.2 Motion Forge Lab

- Primitive Graph Editor ;
- Smart Locomotion Editor ;
- Smart Object Editor ;
- Traversal Primitive Editor ;
- Contact Patch Inspector ;
- Footstep Planner Lab ;
- Style Mixer ;
- Injury/Fatigue Simulator ;
- Equipment Load Preview ;
- Actor DNA Motion Preview ;
- Motion LOD Debugger ;
- Crowd Motion Profiler.

### 27.3 ProtoMotion Lab

- Dataset Importer ;
- License/Source Auditor ;
- Skeleton Mapper ;
- Retarget Solver ;
- Motion Feature Extractor ;
- Motion Tokenizer ;
- Policy Training Harness ;
- Terrain Challenge Generator ;
- Sim2Sim Comparator ;
- ONNX/CoreML Exporter ;
- Golden Motion Validator.

### 27.4 World Interaction Lab

- Smart Props Browser ;
- Affordance Painter ;
- Settlement Interaction Debugger ;
- Path/Approach Zone Viewer ;
- Collision Proxy Viewer ;
- Contact Target Browser.

### 27.5 Surface/FX/Audio integration tools

- Surface Response Viewer ;
- Footstep Audio Matrix ;
- FX Surface Response Preview ;
- Footprint Decal Inspector ;
- Weather Motion Sandbox.

### 27.6 Performance tools

- Motion Budget HUD ;
- GPU Skinning Profiler ;
- Contact Query Profiler ;
- Primitive Resolution Profiler ;
- Motion LOD Heatmap ;
- Capture Script Runner ;
- Metal Trace Report Importer.

### 27.7 Validation tools

- Deterministic Replay Runner ;
- Golden Seed Motion Suite ;
- Motion Snapshot Diff ;
- Foot Sliding Detector ;
- Contact Penetration Detector ;
- Joint Limit Validator ;
- Save/Load Motion Roundtrip ;
- Pack Compatibility Checker.

---

## 28. Asset pipeline

### 28.1 Asset categories

```text
Source mocap
Retargeted motion
Motion features
Motion tokens
Primitive graphs
Smart object descriptors
Skeleton maps
Policies/models
Runtime packs
Debug reports
```

### 28.2 Git strategy

GitHub versionne :

- code ;
- docs ;
- manifests ;
- specs ;
- tiny fixtures ;
- graph JSON ;
- validation config.

Hors GitHub :

- datasets mocap lourds ;
- checkpoints ;
- packs runtime full ;
- captures vidéo ;
- exports lourds.

### 28.3 Manifest obligatoire

```json
{
  "id": "motionpack.humanoid.locomotion.core",
  "version": "1.0.0",
  "kind": "isomotionpack",
  "license": "internal_or_verified",
  "source": "internal",
  "skeleton": "IsoHumanoid_v1",
  "featureVersion": "IsoMotionFeature_v1",
  "files": [
    { "path": "packs/humanoid_core.isomotionpack", "sha256": "..." }
  ],
  "profiles": ["codex", "dev", "full"]
}
```

---

## 29. Formats internes

### 29.1 `.isomotionpack`

Contient :

- skeleton target ;
- clips/features ;
- token tables ;
- contact annotations ;
- style tags ;
- source manifest ;
- validation report ;
- compression blocks.

### 29.2 `.isoprimitivepack`

Contient :

- primitive graphs ;
- smart object primitives ;
- traversal primitives ;
- scoring rules ;
- phase definitions ;
- fallback policies.

### 29.3 `.isopolicy`

Contient :

- model metadata ;
- version ;
- input/output schema ;
- fallback primitive ;
- supported platforms ;
- deterministic boundary ;
- license.

### 29.4 `.isomotionreport`

Contient :

- foot sliding ;
- contact accuracy ;
- joint violations ;
- compression error ;
- playback cost ;
- deterministic hashes ;
- regression screenshots/plots.

---

## 30. Roadmap ultime

### STEP 1 — Repo IsoForge clean + architecture cible

- Nouveau repo GitHub.
- `EngineCore`, `RenderCoreMetal4`, `IsoTools`, `IsoRuntimeApp`, `IsoAssets`.
- Xcode/Swift/macOS cible moderne.
- Build wrapper local.
- CI locale Codex.
- Asset bootstrap profiles.

DoD : build app vide + tests EngineCore + docs architecture.

### STEP 2 — Determinism spine

- Seed types.
- GeneratorVersionTable.
- Stable hashes.
- Golden seed runner.
- Simulation tick.
- Save manifest minimal.

DoD : même seed = mêmes résultats sur corpus.

### STEP 3 — Chunk streaming foundation

- Chunk coordinates.
- Candidate/simulation/render rings.
- Async generation.
- Cache rebuildable.
- Anti-thrashing.
- Debug world chunk viewer.

DoD : monde se construit autour du joueur sans blocage main thread.

### STEP 4 — Terrain + traversal context

- Terrain sample grid.
- Features : slope, cliff, water, shore, ledges.
- TraversalChunkState.
- MotionAffordanceChunkState minimal.

DoD : contact patches fiables autour du joueur.

### STEP 5 — RenderCoreMetal4 baseline

- MTKView host minimal.
- RenderGraph.
- ResourceGraph.
- Pipeline cache.
- Metal debug labels.
- Apple tools scripts.

DoD : frame capture lisible, pas d'overlay lourd.

### STEP 6 — IVDS root

- VirtualGeometryAsset.
- Cluster model.
- Geometry pages.
- Root resident fallback.
- Terrain LOD baseline.

DoD : LOD stable, culling, streaming page minimal.

### STEP 7 — Character skeleton + proxy

- IsoHumanoid skeleton.
- CharacterDNA.
- Capsule/body collision.
- Sockets.
- Humanoid proxy render.

DoD : personnage lisible, données pures testées.

### STEP 8 — Motion Forge contracts

- MotionIntent.
- WorldMotionContext.
- MotionPrimitiveGraph.
- MotionFeatureVector.
- ContactPatch.
- MotionSaveRecord.

DoD : contrats Codable/testés/déterministes.

### STEP 9 — Smart Locomotion deterministic V0

- Locomotion intent.
- Trajectory planner.
- Procedural gait simple.
- Footstep planner.
- Surface-aware footsteps.

DoD : marche sur pentes/surfaces sans clip forest.

### STEP 10 — GPU skinning V1

- Mesh skinned minimal.
- Skeleton palette buffer.
- Motion snapshot to GPU.
- Character LOD0.

DoD : humanoïde skinné en Metal 4.

### STEP 11 — Motion Forge Lab V0

- Primitive viewer.
- Contact viewer.
- Footstep debug.
- Replay timeline.

DoD : inspecter une marche seedée et ses contacts.

### STEP 12 — Smart Object descriptors

- Affordance descriptors.
- Approach zones.
- Contact targets.
- Phase graph.
- Props test : coffre, porte, levier, rocher bas.

DoD : interaction ouverte par intent + primitive, pas par clip unique.

### STEP 13 — Warping/IK stack

- Stride warping.
- Slope warping.
- Orientation warping.
- Pelvis compensation.
- Hand IK.
- Inertialization.

DoD : corrections bornées, visibles dans tools.

### STEP 14 — Surface Forge integration

- Surface friction/wetness/snow/mud into motion.
- Footstep audio/FX mapping.
- Footprint deltas.

DoD : marcher boue/neige/roche produit motion+FX+audio cohérents.

### STEP 15 — ProtoMotion Lab importer

- Tiny dataset importer.
- Skeleton mapper.
- Feature extractor.
- Contact annotation.
- Motion report.

DoD : importer un clip libre/test et le retargeter IsoSkeleton.

### STEP 16 — Motion Matching / Token baseline

- Motion feature index.
- Token table.
- Deterministic candidate selection.
- Fallback procedural.

DoD : selection motion par intent/contexte.

### STEP 17 — Traversal primitives

- Step up/down.
- Vault low obstacle.
- Mantle low ledge.
- Jump/land.
- Slip/recover.

DoD : terrain vertical jouable.

### STEP 18 — Physics Bridge

- Balance estimation.
- Support polygon.
- Active ragdoll partial prototype.
- Fall/recover flow.

DoD : chutes/récupération contrôlées.

### STEP 19 — Smart Objects advanced

- Sit.
- Pick up.
- Carry.
- Push/pull.
- Tool use.
- Settlement interactions.

DoD : interactions contextuelles générées par descriptors.

### STEP 20 — Motion LOD + crowds

- Motion LOD tiers.
- Update frequency tiers.
- Pose cache.
- GPU skinning batching.

DoD : NPCs multiples sans explosion CPU/GPU.

### STEP 21 — ProtoMotion training sandbox

- Offline Python lab optionnel.
- Terrain challenge generator.
- Policy experiment.
- Export manifest.

DoD : aucune dépendance runtime, lab reproductible.

### STEP 22 — Optional ML path

- ONNX/CoreML/MPSGraph feasibility.
- Model schema.
- Fallback deterministic.
- Model versioning.

DoD : ML optionnel, jamais obligatoire.

### STEP 23 — Save/replay hardening

- Motion save records.
- Replay runner.
- Golden motion suite.
- Save/load interactions.

DoD : interaction en cours restaurée correctement.

### STEP 24 — Production validation

- Foot sliding validator.
- Contact penetration validator.
- Joint limit validator.
- Perf gates.
- Visual diff.

DoD : Motion Forge devient merge-gated.

### STEP 25 — Ultimate integration slice

- Monde chunké.
- IVDS.
- Surface Forge.
- Motion Forge.
- Smart props.
- Save.
- Metal profiling.

DoD : vertical slice complète : traverser un chunk procédural, interagir avec un prop, marcher sur surfaces dynamiques, sauvegarder/recharger, profiler Metal.

---

## 31. Gates Codex par PR

Chaque PR touchant Motion Forge doit répondre :

- Est-ce déterministe ?
- Est-ce versionné ?
- Est-ce testable sans assets lourds ?
- Est-ce compatible save/replay ?
- Est-ce séparé du runtime si outil lourd ?
- Est-ce sans dépendance externe non auditée ?
- Est-ce compatible Motion LOD ?
- Est-ce instrumenté ?
- Est-ce visible dans les tools ?
- Est-ce validé sur golden seeds ?

---

## 32. Non-objectifs explicites

Motion Forge ne doit pas :

- cloner MotionBricks ;
- cloner ProtoMotions ;
- dépendre de CUDA ;
- dépendre de Python runtime ;
- imposer ML pour jouer ;
- intégrer des datasets non audités ;
- rendre le gameplay non déterministe ;
- transformer chaque interaction en clip authoré ;
- faire du debug GPU custom lourd à la place des outils Apple ;
- mélanger Tools et Runtime.

---

## 33. Liste longue de primitives et interactions cibles

### 33.1 Locomotion

- idle breathing ;
- idle look around ;
- walk ;
- jog ;
- run ;
- sprint ;
- stop ;
- start ;
- turn in place ;
- pivot ;
- strafe ;
- crouch walk ;
- stealth walk ;
- injured walk ;
- heavy load walk ;
- uphill walk ;
- downhill walk ;
- snow walk ;
- mud walk ;
- wet stone careful walk ;
- shallow water walk.

### 33.2 Traversal

- step over root ;
- step over stone ;
- climb small ledge ;
- mantle waist ledge ;
- vault fence ;
- jump gap ;
- land soft ;
- land hard ;
- slide down slope ;
- recover slip ;
- climb rope ;
- climb ladder ;
- climb cliff handholds ;
- descend ledge ;
- squeeze between rocks ;
- balance on beam.

### 33.3 Interactions props

- open/close door ;
- open/close chest ;
- pull lever ;
- push object ;
- pull object ;
- pick up item ;
- place item ;
- inspect object ;
- sit on bench ;
- sleep on bed ;
- light fire ;
- gather plant ;
- chop tree ;
- mine rock ;
- fish ;
- drink water ;
- climb into boat ;
- use workbench ;
- forge metal ;
- cook ;
- write/read ;
- pray/ritual.

### 33.4 Combat/reaction

- draw weapon ;
- sheath weapon ;
- light attack ;
- heavy attack ;
- block ;
- parry ;
- dodge ;
- stagger ;
- hit react ;
- knockdown ;
- recover ;
- aim ;
- throw ;
- shield bash ;
- wounded limp ;
- death/fall.

### 33.5 Social/NPC

- wave ;
- point ;
- talk ;
- listen ;
- trade ;
- argue ;
- cheer ;
- fear ;
- kneel ;
- carry box ;
- sweep ;
- hammer ;
- farm ;
- patrol ;
- guard idle.

---

## 34. Definition of Done globale

Motion Forge est considéré “ultimate foundation ready” quand :

- le joueur n'est plus un cube/proxy rigide ;
- l'animation est pilotée par intents et primitives ;
- au moins 10 smart objects fonctionnent par descriptors ;
- la locomotion réagit aux surfaces/pentes ;
- les footstep events déclenchent audio/FX/surface deltas ;
- le runtime est natif Swift/Metal 4 ;
- le ProtoMotion Lab est séparé ;
- les packs sont manifestés/licenciés/versionnés ;
- save/replay restaure les primitives en cours ;
- le Motion LOD permet plusieurs NPCs ;
- les outils permettent de visualiser contacts, phases, corrections, coûts ;
- les captures Metal sont lisibles avec labels ;
- Codex peut tester avec `SamplesTiny` sans assets lourds.

---

## 35. Glossaire

**MotionIntent** : intention haut niveau d'un acteur.  
**Smart Primitive** : bloc d'animation/interactions paramétrique et contextuel.  
**ContactPatch** : surface de contact évaluée par terrain/props/surface.  
**MotionToken** : unité latente ou discrète de mouvement.  
**MotionPack** : paquet runtime compilé de motions/features/tokens.  
**ProtoMotion Lab** : outil offline de retargeting/training/validation.  
**Motion Forge Lab** : outil interactif de design et debug primitives.  
**IVDS** : virtualisation géométrique/LOD inspirée Nanite, adaptée IsoForge.  
**Surface Forge** : système procédural de surfaces/materials world-aware.  
**WorldMotionContext** : agrégation monde utile au mouvement.  
**MotionDeterminismRecord** : trace stable des décisions motion pour replay/save.

---

## 36. Références externes à surveiller

- ProtoMotions — https://github.com/NVlabs/ProtoMotions
- ProtoMotions documentation — https://protomotions.github.io/
- MotionBricks project page — https://nvlabs.github.io/motionbricks/
- MotionBricks code — https://github.com/NVlabs/GR00T-WholeBodyControl/tree/main/motionbricks
- Apple Metal — https://developer.apple.com/metal/
- Apple Metal developer tools — https://developer.apple.com/metal/tools/
- MetalFX — https://developer.apple.com/documentation/metalfx
- Metal Performance Shaders — https://developer.apple.com/documentation/MetalPerformanceShaders
- Metal Performance Shaders Graph — https://developer.apple.com/documentation/metalperformanceshadersgraph

---

## 37. Conclusion

La version ultime d'IsoForge ne doit pas essayer d'être “un moteur avec des animations”. Elle doit être un moteur où le mouvement est une conséquence du monde : seed, terrain, surface, props, climat, personnage, équipement, IA, style et intention.

MotionBricks nous inspire l'idée de **smart primitives et motion generation temps réel**. ProtoMotions nous inspire l'idée de **motion learning, retargeting, policies physiques et terrain challenge lab**. Notre version, Motion Forge, doit aller dans une direction propre à IsoWorld :

```text
Intentions + Monde procédural + Contacts + Surfaces + Props + LOD + Save + Metal 4
```

C'est cette intégration qui fera la différence entre un système d'animation moderne et un vrai moteur procédural vivant.
