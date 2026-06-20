# **Nom du Moteur : IsoForge Engine**
#### Procédural, orienté fabrication de monde.

Architecture de départ :

1. Xcode 26.5 / Swift 6.x / macOS 26 / Apple Silicon-first.
2. EngineCore pur Swift, déterministe, sans SwiftUI, sans Metal.
3. RenderCoreMetal4 séparé, Metal 4-first.
4. IsoTools séparé de l’app runtime.
5. IsoAssets avec manifest, importers, validation, licences.
6. IsoRuntimeApp minimal : menu, loading, debug world, real world.
7. RenderGraph natif dès le départ.
8. Resource graph + lifetime + residency dès le départ.
9. Shader/pipeline cache dès le départ.
10. Apple GPU tools intégrés dans scripts CI/dev dès le départ.
11. Aucun overlay SwiftUI lourd dans le mode runtime.
12. Un seul pipeline “final target” : pas de preview system destiné à rester trois mois.

Mais il faut être lucide : “pas de versions intermédiaires” ne veut pas dire “tout coder en bloc”. Ça veut dire : on ne fait pas de faux systèmes temporaires. On implémente par vertical slices, mais chaque slice respecte déjà l’architecture finale.

Exemple :

* mauvais : “on fait un terrain preview vertex color, puis plus tard on verra le vrai terrain” ;
* bon : “on crée tout de suite le vrai contrat terrain/material/texture/residency, mais on alimente d’abord avec 3 assets validés”.



Stopper l’empilement V2/V3 dans le repo POC. Créer un nouveau repo moteur propre, Metal 4-first, Apple tooling-first, procedural/deterministic-first.

L’ancien repo reste utile pour :

* valider des idées ;
* comparer les comportements ;
* récupérer certains tests ;
* relire les décisions ;
* éviter de perdre les specs ;
* garder une preuve que les systèmes peuvent marcher.

Mais le nouveau repo doit refuser :

* les systèmes de debug faits main qui remplacent les outils Apple ;
* les previews permanents ;
* les noms V1/V2/V3 dans le code ;
* les migrations de compromis ;
* les backends historiques ;
* les tools qui tournent dans le runtime ;
* les features non testables ;
* les pipelines renderer sans resource lifetime clair.

La bonne stratégie maintenant, selon moi :

IsoWorldPOC = POC validé.
IsoForge Engine = vraie fondation moteur.

Et oui : dans ce nouveau projet, il faut spécifier dès le départ Metal 4, MetalFX, Metal Developer Tools, RenderGraph, residency, pipeline cache, deterministic world generation, save spine, asset validation, profiling CLI et CI perf gates. C’est exactement le moment de faire ce pivot.



GitHub
→ code, docs, shaders, tests, manifests

Git LFS minimal
→ quelques textures/meshes de test seulement

Dossier local Assets/
→ tous les gros assets non commités

IsoForgeEngine/
  EngineCore/
  RenderCoreMetal4/
  Tools/
  RuntimeApp/
  Shaders/
  Tests/
  AssetManifests/
  SamplesTiny/
  LocalAssets/       ← ignoré par Git
  
  
  
LocalAssets/
AssetCache/
GeneratedAssets/
BuildArtifacts/
DerivedData/
*.gputrace
*.metal-capture




Niveau 2 — Propre pour Codex
Ensuite tu ajoutes un script :
./tools/assets/bootstrap-assets.sh --profile codex
./tools/assets/bootstrap-assets.sh --profile dev
./tools/assets/bootstrap-assets.sh --profile full   


codex → mini-assets nécessaires aux tests
dev   → assets utiles en local
full  → assets complets, jamais nécessaires à Codex


Codex n’a besoin que du profil codex.

Ça demande un peu d’organisation, mais ce n’est pas très dur. Le plus important est de créer des manifests d’assets propres :

```
{
  "id": "terrain.grass_temperate_01",
  "kind": "pbr_texture_set",
  "profile": ["codex", "dev"],
  "files": {
    "albedo": "Textures/grass/albedo.ktx2",
    "normal": "Textures/grass/normal.ktx2",
    "roughness": "Textures/grass/roughness.ktx2"
  },
  "license": "CC0",
  "sha256": "..."
}


```
Là, Codex peut coder autour du manifest sans avoir toute la librairie.

Ma reco très claire

Pour ton nouveau projet, je ne commencerais pas directement par Perforce + bucket + CI avancée.

Je commencerais par :

1. Nouveau repo GitHub propre
2. Git LFS activé mais utilisé très peu
3. LocalAssets/ ignoré
4. AssetManifests/ versionné
5. SamplesTiny/ versionné
6. Script bootstrap-assets.sh
7. Documentation claire pour Codex



Textures/Materials =>

Le système le plus puissant pour IsoForge serait :
un Surface Synthesis Graph déterministe, world-conditioned, compilé en IR stable, évalué CPU pour l’autorité, baké GPU via Metal 4 pour les textures/masks, streamé via un Surface Page Cache, puis rendu par un pipeline PBR layered avec residency, debug Metal natif et validation golden seeds.

Nom recommandé :

Surface Forge

Sous-systèmes :
1. WorldSurfaceDNA
2. SurfaceContextFields
3. SurfaceGraph IR
4. Deterministic Surface VM
5. Metal 4 Surface Baker
6. Surface Page Cache / Residency
7. Runtime Material Binding Table
8. Surface Debug & Validation Suite
9. Optional ML Assist Layer


Surface Forge :

- matériau paramétrique
- world-aware
- seed-aware
- biome-aware
- weather-aware
- save-aware
- LOD-aware
- Metal 4 runtime-aware


Le système ultime :
WorldRenderDNA
→ style global du monde

SurfaceGraph
→ recette procédurale du matériau

SurfaceContext
→ données terrain/biome/météo/RPG/save

SurfaceInstance
→ résultat déterministe pour un chunk, prop, bâtiment ou personnage

SurfaceBake
→ maps GPU/runtime

SurfaceRuntime
→ rendu Metal 4



Architecture cible

Je ferais 7 couches.

1. Surface DNA

C’est le niveau global.

```
struct WorldSurfaceDNA {
    let worldSeed: WorldSeed
    let artDirectionProfile: ArtDirectionProfile
    let pbrProfile: PBRProfile
    let colorHarmony: ColorHarmony
    let materialComplexity: MaterialComplexity
    let textureDensity: TextureDensity
    let erosionProfile: ErosionProfile
    let weatherSurfaceIntensity: Float
    let biomeMutationRate: Float
    let civilizationWearScale: Float
}


```
Ce niveau décide :
- monde réaliste / stylisé / dark fantasy / high contrast / doux
- densité de détails
- palette globale
- rugosité moyenne
- intensité météo
- fréquence de variations

C’est l’équivalent “ADN visuel” du monde.



2. Surface Context Fields

C’est ce qui rend le système vraiment procédural.

Chaque point du monde expose des champs :
* position monde
* chunk coordinate
* altitude
* slope
* aspect
* curvature
* temperature
* humidity
* rainfall
* wind exposure
* sun exposure
* snow line
* water proximity
* shore mask
* cliff mask
* mountain mask
* biome weights
* settlement influence
* road proximity
* age/civilization layer
* combat/scorch/damage deltas
* player wear/trample deltas

Donc le matériau peut réagir à la réalité du monde, pas seulement à des paramètres artistiques.



3. Surface Graph IR

C’est le cœur du système.

Un graph sérialisable, déterministe, compilable.
* Noise
* Voronoi
* Cellular
* Gradient
* ColorRamp
* HeightBlend
* SlopeMask
* CurvatureMask
* BiomeMix
* WeatherBlend
* Erosion
* Sediment
* CrackPattern
* MossGrowth
* SnowAccumulation
* WetnessResponse
* DustResponse
* WearResponse
* HeightToNormal
* NormalBlend
* PackORM
* OutputPBR
* OutputMasks


Mais au lieu d’être un graph générique façon Substance, il a des nodes spécifiques à IsoForge :
* BiomeWeightsNode
* TerrainFeatureMaskNode
* WorldAgeNode
* RPGFactionInfluenceNode
* SettlementWearNode
* RoadDustNode
* HydrologyProximityNode
* SeasonNode
* WeatherSurfaceStateNode
* ChunkSeamSafeNoiseNode
* DeterministicVariantNode


4. Deterministic Surface VM

Le graph ne doit pas être juste une UI. Il faut une VM / IR moteur.

Chaque graph est compilé en représentation stable :
SurfaceGraph JSON
  ↓
validated DAG
  ↓
canonical IR
  ↓
hash stable
  ↓
CPU evaluator + GPU kernel generation

Le déterminisme vient de règles strictes :
* seed explicite partout
* pas de random global
* pas de dépendance au frame time
* pas de float non contrôlé pour les décisions critiques
* hash stable des nodes
* ordre topologique canonique
* versions de générateurs
* snapshots de graph versionnés
* fallback CPU de référence
* tests golden seeds

Pour les décisions de gameplay/save/seams, on utilise CPU/fixed rules. Pour le rendu haute fréquence, on peut accepter du GPU déterministe “visuellement stable”, mais jamais comme source d’autorité gameplay.



5. GPU Baking Metal 4

C’est là que Metal 4 devient important.

Apple présente Metal comme une API graphique/compute bas niveau, intégrée à Apple silicon, avec contrôle direct des tâches GPU ; Metal 4 ajoute de nouvelles manières d’intégrer le machine learning, d’encoder les commandes et de compiler les shaders plus efficacement.  

Surface Forge devrait donc utiliser Metal 4 pour :
* baking de tiles PBR
* baking de masks
* génération de normal maps
* packing ORM
* mip generation
* texture arrays
* debug views
* residency feedback
* prévisualisation temps réel dans les tools

Pipeline :
SurfaceGraph IR
  ↓
Metal compute kernels
  ↓
Tile bake 256/512/1024
  ↓
baseColor / normal / ORM / height / masks
  ↓
compression/import
  ↓
texture arrays / virtual pages
  ↓
runtime material table


6. Material Residency + Virtual Surface Cache

Le système le plus puissant ne génère pas toutes les textures partout.

Il génère/cache par besoin :
near field
→ textures haute résolution, detail normals, masks fins

mid field
→ textures moyennes, masks simplifiés

far field
→ macro albedo/roughness, pas de micro detail

tools/inspection
→ bake haute qualité localisé

CI/tests
→ bake basse résolution déterministe


Donc il faut un Surface Page Cache :
SurfacePageKey:
  graphHash
  presetHash
  worldSeed
  chunkCoord
  biomeSignature
  lod
  resolution
  outputKind
    
Et un système de residency :    
requested
baking
resident
evictable
pinned
stale
rebuildable


7. Runtime Surface Layer

Le runtime ne doit pas transporter des graphes énormes partout. Il consomme une table compacte :

```
struct SurfaceRuntimeBinding {
    let materialID: UInt32
    let surfacePageBase: UInt32
    let textureArrayIndices: PBRTextureSet
    let normalStrength: Float
    let heightScale: Float
    let roughnessBias: Float
    let wetnessResponse: Float
    let snowResponse: Float
    let dustResponse: Float
    let mossResponse: Float
    let debugFlags: UInt32
}


```
Le renderer Metal lit :
MaterialBindingTable
SurfacePageTable
Texture arrays / sparse pages
EnvironmentState
LightingState
SurfaceState

Et applique :
layered PBR
triplanar terrain
detail normals
height/slope blending
wetness/snow/dust/moss
decals
terrain/prop/building material variants



Le système complet
Le système ultime serait donc :
Surface Forge
├── WorldSurfaceDNA
├── SurfaceContextFields
├── SurfaceGraph IR
├── Deterministic Surface VM
├── Metal 4 GPU Baker
├── Surface Page Cache
├── Material Residency System
├── Runtime Material Binding Table
├── Surface Debug/Validation Tools
└── Apple Metal tools integration



Comment ça s’intègre avec les outils Apple

On ne remplace pas les outils Metal. On les embrasse.

Apple fournit Xcode Metal debugger, Metal system trace, performance HUD, validation API/shader, inspection de ressources, shader debugging, mémoire, compteurs, heat maps, et des outils CLI comme gpucapture, gpudebug, metalperftrace pour scripts et workflows agentiques.

Donc Surface Forge doit produire des labels/debug markers lisibles :
SurfaceBakePass[terrain.marsh_mud][chunk 12,-4][LOD1]
SurfaceResidencyUpload[rock_cliff][page 88]
SurfaceGraphCompute[wetnessMask]
TerrainLayeredPBR[biome taiga/mountain]

Le but : quand tu captures une frame, tu vois immédiatement quelles surfaces, quels graphs, quelles pages et quels chunks coûtent cher.





Le rôle de MPS / MPSGraph / ML
Dans le système le plus puissant, je mettrais le ML en support, pas comme source déterministe principale.

Apple indique que Metal permet d’intégrer le machine learning avec le rendu, y compris en encodant des réseaux au niveau commande ou directement dans les shaders pour calculer lighting, materials et geometry, et mentionne MPS/MPSGraph pour des shaders compute/graphics optimisés et l’intégration de modèles Core ML.  

Mais pour notre moteur :
Chemin autoritaire déterministe
→ SurfaceGraph IR classique, seedé, versionné, testable.

Chemin ML optionnel
→ suggestion de matériaux, denoising, upscaling, génération assistée dans les tools, compression, classification, preview.

Pourquoi ? Parce que le ML peut être stable dans un build donné, mais ce n’est pas idéal comme source canonique pour des saves, des seams terrain ou des golden seeds cross-version.
Donc :
ML dans tools : oui
ML dans offline baking : oui, si résultat hashé
ML dans runtime esthétique : possible
ML comme source de vérité procédurale : non


Debug/Metal4 =>

Or Apple fournit maintenant exactement ce qu’il faut pour remplacer une grosse partie du debug lourd : Metal debugger dans Xcode, Metal performance HUD, Metal system trace dans Instruments, validation API/shader, gpucapture, gpudebug, metalperftrace. Apple décrit aussi le support Metal 4 du debugger pour inspecter pipelines render/compute/ML, ressources, synchronisation d’encoders, tensors, shader debugging, memory reports, counters et traces.  

Donc je dirais :

À garder custom :

* mini overlay runtime très léger : FPS, seed, chunk count, LOD tier, GPU frame time, mode capture actif ;
* debug gameplay/procédural : biome weights, save slot, world DNA, terrain masks ;
* inspectors tools qui lisent les données moteur, pas le GPU bas niveau.

À basculer vers Apple tools :

* capture frame GPU ;
* analyse mémoire GPU ;
* shader debugging ;
* counters hardware ;
* validation API ;
* performance traces ;
* analyse de dépendances entre passes ;
* profiling automatisé via CLI.

Apple a clairement pensé ces workflows pour les scripts et agents de code : gpucapture, gpudebug et metalperftrace sont explicitement orientés capture/debug/profiling depuis la ligne de commande et workflows agentiques.  

1. Metal 4 change vraiment la stratégie

Oui, ça change la stratégie. Metal 4 n’est pas juste “Metal 3 + quelques features”. Apple indique que Metal 4 apporte de nouveaux moyens d’intégrer le machine learning, d’encoder les commandes et de compiler les shaders plus efficacement.   Apple met aussi en avant MetalFX Upscaling, Frame Interpolation et Denoising pour améliorer les performances en économisant le coût de rendu des frames.  

Pour IsoWorld, les implications sont énormes :

* MetalFX devrait être une brique officielle du pipeline résolution/perf, au lieu de bricoler un rendu basse résolution + upscale maison.
* Metal developer tools doivent devenir le pipeline officiel de debug/perf.
* Metal 4 Core API doit être évalué dès l’architecture renderer, pas ajouté après 80 steps.
* MPS / MPSGraph ne sont pas forcément au cœur du rendu terrain, mais peuvent servir plus tard pour génération ML, upscaling custom, denoising, classifiers, compression, tools, ou pré-calculs.
* Shader compilation / pipeline cache / render graph / resource residency doivent être designés dès le départ.

Apple liste Metal 4 comme supporté sur Mac Apple silicon M1 ou plus récent, iPhone/iPad/Apple TV A14 ou plus récent, et Vision Pro.   Donc si tu assumes une cible moderne Apple Silicon, tu peux être beaucoup plus agressif.