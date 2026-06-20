# IsoWorld — Moteur audio custom procédural / paramétrique haute qualité

**Nouveau step — Document dédié uniquement à l’audio**  
**Sujet :** moteur audio custom inspiré des meilleures technologies modernes, avec synthèse physique, générateurs procéduraux/paramétriques, musique générative et thèmes audio dépendants du monde.  
**Contexte :** IsoWorld, Swift/Metal, macOS, monde déterministe par seed, génération dynamique par chunks, systèmes procéduraux cohérents entre terrain, biomes, props, météo, RPG, FX et UI/HUD.  
**Objectif :** définir une architecture audio moderne, versatile, déterministe et extensible, capable de produire un rendu audio riche sans dépendre uniquement de banques de samples.

---

## 0. Résumé exécutif

Le moteur audio d’IsoWorld doit être pensé comme un **système procédural de simulation sonore**, pas comme un simple lecteur de samples.  
Le jeu génère déjà son monde avec des règles, des seeds, des biomes, des props, de la météo, des matériaux et des événements systémiques. L’audio doit donc suivre la même philosophie :

- un pas ne joue pas seulement un fichier `footstep_grass_03.wav` ;
- il est généré à partir d’un événement : masse du personnage, vitesse, matériau du sol, humidité, pente, chaussure, profondeur de boue, taille des graviers, fatigue, météo, distance caméra, réverbération locale ;
- une forêt ne joue pas seulement une boucle d’ambiance ;
- elle est composée de vents, feuilles, branches, insectes, oiseaux, humidité, densité végétale, altitude, saison, heure, météo et topologie ;
- une musique d’ambiance n’est pas seulement une piste fixe ;
- elle est générée depuis le `WorldAudioDNA`, le biome, la tension, les thèmes harmoniques du monde, l’époque, la mythologie RPG, la météo, la verticalité et l’état du joueur.

La recommandation d’architecture est **hybride** :

1. **Backend Apple pour l’intégration système**  
   Utiliser Core Audio / Audio Unit / AVAudioEngine / éventuellement PHASE selon le niveau d’intégration choisi. Apple fournit des APIs solides pour l’I/O audio, les graphes de nœuds, le spatial audio et les effets système. PHASE peut être intéressant pour des scènes audio spatiales et géométriques dynamiques, tandis qu’AVAudioEngine simplifie les graphes de lecture/traitement.

2. **Cœur DSP custom pour IsoWorld**  
   Le cœur temps réel doit être contrôlé par IsoWorld : scheduler, mixer, graphes DSP, synthèse, random déterministe, events, paramètres, LOD audio, budgets CPU, profilage, crossfades, musiques génératives. Le cœur DSP doit être le plus possible écrit dans une couche bas niveau sans allocation sur le thread audio.

3. **Authoring procédural paramétrique**  
   Créer un système `AudioRecipe` / `AudioGraph` comparable dans l’esprit à MetaSounds, GameSynth, SuperCollider ou Pure Data, mais adapté au moteur. Les sound designers ne doivent pas coder chaque son ; ils doivent manipuler des générateurs, modules, presets, règles, ranges, courbes et contraintes.

4. **World-aware audio**  
   Tout son doit pouvoir lire des attributs du monde : biome, sous-biome, météo, heure, humidité, température, matériau, densité de props, époque RPG, technologie, magie, niveau de danger, altitude, occlusion, cavité, verticalité.

5. **Pas de dogme “100 % synthèse”**  
   Pour un rendu haute qualité, le moteur doit mélanger :
   - synthèse physique ;
   - synthèse additive/soustractive/FM/granulaire/wavetable/modal ;
   - samples courts et corpus de grains ;
   - convolution / impulsions ;
   - pré-rendu offline de textures sonores ;
   - variations runtime ;
   - musique générative structurée.

Le résultat visé est un système capable de produire des sons **naturels, réactifs, non répétitifs, synchronisés au gameplay et cohérents avec chaque seed de monde**.

---

## 1. Références modernes et leçons à retenir

### 1.1 Apple : Core Audio, AVAudioEngine, Audio Unit, PHASE

Apple propose plusieurs niveaux d’abstraction audio :

- **AVAudioEngine** : graphe de nœuds audio pour lecture, capture, mixage et traitement. Très utile pour prototyper, connecter des nodes, utiliser des effets système et gérer des chaînes audio complexes.
- **Audio Unit / AUv3** : format bas niveau pour effets, instruments et traitement temps réel. Pertinent si IsoWorld veut empaqueter certains synthés/effets comme unités réutilisables.
- **Core Audio** : couche très bas niveau pour contrôle fin de l’I/O, latence, buffers et callbacks audio.
- **PHASE** : Physical Audio Spatialization Engine, conçu pour des expériences audio spatiales dynamiques et intégrées à la scène, avec paramètres audio réactifs au monde.

Leçon pour IsoWorld :  
Apple doit être utilisé comme **backend fiable** et comme source d’intégration macOS, mais le gameplay procédural doit rester dans un cœur custom. PHASE est intéressant pour la spatialisation et la scène acoustique, mais il ne remplace pas un moteur de génération procédurale des sources sonores.

### 1.2 Unreal MetaSounds

MetaSounds est une référence majeure : le son est généré par un **graphe DSP**, avec contrôle fin par les designers. Il est présenté comme un système audio haute performance donnant un contrôle complet sur la génération DSP des sources. Les points à retenir :

- graphes réutilisables ;
- inputs/outputs typés ;
- sources audio procédurales ;
- design in-editor ;
- réutilisation de sous-graphes ;
- contrôle sample-accurate via Quartz dans Unreal ;
- bonne séparation entre événement gameplay, source sonore et rendu.

Leçon pour IsoWorld :  
Créer `IsoAudioGraph`, un langage de graphes DSP data-driven. Ne pas coder chaque synthèse comme un cas spécial. Les générateurs doivent être composables.

### 1.3 Wwise / FMOD

Wwise et FMOD ne sont pas uniquement des lecteurs de samples ; ils gèrent :

- événements ;
- banques ;
- paramètres temps réel ;
- mixing hiérarchique ;
- snapshots ;
- transitions musicales ;
- ducking ;
- profiling ;
- banques interactives ;
- logique musicale ;
- routing ;
- priorités ;
- virtualisation de voix.

Wwise propose aussi des sources de synthèse comme Synth One et SoundSeed Wind, qui montre que les pipelines AAA utilisent déjà des générateurs procéduraux pour certains sons.

Leçon pour IsoWorld :  
Le moteur doit être pensé comme un **middleware interne** : événements, paramètres, bus, snapshots, states, switches, blending, music segments, profiling, authoring.

### 1.4 Steam Audio / spatialisation géométrique

Steam Audio montre l’importance de l’audio spatial dépendant de la géométrie :

- occlusion ;
- réflexion ;
- réverbération ;
- propagation ;
- géométrie dynamique ;
- changements en temps réel lorsque la scène change.

Leçon pour IsoWorld :  
Même sans simulation acoustique lourde, il faut au minimum un système d’occlusion/obstruction, zones acoustiques, reverb probes, matériau acoustique et transitions intérieur/extérieur.

### 1.5 GameSynth / procedural sound design

GameSynth est une référence spécialisée dans le sound design procédural : il permet de générer des sons à partir de paramètres, courbes, gestes et modules de synthèse. Il montre qu’un pipeline procédural peut remplacer ou enrichir une partie du travail habituellement basé sur des bibliothèques de samples.

Leçon pour IsoWorld :  
Créer des **recettes sonores paramétriques** exportables, versionnées, randomisables, testables et rendables offline.

### 1.6 SuperCollider / Pure Data / AudioKit

Ces environnements donnent de bonnes idées de design :

- graphes dynamiques ;
- oscillateurs et filtres modulaires ;
- bus audio/control ;
- scheduling ;
- patching temps réel ;
- instruments génératifs ;
- séparation langage de contrôle / serveur DSP ;
- prototypage rapide.

Leçon pour IsoWorld :  
Une architecture audio robuste doit séparer :
- le monde/gameplay ;
- le langage de contrôle ;
- le graphe DSP ;
- le scheduler ;
- le moteur de rendu audio temps réel.

### 1.7 Recherche en synthèse physique

La recherche sur les pas, impacts, frottements, roulements, contacts continus et sons modaux montre que les sons peuvent être générés à partir de modèles physiques : masse, vitesse, matériau, force, surface, modes résonants, texture, friction.

Leçon pour IsoWorld :  
Les meilleurs candidats pour la synthèse physique runtime sont :
- pas ;
- impacts ;
- frottements ;
- roulements ;
- graviers ;
- bois qui craque ;
- métal qui résonne ;
- cordes ;
- tissus ;
- eau légère ;
- vent ;
- objets mécaniques.

---

## 2. Vision du moteur : IsoAudioEngine

### 2.1 Objectif global

`IsoAudioEngine` doit être le système qui transforme les événements du monde en expérience sonore :

```text
World state + gameplay events + procedural rules + audio recipes
        ↓
Audio event graph
        ↓
Parameter extraction
        ↓
Procedural source generation / sample hybrid / music generation
        ↓
Spatialization + acoustics + mix
        ↓
Output audio
```

Il doit être :

- **déterministe** : même seed + mêmes événements + même timeline = même résultat perceptuel ;
- **paramétrique** : tous les sons importants exposent des paramètres de contrôle ;
- **modulaire** : chaque générateur est une brique réutilisable ;
- **scalable** : LOD audio, voix virtuelles, budgets CPU ;
- **artist-friendly** : recettes et presets, pas uniquement du code ;
- **world-aware** : le monde influence réellement le rendu ;
- **haute qualité** : pas de boucles répétitives évidentes, pas d’artefacts de modulation, bonne dynamique, spatialisation crédible ;
- **compatible Swift/Metal/macOS** : intégration propre avec l’écosystème Apple.

### 2.2 Les grands sous-systèmes

```text
IsoAudioEngine
├─ AudioDeviceBackend
│  ├─ CoreAudioBackend
│  ├─ AVAudioEngineBackend
│  └─ PHASEBridge optional
│
├─ AudioEventSystem
│  ├─ EventQueue
│  ├─ AudioTimeline
│  ├─ DeterministicRNG
│  └─ ParameterResolver
│
├─ AudioGraphRuntime
│  ├─ DSPGraphCompiler
│  ├─ AudioNodeVM
│  ├─ SynthNodeLibrary
│  ├─ ModulationSystem
│  └─ RealtimeMemoryArena
│
├─ ProceduralSourceSystem
│  ├─ FootstepSynth
│  ├─ ImpactSynth
│  ├─ FrictionSynth
│  ├─ WindSynth
│  ├─ RainSynth
│  ├─ WaterSynth
│  ├─ CreatureVoiceSynth
│  ├─ MechanicalSynth
│  ├─ UIAudioSynth
│  └─ MusicGenerator
│
├─ SampleHybridSystem
│  ├─ GrainLibrary
│  ├─ SamplePool
│  ├─ CorpusTagging
│  ├─ ConcatenativeSelector
│  └─ VariationRenderer
│
├─ SpatialAudioSystem
│  ├─ SourceSpatializer
│  ├─ DistanceModel
│  ├─ Directionality
│  ├─ OcclusionObstruction
│  ├─ ReverbZones
│  ├─ AcousticMaterials
│  └─ InteriorExteriorSolver
│
├─ MixSystem
│  ├─ BusGraph
│  ├─ Snapshots
│  ├─ Ducking
│  ├─ Limiters
│  ├─ LoudnessManagement
│  └─ DebugMeters
│
├─ MusicSystem
│  ├─ WorldThemeDNA
│  ├─ HarmonyGenerator
│  ├─ MotifGenerator
│  ├─ ArrangementDirector
│  ├─ StemMixer
│  ├─ TransitionScheduler
│  └─ ProceduralInstruments
│
└─ Tooling
   ├─ AudioRecipeEditor
   ├─ WorldAudioDebugger
   ├─ Profiler
   ├─ OfflineRenderer
   ├─ RegressionTests
   └─ PerceptualPreview
```

---

## 3. Décision d’architecture : Apple only ou moteur custom ?

### 3.1 Option A : tout faire avec AVAudioEngine

Avantages :
- intégration rapide ;
- nodes audio existants ;
- effets Apple ;
- bonne base pour prototypage ;
- moins de code bas niveau ;
- compatible Swift.

Limites :
- moins de contrôle sur le scheduler déterministe ;
- graphes dynamiques moins adaptés à une VM DSP de jeu ;
- contrôle temps réel strict plus délicat ;
- moins d’outils custom pour règles de monde ;
- déterminisme plus difficile si le moteur dépend trop d’états externes ;
- coût potentiel si le graphe devient très complexe.

Verdict : bon pour prototyper, outils, musique, effets simples, mais pas suffisant comme cœur d’un moteur audio procédural AAA.

### 3.2 Option B : tout faire en Core Audio bas niveau

Avantages :
- contrôle fin ;
- faible latence ;
- architecture maîtrisée ;
- moteur DSP sur mesure ;
- déterminisme fort ;
- performance prévisible.

Limites :
- complexité élevée ;
- gestion des devices, formats, interruptions ;
- plus de code ;
- davantage de risques de bugs audio temps réel.

Verdict : très bon pour le cœur runtime, mais coûteux. À réserver au noyau critique.

### 3.3 Option C : moteur custom + backend Apple

Recommandation.

```text
Swift gameplay/control layer
        ↓
IsoAudioEngine API
        ↓
Custom deterministic DSP runtime
        ↓
Core Audio / AVAudioEngine / AudioUnit backend
        ↓
Device output
```

Stratégie :
- Swift pour l’API, les recipes, l’authoring, le gameplay ;
- C/C++/C-compatible ou Swift très contrôlé pour DSP temps réel ;
- aucun heap allocation sur thread audio ;
- aucun lock bloquant sur thread audio ;
- ring buffers lock-free pour events ;
- graphes compilés en instructions DSP ;
- backend Apple pour device I/O ;
- PHASE facultatif pour certains modes spatial audio avancés.

---

## 4. Principes temps réel indispensables

Le thread audio est fragile. Il ne doit pas :

- allouer de mémoire ;
- faire de l’I/O disque ;
- attendre un lock ;
- parser du JSON ;
- appeler des APIs imprévisibles ;
- déclencher du logging lourd ;
- faire du travail de gameplay ;
- dépendre d’un scheduling système incertain.

Il doit :

- lire des buffers préchargés ;
- lire des commandes déjà préparées ;
- exécuter du DSP précompilé ;
- utiliser des structures préallouées ;
- traiter un nombre borné de voix ;
- respecter un budget CPU strict ;
- se dégrader proprement en cas de surcharge.

### 4.1 Thread model proposé

```text
Main/Game Thread
├─ produit les AudioEvents
├─ met à jour paramètres monde
├─ prépare recettes
└─ écrit dans EventQueue lock-free

Audio Control Thread
├─ résout les paramètres
├─ instancie les voix
├─ compile les graphes si nécessaire
├─ gère streaming/cache
└─ prépare commandes realtime

Audio Render Thread
├─ mélange les voix actives
├─ exécute DSP
├─ spatialise
├─ applique bus/effects
└─ sort le buffer audio
```

### 4.2 Déterminisme

Le déterminisme audio doit être défini intelligemment. Il n’est pas nécessaire que les samples numériques soient bit-exact entre machines si les backends changent, mais il faut que les décisions soient déterministes :

- choix de variante ;
- paramètres générés ;
- timing relatif ;
- activation de couches ;
- pitch random ;
- grain selection ;
- accords ;
- motifs ;
- transitions ;
- objectifs de mix ;
- état du monde sonore.

Utiliser :

```swift
struct AudioSeedContext {
    let worldSeed: UInt64
    let chunkSeed: UInt64
    let entityId: UInt64
    let eventIndex: UInt64
    let audioRecipeId: UInt64
}
```

Puis :

```text
audioRNG = hash(worldSeed, entityId, eventIndex, recipeId)
```

---

## 5. Modèle de données central

### 5.1 WorldAudioDNA

Chaque seed doit générer un profil audio du monde.

```swift
struct WorldAudioDNA {
    var acousticEra: AcousticEra
    var musicLanguage: MusicLanguage
    var instrumentPalette: InstrumentPalette
    var ambienceDensity: Float
    var naturalism: Float
    var mysticism: Float
    var technologyLevel: Float
    var dangerTension: Float
    var silenceAmount: Float
    var reverbPersonality: ReverbPersonality
    var creatureVocalStyle: CreatureVocalStyle
    var materialSonicPalette: MaterialSonicPalette
    var motifRules: MotifRules
    var tuningSystem: TuningSystem
}
```

Exemples :
- monde primordial : vents graves, percussions de pierre, drones organiques, peu de musique tonale ;
- monde médiéval humide : bois, cuir, cloches, cordes, modes anciens, pluie fréquente ;
- monde futur lointain : drones spectraux, microtonalité, impulsions synthétiques, réverbérations propres ;
- monde sans ennemis : ambiances plus ouvertes, musique contemplative, moins d’alertes ;
- monde hostile : motifs dissonants, nappes instables, insectes agressifs, vents coupants.

### 5.2 AudioEvent

```swift
struct AudioEvent {
    let id: UInt64
    let recipe: AudioRecipeID
    let emitter: AudioEmitterID?
    let position: SIMD3<Float>?
    let velocity: SIMD3<Float>?
    let surface: SurfaceAudioInfo?
    let impact: ImpactInfo?
    let biome: BiomeAudioInfo?
    let weather: WeatherAudioInfo?
    let gameplay: GameplayAudioInfo?
    let seedContext: AudioSeedContext
    let priority: AudioPriority
}
```

### 5.3 SurfaceAudioInfo

Très important pour les pas, impacts, frottements.

```swift
struct SurfaceAudioInfo {
    var material: SurfaceMaterial
    var subMaterial: SurfaceSubMaterial
    var wetness: Float
    var snowDepth: Float
    var mudDepth: Float
    var gravelSize: Float
    var vegetationDensity: Float
    var hardness: Float
    var roughness: Float
    var porosity: Float
    var temperature: Float
    var slope: Float
    var normal: SIMD3<Float>
}
```

### 5.4 FootwearAudioInfo

```swift
struct FootwearAudioInfo {
    var soleMaterial: SoleMaterial
    var soleHardness: Float
    var treadDepth: Float
    var wetnessCarry: Float
    var metalParts: Float
    var dirtAccumulation: Float
    var weight: Float
}
```

### 5.5 AudioRecipe

```yaml
id: footstep_adaptive_v1
type: procedural_source
category: locomotion
inputs:
  - footVelocity
  - characterMass
  - surface.material
  - surface.wetness
  - footwear.soleMaterial
  - slope
graph: graphs/footstep_physical.graph
variation:
  randomSeed: eventSeed
  pitchRange: [-0.08, 0.06]
  timingJitterMs: [-6, 8]
lod:
  near: full
  mid: reduced_layers
  far: material_impression
```

---

## 6. Architecture des graphes DSP

### 6.1 Pourquoi un graphe DSP ?

Le son procédural devient vite complexe :

- un pas = impact + friction + grain + résonance + couche humide + couche chaussure + réverbération locale ;
- un vent = bruit filtré + rafales + modulation par obstacles + turbulences + feuillage ;
- une musique = horloge + harmonie + voix + instruments + effets + transitions.

Coder chaque son à la main serait ingérable. Il faut un graphe.

### 6.2 Types de nodes

#### Sources

- Oscillator sine/saw/square/triangle
- Noise white/pink/brown/blue
- Band-limited noise
- Granular source
- Sample source
- Wavetable source
- Modal resonator bank
- Karplus-Strong pluck
- FM operator
- Additive partial bank
- Physical excitation generator
- Event impulse generator
- Envelope generator
- Step sequencer
- Grain cloud source
- Texture scanner
- Procedural loop source

#### Transformations

- Filter lowpass/highpass/bandpass/notch
- SVF / ladder / biquad
- Comb
- Allpass
- Wavefolder
- Saturation
- Waveshaper
- Ring modulation
- Frequency shifter
- Pitch shifter
- Granular stretcher
- Transient shaper
- Envelope follower
- Compressor
- Limiter
- Gate
- Expander
- De-esser
- Convolution light
- Modal filter
- Resonator
- Spectral blur
- Spectral freeze
- Stereo spread
- Haas delay
- Doppler

#### Modulations

- LFO
- Random walk
- Sample & hold
- Perlin noise
- Curl noise
- Envelope
- Curve remapper
- Parameter smoother
- Biome parameter
- Weather parameter
- Time-of-day parameter
- Player state parameter
- Distance parameter
- Occlusion parameter
- Tension parameter
- WorldDNA parameter

#### Mix / routing

- Mixer
- Crossfade
- Layer selector
- Priority gate
- Bus send
- Sidechain input
- Snapshot morph
- Stem mixer
- Ambience bed router

### 6.3 Compilation du graphe

Le graphe authoring est lisible mais pas optimal. Il faut le compiler.

```text
AudioGraph Asset
        ↓ parse/validate
Typed DSP IR
        ↓ optimize
DSP Program
        ↓ instantiate voices
Realtime VM / native kernels
```

Optimisations :
- constant folding ;
- suppression des nodes inutilisés ;
- fusion d’opérateurs ;
- pré-calcul des courbes ;
- pré-allocation des buffers ;
- vectorisation SIMD ;
- sélection de LOD graph ;
- remplacement de nodes coûteux à distance.

---

## 7. Système d’événements audio

### 7.1 Types d’événements

- one-shot : impact, pas, clic UI ;
- continuous : vent, feu, rivière, machine ;
- stateful : pluie qui commence, moteur qui accélère ;
- music : transition, intensité, mode, cadence ;
- ambience : couche de biome, insectes, oiseaux ;
- physical contact : frottement, roulement, corde ;
- material response : pluie sur métal, neige sous chaussure ;
- narrative/RPG : lieu sacré, danger, faction proche.

### 7.2 API conceptuelle

```swift
audio.post(.footstep(
    entity: player.id,
    foot: .left,
    contact: footContact,
    surface: terrain.sampleAudioSurface(at: footPosition),
    footwear: player.equipment.footwearAudioInfo,
    biome: world.biomeAudioInfo(at: footPosition),
    weather: world.weatherAudioInfo(at: footPosition)
))
```

### 7.3 Audio tags

Chaque son doit être taggé :

```text
category: locomotion / nature / creature / mechanical / music / ui / weather / water / magic
material: grass / mud / snow / stone / wood / metal
world: ancient / modern / futuristic / organic / corrupted
mood: calm / tense / sacred / hostile / mysterious
priority: critical / high / normal / low / ambient
```

---

## 8. Synthèse physique : principes

La synthèse physique utilise des paramètres physiques ou perceptuellement liés au monde :

- masse ;
- vitesse ;
- force ;
- matériau ;
- densité ;
- élasticité ;
- rigidité ;
- frottement ;
- rugosité ;
- résonance ;
- humidité ;
- taille des grains ;
- pression ;
- surface de contact.

Le son produit peut être approximé avec :
- excitations impulsionnelles ;
- bruit filtré ;
- banques de résonateurs ;
- grains ;
- oscillateurs non linéaires ;
- modèles source-filtre ;
- convolution légère ;
- modal synthesis.

### 8.1 Pourquoi c’est idéal pour IsoWorld

Le monde connaît déjà :
- matériaux ;
- props ;
- météo ;
- terrain ;
- collision ;
- vitesse ;
- entités ;
- seed ;
- règles RPG.

Donc beaucoup de sons peuvent être dérivés automatiquement.

---

## 9. FootstepSynth : pas procéduraux haute qualité

### 9.1 Objectif

Générer des pas réalistes et variés, sensibles à :

- matériau du sol ;
- sous-couche ;
- pente ;
- humidité ;
- boue ;
- neige ;
- gravier ;
- végétation ;
- type de chaussure ;
- masse du personnage ;
- fatigue ;
- vitesse ;
- animation exacte du pied ;
- glissement ;
- contact talon/pointe ;
- micro-obstacles ;
- environnement acoustique.

### 9.2 Décomposition d’un pas

Un pas n’est pas un son unique. Il est composé :

```text
footstep =
    heelImpact
  + soleCompression
  + surfaceCrack
  + grainScatter
  + frictionScrape
  + wetSquish/splash
  + vegetationRustle
  + footwearDetail
  + bodyWeightTransfer
  + localReflection
```

### 9.3 Paramètres d’entrée

```swift
struct FootstepParams {
    var mass: Float
    var footVelocity: Float
    var verticalImpulse: Float
    var horizontalSlip: Float
    var contactArea: Float
    var heelToeRatio: Float
    var cadence: Float
    var fatigue: Float
    var shoeHardness: Float
    var soleTread: Float
    var surfaceHardness: Float
    var surfaceRoughness: Float
    var wetness: Float
    var mudDepth: Float
    var snowDepth: Float
    var gravelSize: Float
    var vegetationDensity: Float
}
```

### 9.4 Matériaux et signatures sonores

| Sol | Génération proposée |
|---|---|
| pierre sèche | impact court + résonance haute + peu de bruit |
| pierre humide | impact amorti + slap léger + reflections |
| gravier fin | nuage de grains rapides + impacts multiples |
| gravier gros | grains plus espacés + clacks irréguliers |
| sable sec | bruit large amorti + peu d’attaque |
| sable humide | thud mou + succion légère |
| boue | squish + suction + lowpass |
| herbe sèche | frottement léger + brins cassants |
| herbe humide | frottement doux + humidité |
| feuilles mortes | craquements granulaires |
| neige poudreuse | crunch doux, bruit compressé |
| neige glacée | crack + squeak haute fréquence |
| glace | glissement + résonance fine |
| bois | impact + résonance modale |
| métal | clank + ringing |
| tissu/tapis | bruit court absorbé |
| eau peu profonde | splash + gouttes + déplacement |
| marécage | suction + bulles + boue liquide |

### 9.5 Chaussures

| Chaussure | Effet |
|---|---|
| pieds nus | peau + slap doux + contact organique |
| sandales | slap séparé semelle/pied |
| bottes cuir | thud profond + craquements cuir |
| bottes métal | impact dur + clinks |
| chaussures modernes | semelle caoutchouc + amorti |
| crampons | micro-impacts métalliques |
| neige/raquettes | surface large + compression |
| chaussures mouillées | squeak + suction |
| chaussures usées | asymétrie, bruits latéraux |
| pieds d’animal | griffes, coussinets, sabots selon espèce |

### 9.6 Variantes déterministes

Pour éviter la répétition :

- seed par pied + step index ;
- pitch jitter ;
- phase de grains ;
- variation de heel/toe ;
- alternance gauche/droite ;
- mémoire de surface humide ;
- accumulation de boue/neige sur chaussure ;
- fatigue qui modifie l’impact ;
- pente qui modifie glissement.

### 9.7 Footstep LOD

| Distance | Rendu |
|---|---|
| 0-8 m | synthèse complète multicouche |
| 8-25 m | couches principales + moins de grains |
| 25-60 m | impression matériau + spatialisation |
| >60 m | virtualisé ou inclus dans ambience crowd/foley |

---

## 10. ImpactSynth : impacts et collisions

### 10.1 Types d’impacts

- pierre sur pierre ;
- pierre sur bois ;
- métal sur pierre ;
- métal sur métal ;
- bois sur terre ;
- corps sur sol ;
- branche cassée ;
- objet qui tombe ;
- arme qui frappe ;
- outil ;
- meuble déplacé ;
- débris ;
- grêle ;
- gouttes lourdes ;
- fruits qui tombent ;
- os/carapace ;
- verre/céramique ;
- cristal ;
- glace.

### 10.2 Modèle

```text
impactSound =
    excitation(force, duration, contactShape)
  → modalResonator(material, size, geometry)
  → damping(surface, wetness, temperature)
  → debrisLayer(optional)
  → spatial/acoustic rendering
```

### 10.3 Modal synthesis

Pour les objets résonants :
- pré-calculer ou approximer des modes ;
- stocker fréquences, amplitudes, decay ;
- exciter selon point d’impact ;
- moduler selon matériau, taille, épaisseur.

```swift
struct ModalProfile {
    var frequencies: [Float]
    var gains: [Float]
    var decays: [Float]
    var materialDamping: Float
}
```

### 10.4 Variante par géométrie procédurale

Comme IsoWorld génère des props, chaque prop peut générer son profil audio :

```text
rock size + density + cracks → dull stone impact
thin metal pole → bright ringing
large wooden table → hollow knock
wet branch → muted crack
dry branch → sharp snap
```

---

## 11. FrictionSynth : frottement, glissement, roulement

### 11.1 Sons couverts

- pied qui glisse ;
- corde qui frotte ;
- rocher poussé ;
- caisse déplacée ;
- lame sur pierre ;
- tissu froissé ;
- pneu sur gravier ;
- roue sur bois ;
- corps qui rampe ;
- griffes sur métal ;
- patin sur glace ;
- bateau contre ponton ;
- branche contre mur ;
- roulement de pierre ;
- roulement de tonneau ;
- sable qui s’écoule.

### 11.2 Paramètres

- vitesse tangentielle ;
- force normale ;
- friction statique/dynamique ;
- rugosité ;
- contact area ;
- matériau A/B ;
- humidité ;
- granularité ;
- compliance ;
- résonance de l’objet.

### 11.3 Modèle source-filtre

```text
contact motion → excitation noise/grains → resonator/object filter → surface filter
```

Pour un glissement sur pierre :
- bruit rugueux filtré ;
- micro-impacts ;
- résonance faible ;
- variations aléatoires corrélées à la vitesse.

Pour une corde :
- fibres ;
- tension ;
- torsion ;
- frottement périodique.

---

## 12. NatureSynth : sons naturels procéduraux

### 12.1 Vent

Le vent ne doit pas être une boucle. Il doit être une simulation sonore paramétrique :

Entrées :
- vitesse du vent ;
- rafales ;
- direction ;
- altitude ;
- densité d’arbres ;
- type de végétation ;
- canyon/falaise ;
- bâtiments ;
- météo ;
- température.

Couches :
- wind bed large bande ;
- whistling tonal autour d’obstacles ;
- leaf rustle ;
- branch creak ;
- grass hiss ;
- canyon roar ;
- gust transients ;
- low-frequency pressure.

Types de vent générables :
- brise légère de prairie ;
- vent dans herbes hautes ;
- vent de forêt dense ;
- vent de forêt de pins ;
- vent dans bambous ;
- vent de falaise ;
- vent de canyon ;
- vent glacial ;
- blizzard ;
- tempête de sable ;
- vent urbain entre immeubles ;
- vent dans câbles ;
- vent dans ruines ;
- vent magique spectral ;
- vent futuriste filtré par dômes ;
- rafales avant orage.

### 12.2 Pluie

Paramètres :
- intensité ;
- taille gouttes ;
- type de surface ;
- végétation ;
- toiture ;
- vent ;
- distance caméra ;
- abris ;
- puddles ;
- orage.

Couches :
- pluie air ;
- impacts sol ;
- impacts feuilles ;
- impacts métal ;
- impacts bois ;
- gouttières ;
- ruissellement ;
- flaques ;
- gouttes isolées ;
- splashes ;
- thunder distant.

Types :
- bruine ;
- pluie fine ;
- pluie tropicale ;
- pluie froide ;
- orage ;
- pluie sur tôle ;
- pluie sur forêt ;
- pluie dans grotte ;
- pluie sur marais ;
- pluie dans ville futuriste ;
- pluie acide ;
- pluie magique cristalline.

### 12.3 Eau

Sons :
- ruisseau ;
- rivière lente ;
- rivière rapide ;
- cascade ;
- vagues lac ;
- mer calme ;
- mer agitée ;
- ressac ;
- gouttes ;
- ruissellement ;
- geyser ;
- source chaude ;
- boue liquide ;
- égout ;
- courant souterrain ;
- glace qui fond ;
- eau sous pont ;
- canal artificiel.

Paramètres :
- débit ;
- pente ;
- turbulence ;
- largeur ;
- profondeur ;
- rochers ;
- végétation ;
- matériaux des berges ;
- météo ;
- distance ;
- cavité.

### 12.4 Feu

Couches :
- crackle ;
- low roar ;
- ember pops ;
- air draw ;
- material burning ;
- smoke turbulence ;
- heat shimmer audio optional.

Types :
- bougie ;
- torche ;
- feu de camp ;
- incendie forêt ;
- brasero ;
- forge ;
- feu humide ;
- feu magique ;
- plasma sci-fi ;
- lave ;
- cendres incandescentes.

### 12.5 Végétation

- feuilles au vent ;
- branches qui craquent ;
- tronc qui gémit ;
- herbe frottée par joueur ;
- buissons ;
- bambous ;
- pins ;
- palmiers ;
- cactus ;
- plantes sèches ;
- plantes alien ;
- fleurs géantes ;
- lianes ;
- racines ;
- mousse ;
- champignons.

Chaque espèce de plante procédurale peut générer un `PlantAudioProfile`.

---

## 13. CreatureVoiceSynth : animaux et créatures procédurales

### 13.1 Objectif

Créer des vocalisations paramétriques cohérentes avec :
- taille ;
- masse ;
- anatomie ;
- habitat ;
- agressivité ;
- distance ;
- émotion ;
- espèce ;
- époque/monde ;
- seed.

### 13.2 Modèle source-filtre

```text
excitation source → vocal tract filter → mouth/nasal resonances → expression modifiers
```

Sources :
- glottal pulse ;
- bruit ;
- growl ;
- hiss ;
- chirp ;
- click ;
- formant oscillator ;
- granular throat ;
- inharmonic buzz.

Filtres :
- formants ;
- tube vocal ;
- nasalité ;
- bec ;
- grotte buccale ;
- résonateur corporel.

### 13.3 Types d’animaux/sons

#### Mammifères
- souffle ;
- grognement ;
- rugissement ;
- cri court ;
- appel lointain ;
- gémissement ;
- reniflement ;
- respiration ;
- pas lourds ;
- mastication ;
- cri de peur ;
- cri d’alerte.

#### Oiseaux
- chants modulaires ;
- trilles ;
- appels ;
- cris territoriaux ;
- battements d’ailes ;
- becs ;
- plumes ;
- oiseaux nocturnes ;
- oiseaux de mer ;
- oiseaux mécaniques/futuristes.

#### Insectes
- bourdonnement ;
- stridulation ;
- essaim ;
- clics ;
- ailes ;
- vibrations ;
- insectes nocturnes ;
- essaim magique.

#### Reptiles/amphibiens
- sifflement ;
- coassement ;
- claquement langue ;
- peau humide ;
- déplacement dans boue ;
- respiration profonde.

#### Créatures fantastiques/alien
- voix à double larynx ;
- clics sonar ;
- drones organiques ;
- souffle cristallin ;
- chants harmoniques ;
- cris infrasoniques ;
- vocalisations modulées par bioluminescence ;
- attaques sonores ;
- langue mécanique.

### 13.4 Variante par seed

Un monde peut générer une grammaire vocale :
- créatures avec cris courts et secs ;
- faune très mélodique ;
- monde silencieux ;
- insectes omniprésents ;
- faune mécanique ;
- animaux sans vocalisation, mais avec frottements corporels ;
- créatures qui imitent le vent ;
- espèces avec motifs rythmiques liés à la musique du monde.

---

## 14. MechanicalSynth : machines et objets manufacturés

### 14.1 Pourquoi procédural ?

Les machines ont des états continus :
- vitesse ;
- couple ;
- charge ;
- usure ;
- température ;
- carburant ;
- puissance ;
- friction ;
- vibration ;
- matériau ;
- taille.

Une boucle fixe est vite répétitive. Un synthé paramétrique peut suivre le gameplay.

### 14.2 Générateurs mécaniques

#### Moteurs
- moteur thermique simple ;
- diesel ;
- turbine ;
- réacteur ;
- moteur électrique ;
- moteur futuriste ;
- générateur instable ;
- machine à vapeur ;
- moteur magique ;
- moteur organique.

Paramètres :
- RPM ;
- torque ;
- throttle ;
- load ;
- damage ;
- gear ;
- resonance body ;
- exhaust path.

#### Engrenages et mécanismes
- engrenage bois ;
- engrenage métal ;
- horloge ;
- moulin ;
- treuil ;
- poulie ;
- ascenseur ;
- pont-levis ;
- porte mécanique ;
- serrure ;
- coffre ;
- machine industrielle ;
- robots.

#### Outils
- scie ;
- perceuse ;
- marteau ;
- forge ;
- pompe ;
- soufflet ;
- imprimante 3D sci-fi ;
- machine agricole ;
- moulin à eau ;
- générateur électrique ;
- drone.

#### Objets du quotidien
- porte bois ;
- porte métal ;
- tiroir ;
- table déplacée ;
- chaise ;
- vaisselle ;
- verre ;
- lampe ;
- interrupteur ;
- livres ;
- tissus ;
- sac ;
- arme ;
- équipement porté.

### 14.3 Modèle moteur harmonique + bruit

```text
rpm → harmonic series + combustion/commutation pulses + mechanical noise + resonance body + exhaust/filter
```

C’est particulièrement bon pour :
- véhicules ;
- machines ;
- générateurs ;
- drones ;
- machines futuristes.

---

## 15. WeatherAudioSystem

La météo doit influencer toutes les couches audio.

### 15.1 Inputs météo

```swift
struct WeatherAudioState {
    var rainIntensity: Float
    var windSpeed: Float
    var windGust: Float
    var snowIntensity: Float
    var thunderProbability: Float
    var fogDensity: Float
    var temperature: Float
    var humidity: Float
    var stormEnergy: Float
}
```

### 15.2 Couches météo

- vent global ;
- pluie air ;
- pluie surface ;
- pluie végétation ;
- ruissellement ;
- tonnerre ;
- neige ;
- grêle ;
- tempête de sable ;
- brouillard sonore ;
- gouttes post-pluie ;
- branches humides ;
- sol mouillé ;
- animaux qui se taisent ou changent ;
- musique filtrée par météo ;
- reverb modifiée par humidité.

### 15.3 Transitions

La météo ne doit pas switcher brutalement. Il faut :
- rampes ;
- crossfades ;
- hystérésis ;
- états intermédiaires ;
- mémoire d’humidité des surfaces ;
- accumulation de neige/eau ;
- événements rares.

---

## 16. AmbienceSystem : paysages sonores procéduraux

### 16.1 Ambiance = écologie sonore

Une ambiance est un écosystème, pas une boucle.

```text
ambience =
    geophony  (vent, eau, météo, géologie)
  + biophony  (animaux, insectes, végétation)
  + anthrophony (humains, machines, culture)
  + music bed optional
  + rare events
```

### 16.2 Biome audio profiles

Chaque biome doit produire un `BiomeAudioProfile`.

```swift
struct BiomeAudioProfile {
    var windResponse: WindResponse
    var insectDensity: Float
    var birdDensity: Float
    var waterPresence: Float
    var foliageNoise: Float
    var silenceWeight: Float
    var rareEvents: [AudioRareEventRule]
    var musicMoodBias: MusicMoodBias
    var acousticAbsorption: Float
}
```

### 16.3 Exemples de biomes

#### Forêt tempérée
- feuilles larges ;
- oiseaux ;
- insectes modérés ;
- branches ;
- sol amorti ;
- pluie très audible.

#### Forêt boréale
- pins ;
- vent aigu ;
- neige ;
- oiseaux rares ;
- craquements bois ;
- silence froid.

#### Jungle
- insectes denses ;
- oiseaux multiples ;
- pluie forte ;
- humidité ;
- eau stagnante ;
- faune lointaine.

#### Désert
- vent sable ;
- silence ;
- insectes nocturnes ;
- réverbération sèche ;
- grains ;
- chaleur.

#### Banquise
- vent large ;
- glace qui craque ;
- neige ;
- réverbération dure ;
- silence extrême ;
- eau sous glace.

#### Ville futuriste
- drones ;
- hum électrique ;
- ventilation ;
- signaux UI ;
- trafic lointain ;
- ambiances filtrées.

#### Monde organique alien
- pulsations ;
- insectes harmoniques ;
- vents respirants ;
- fluides ;
- drones biologiques.

---

## 17. MusicSystem procédural / paramétrique

### 17.1 Objectif

La musique doit être générée ou assemblée à partir de règles liées au monde :

- ambiance ;
- seed ;
- biome ;
- époque ;
- niveau de danger ;
- objectifs RPG ;
- météo ;
- heure ;
- proximité de lieux importants ;
- état émotionnel ;
- progression joueur.

### 17.2 Architecture

```text
WorldThemeDNA
    ↓
HarmonyGenerator
    ↓
MotifGenerator
    ↓
ArrangementDirector
    ↓
InstrumentSynths / sample stems
    ↓
AdaptiveMix
```

### 17.3 WorldThemeDNA

```swift
struct WorldThemeDNA {
    var scale: ScaleDefinition
    var tuning: TuningSystem
    var chordVocabulary: [ChordShape]
    var cadenceRules: CadenceRules
    var rhythmDensity: Float
    var dissonance: Float
    var motifLength: Int
    var instrumentation: InstrumentPalette
    var silenceRatio: Float
    var reverbSpace: Float
    var eraStyle: MusicEraStyle
}
```

### 17.4 Génération harmonique

Méthodes :
- suites d’accords paramétriques ;
- grammaire harmonique ;
- Markov contrôlé ;
- règles modales ;
- tension/résolution ;
- voice leading ;
- drones ;
- pédales ;
- microtonalité ;
- cycles lents ;
- leitmotifs ;
- motifs fractals ;
- transformations par biome.

Exemples :
- monde calme : I–vi–IV–V lent, nappes additives ;
- monde mystérieux : i–bVI–bII–V, drones ;
- monde ancien : modes dorien/phrygien ;
- monde futur : accords quartaux, spectres inharmoniques ;
- monde sacré : quintes ouvertes, chœurs synthétiques ;
- monde corrompu : glissements microtonaux, instabilité.

### 17.5 Générateurs de musique possibles

#### Nappes / drones
- additive sine partials ;
- wavetable slow morph ;
- granular cloud ;
- spectral freeze ;
- formant pads ;
- modal drone ;
- subharmonic bed ;
- noise pad filtré ;
- organique respirant ;
- cristal résonant.

#### Mélodies
- motifs courts ;
- call-response ;
- ostinatos ;
- arpèges ;
- motifs pentatoniques ;
- motifs modaux ;
- motifs microtonaux ;
- motifs générés par topologie ;
- motifs liés aux factions ;
- motifs liés à un objet mythique.

#### Rythmes
- percussions procédurales ;
- pulses doux ;
- battements cardiaques ;
- rythmes tribaux ;
- glitch ;
- drones rythmiques ;
- machines ;
- séquences Euclidiennes ;
- patterns basés sur météo ;
- patterns basés sur pas du joueur.

#### Instruments synthétiques
- additive strings ;
- physical plucked strings ;
- FM bells ;
- modal gongs ;
- granular choir ;
- subtractive bass ;
- wavetable leads ;
- noise flutes ;
- resonant bowls ;
- mechanical percussion.

#### Instruments hybrides
- sample grains + synthèse ;
- sons naturels pitchés ;
- vents transformés en pads ;
- eau granulée ;
- insectes transformés en textures musicales ;
- impacts métalliques transformés en gongs ;
- voix créatures transformées en chœurs.

### 17.6 Musique adaptative

Événements :
- changement de biome ;
- découverte ;
- combat ;
- menace proche ;
- nuit ;
- météo extrême ;
- entrée dans grotte ;
- proximité d’un lieu mythique ;
- accomplissement RPG ;
- danger silencieux.

Techniques :
- stem mixing ;
- vertical remixing ;
- horizontal resequencing ;
- transitions quantifiées ;
- motifs superposés ;
- tension curves ;
- sidechain ambience/music ;
- ducking contextuel ;
- silence dramatique.

---

## 18. Longue liste de synthèses et générateurs possibles

Cette section est volontairement très large. Elle sert de catalogue d’ambition.

### 18.1 Synthèses de base

1. Synthèse additive
2. Synthèse soustractive
3. Synthèse FM
4. Synthèse AM
5. Synthèse wavetable
6. Synthèse granulaire
7. Synthèse par échantillonnage granulaire
8. Synthèse par bruit filtré
9. Synthèse modale
10. Synthèse Karplus-Strong
11. Synthèse source-filtre
12. Synthèse formantique
13. Synthèse par convolution
14. Synthèse par résonateurs
15. Synthèse par physical modeling
16. Synthèse par waveguide
17. Synthèse par oscillateurs non linéaires
18. Synthèse par waveshaping
19. Synthèse spectrale
20. Synthèse par phase vocoder
21. Synthèse vectorielle
22. Synthèse par cross-synthesis
23. Synthèse DDSP-like
24. Synthèse neuronale contrôlée offline
25. Synthèse hybride sample + DSP

### 18.2 Générateurs naturels

1. Vent de prairie
2. Vent en forêt
3. Vent de canyon
4. Vent glacial
5. Blizzard
6. Tempête de sable
7. Vent urbain
8. Vent dans câbles
9. Vent dans ruines
10. Pluie fine
11. Pluie forte
12. Pluie tropicale
13. Pluie sur feuilles
14. Pluie sur métal
15. Pluie sur pierre
16. Pluie sur boue
17. Gouttes sous abri
18. Ruissellement
19. Ruisseau
20. Rivière
21. Torrent
22. Cascade
23. Lac
24. Mer calme
25. Mer agitée
26. Vagues contre rochers
27. Vagues contre sable
28. Marais
29. Bulles de boue
30. Source chaude
31. Geyser
32. Glace qui craque
33. Neige sous vent
34. Grêle
35. Tonnerre lointain
36. Tonnerre proche
37. Feu de camp
38. Incendie
39. Braise
40. Lave
41. Fumerolles
42. Éboulis
43. Pierre qui roule
44. Sable qui s’écoule
45. Arbre qui craque
46. Branches qui tombent
47. Feuilles sèches
48. Herbes hautes
49. Roseaux
50. Bambous
51. Champignons alien
52. Coraux
53. Caverne humide
54. Écho de montagne
55. Avalanche
56. Séisme léger
57. Orage magnétique
58. Pluie acide
59. Cristaux résonants
60. Biome organique respirant

### 18.3 Générateurs de pas

1. Pas pieds nus sur pierre
2. Pas pieds nus sur sable
3. Pas pieds nus sur eau
4. Pas pieds nus sur boue
5. Bottes sur bois
6. Bottes sur métal
7. Bottes sur gravier
8. Bottes sur neige
9. Bottes mouillées
10. Chaussures modernes sur béton
11. Chaussures modernes sur herbe
12. Chaussures modernes sur carrelage
13. Crampons sur glace
14. Armure lourde sur pierre
15. Sandales sur poussière
16. Pattes animales sur terre
17. Sabots sur pierre
18. Griffes sur bois
19. Créature lourde sur boue
20. Robot léger sur métal
21. Robot lourd sur béton
22. Exosquelette sur sol humide
23. Pas furtifs
24. Pas fatigués
25. Pas blessés
26. Course
27. Sprint
28. Glissade
29. Dérapage
30. Atterrissage
31. Saut
32. Escalade roche
33. Escalier bois
34. Escalier métal
35. Corde
36. Échelle
37. Neige poudreuse
38. Neige glacée
39. Feuilles mortes
40. Végétation dense

### 18.4 Générateurs de contacts

1. Impact pierre/pierre
2. Impact bois/bois
3. Impact métal/métal
4. Impact métal/pierre
5. Impact verre
6. Impact céramique
7. Impact os
8. Impact cristal
9. Impact glace
10. Impact boue
11. Impact eau
12. Friction corde/bois
13. Friction métal/pierre
14. Friction bois/pierre
15. Friction tissu
16. Froissement cuir
17. Froissement papier
18. Froissement feuilles
19. Roulement rocher
20. Roulement roue
21. Roulement tonneau
22. Grincement porte
23. Craquement branche
24. Rupture corde
25. Chute objet
26. Débris
27. Traînée caisse
28. Chaîne
29. Cloche
30. Gong
31. Arme
32. Bouclier
33. Outil
34. Ressort
35. Charnière
36. Serrure
37. Mécanisme secret
38. Sculpture mobile
39. Fragmentation
40. Effondrement léger

### 18.5 Générateurs animaux

1. Oiseaux diurnes
2. Oiseaux nocturnes
3. Oiseaux de mer
4. Rapaces
5. Petits mammifères
6. Grands mammifères
7. Prédateurs
8. Herbivores
9. Insectes jour
10. Insectes nuit
11. Essaims
12. Amphibiens
13. Reptiles
14. Poissons sautant
15. Créatures de grotte
16. Créatures de marais
17. Créatures désertiques
18. Créatures glaciaires
19. Créatures mécaniques
20. Créatures alien
21. Dragons / grands reptiles
22. Géants
23. Esprits
24. Animaux domestiques
25. Animaux de ferme
26. Animaux montures
27. Faune silencieuse
28. Faune mimétique
29. Faune chorale
30. Faune agressive

### 18.6 Générateurs mécaniques

1. Moteur thermique
2. Moteur diesel
3. Moteur électrique
4. Turbine
5. Réacteur
6. Machine à vapeur
7. Pompe
8. Moulin
9. Treuil
10. Poulie
11. Engrenages
12. Horloge
13. Ascenseur
14. Porte automatique
15. Pont-levis
16. Forge
17. Générateur
18. Ventilation
19. Drone
20. Robot
21. Exosquelette
22. Véhicule léger
23. Véhicule lourd
24. Train
25. Bateau
26. Machine agricole
27. Machine industrielle
28. Terminal futuriste
29. Console rétro
30. Imprimante/constructeur
31. Antenne
32. Radar
33. Champ énergétique
34. Arme énergétique
35. Bouclier
36. Téléporteur
37. Machine instable
38. Ruine technologique
39. Mécanisme ancien
40. Artefact sonore

### 18.7 Générateurs musicaux

1. Drone harmonique
2. Drone inharmonique
3. Nappe additive
4. Nappe granulaire
5. Nappe wavetable
6. Nappe de vent transformé
7. Nappe de voix
8. Chœur synthétique
9. Chœur animal
10. Cordes physiques
11. Cordes synthétiques
12. Cloches FM
13. Gongs modaux
14. Percussions procédurales
15. Arpèges
16. Motifs pentatoniques
17. Motifs modaux
18. Motifs microtonaux
19. Séquences Euclidiennes
20. Pulses ambient
21. Bass drones
22. Textures bruitées
23. Textures cristallines
24. Textures organiques
25. Musique de biome
26. Musique de faction
27. Musique de danger
28. Musique de découverte
29. Musique de nuit
30. Musique météo
31. Musique mythique
32. Musique de combat légère
33. Musique sans combat
34. Musique de ruine
35. Musique future
36. Musique primitive
37. Musique rituelle
38. Musique industrielle
39. Musique éthérée
40. Silence génératif

---

## 19. Audio procédural par seed : mondes sonores

### 19.1 Exemples de mondes audio

1. **Monde pastoral calme**  
   Nappes douces, oiseaux, vent léger, peu de basses, harmonies consonantes.

2. **Monde hostile minéral**  
   Résonances de pierre, vents de canyon, impacts secs, peu de vie, musique modale tendue.

3. **Monde de pluie éternelle**  
   Pluie multimatériau, ruisseaux, boue, pas humides, musique filtrée et mélancolique.

4. **Monde glaciaire**  
   Vent fort, glace qui craque, neige compressée, silences larges, drones froids.

5. **Monde jungle organique**  
   Densité d’insectes, faune vocale, pluie, percussions naturelles, motifs rythmiques.

6. **Monde futur lointain**  
   Machines basses, drones spectraux, UI audio chirurgicale, spatialisation propre.

7. **Monde sans technologie**  
   Bois, pierre, cuir, vent, feu, eau, musique acoustique procédurale.

8. **Monde mécanique ancien**  
   engrenages, cloches, vapeur, résonances de métal, rythmes réguliers.

9. **Monde magique cristallin**  
   cloches FM, résonances longues, vents harmoniques, faune chantante.

10. **Monde corrompu**  
    pitch instable, dissonances, bruit organique, météo malade, faune déformée.

11. **Monde désertique silencieux**  
    silence, sable, vent, insectes nocturnes, drones très lents.

12. **Monde océanique**  
    vagues, bois mouillé, cordages, vents, chants lointains, harmonie mouvante.

13. **Monde souterrain**  
    gouttes, réverbérations, roche, échos, créatures invisibles, basses profondes.

14. **Monde pastoral sans ennemis**  
    pas doux, musiques ouvertes, faune non agressive, transitions musicales lentes.

15. **Monde ritualiste**  
    percussions lentes, chants, cloches, reverb sacrée, lieux mythiques sonores.

16. **Monde cyber-nature**  
    insectes synthétiques, vents filtrés, arbres mécaniques, drones électriques.

17. **Monde post-apocalyptique**  
    vent dans ruines, métal qui grince, silences, machines rares, musique dégradée.

18. **Monde miniature**  
    pas très détaillés, insectes énormes, gouttes massives, matériaux amplifiés.

19. **Monde géant**  
    basses puissantes, grands espaces, impacts lents, météo massive.

20. **Monde onirique**  
    sons inversés, tonalités mouvantes, spatialisation impossible, musique générative flottante.

---

## 20. Spatialisation et acoustique

### 20.1 Minimum viable AAA-like

Même sans raytracing acoustique lourd, il faut :

- distance attenuation ;
- pan stéréo/binaural optionnel ;
- doppler ;
- occlusion par géométrie simple ;
- obstruction partielle ;
- low-pass par occlusion ;
- reverb send par zone ;
- early reflections approximées ;
- interior/exterior detection ;
- portals audio ;
- surface acoustic materials ;
- priority by audibility.

### 20.2 Acoustic probes

Le monde chunké peut générer des probes :

```swift
struct AcousticProbe {
    var position: SIMD3<Float>
    var roomSize: Float
    var openness: Float
    var absorption: Float
    var wetness: Float
    var materialProfile: AcousticMaterialProfile
    var reverbPresetBlend: ReverbBlend
}
```

### 20.3 Zones

- extérieur ouvert ;
- forêt dense ;
- canyon ;
- grotte ;
- bâtiment ;
- tunnel ;
- sous pont ;
- ruines ;
- vallée ;
- intérieur métal ;
- intérieur bois ;
- temple ;
- laboratoire ;
- sous l’eau.

### 20.4 Occlusion simple

Au départ :
- raycasts audio peu fréquents ;
- cache par source ;
- matériau du hit ;
- low-pass + volume reduction ;
- interpolation lente.

Plus tard :
- portals ;
- graph de rooms ;
- occlusion multi-ray ;
- diffraction approximée ;
- réflexion pré-bakée par chunk.

---

## 21. MixSystem

### 21.1 Bus proposés

```text
Master
├─ Music
│  ├─ Music_Bed
│  ├─ Music_Melody
│  ├─ Music_Percussion
│  └─ Music_Stingers
├─ Ambience
│  ├─ Ambience_Geo
│  ├─ Ambience_Bio
│  ├─ Ambience_Weather
│  └─ Ambience_Rare
├─ Foley
│  ├─ Footsteps_Player
│  ├─ Footsteps_NPC
│  ├─ Cloth
│  └─ Gear
├─ World
│  ├─ Props
│  ├─ Mechanics
│  ├─ Water
│  ├─ Fire
│  └─ Impacts
├─ Creatures
├─ UI
├─ Dialogue/Future
└─ Debug
```

### 21.2 Snapshots

Snapshots :
- exploration ;
- combat ;
- danger ;
- underwater ;
- cave ;
- storm ;
- night ;
- low health ;
- inventory ;
- pause ;
- discovery ;
- sacred place ;
- stealth ;
- dream.

Chaque snapshot contrôle :
- gains ;
- EQ ;
- sends reverb ;
- compression ;
- ducking ;
- music intensity ;
- ambience density.

### 21.3 Loudness

Même pour un POC, prévoir :
- headroom ;
- limiter master ;
- normalisation perceptuelle ;
- catégories prioritaires ;
- mix snapshots ;
- monitoring RMS/peak ;
- protection contre clipping.

---

## 22. LOD audio et budgets

### 22.1 Pourquoi

Un monde procédural peut générer trop de sons. Il faut virtualiser.

### 22.2 Voice priorities

Critères :
- distance ;
- importance gameplay ;
- visibilité ;
- catégorie ;
- nouveauté ;
- volume estimé ;
- fréquence ;
- unicité ;
- budget actuel.

### 22.3 États d’une source

```text
ActiveFull
ActiveReduced
VirtualTimeline
Culled
BakedIntoAmbience
```

Exemple :
- feu proche : particules audio + crackles + spatial ;
- feu moyen : crackle réduit ;
- feu loin : simple bed ;
- feu très loin : intégré à ambience.

### 22.4 LOD par génération

| Son | Full | Reduced | Far |
|---|---|---|---|
| pas joueur | toutes couches | pas réduit | jamais cull |
| pas NPC | couches principales | impression | ambience crowd |
| vent | obstacle-aware | biome wind | global bed |
| rivière | détail turbulence | loop procédurale | bed |
| machine | harmonics complets | RPM impression | drone |
| faune | vocalisations | calls rares | ambience |
| musique | full | full | full |

---

## 23. Audio + terrain + matériaux

Le moteur terrain doit exposer des infos audio.

### 23.1 SurfaceMaterial enum

```swift
enum SurfaceMaterial {
    case stone, gravel, sand, mud, grass, leaves, snow, ice
    case wood, metal, ceramic, glass, cloth, carpet, water
    case moss, roots, bone, crystal, fleshOrganic, synthetic
}
```

### 23.2 Surface blend

Si le terrain utilise des splats, l’audio doit lire les poids :

```swift
struct SurfaceBlendAudio {
    var materials: [(SurfaceMaterial, Float)]
    var wetness: Float
    var snow: Float
    var mud: Float
}
```

Un pas sur 60 % herbe, 25 % boue, 15 % gravier doit mélanger les couches.

### 23.3 Micro-variation

Pour un rendu naturel :
- bruit procédural spatial ;
- taille locale des grains ;
- humidité locale ;
- compaction ;
- végétation ;
- pente ;
- proximité eau ;
- altitude ;
- température.

---

## 24. Audio + props procéduraux

Chaque prop généré doit avoir un profil sonore.

```swift
struct PropAudioProfile {
    var material: AcousticMaterial
    var size: Float
    var density: Float
    var hollowness: Float
    var resonance: ModalProfile?
    var friction: FrictionProfile
    var breakage: BreakageProfile?
    var ambientEmitter: AmbientEmitterProfile?
}
```

Exemples :
- arbre : bruissement, craquement, impact bois, chute branches ;
- rocher : impact modal, roulement, glissement ;
- table : coups creux, frottement bois ;
- lampadaire : métal creux, vent dans tube ;
- animal : vocal tract, pas, respiration ;
- machine : hum, gears, cooling, vibration.

---

## 25. Audio + animation / physique

Le système d’animation procédurale doit envoyer des événements précis :

- foot down ;
- heel contact ;
- toe contact ;
- slip ;
- landing ;
- hand contact ;
- cloth motion ;
- gear movement ;
- collision ;
- ragdoll impact ;
- climbing hold ;
- rope tension.

### 25.1 Contact audio

```swift
struct ContactAudioEvent {
    var bodyA: PhysicsBodyID
    var bodyB: PhysicsBodyID
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var normalImpulse: Float
    var tangentialVelocity: Float
    var contactDuration: Float
    var materialA: AudioMaterial
    var materialB: AudioMaterial
}
```

---

## 26. Audio + météo

La météo doit modifier :
- son des pas ;
- son des surfaces ;
- réverbération ;
- faune ;
- densité d’ambiance ;
- musique ;
- mécanique ;
- UI/hud audio éventuellement ;
- absorption ;
- muffling.

Exemples :
- pluie sur armure = couche métallique gouttes ;
- neige = pas amortis + aigus réduits ;
- brouillard = moins d’aigus, plus de proximité ;
- tempête = ducking naturel des sons faibles ;
- chaleur désertique = silence + insectes + air shimmer audio stylisé.

---

## 27. Audio + RPG

Le `WorldRPGDNA` influence l’audio.

Exemples :
- époque sans technologie : pas de hum électrique, plus de bois/cuir/pierre ;
- époque moderne : moteurs, ventilation, interfaces ;
- futur lointain : drones, signaux, matériaux synthétiques ;
- monde sans ennemis : danger music désactivée, faune plus ouverte ;
- monde mythique : leitmotifs d’artefacts ;
- monde religieux : cloches, chants, résonances sacrées ;
- monde corrompu : pitch drift, dissonance, saturation ;
- monde où la magie existe : matériaux avec résonances impossibles.

---

## 28. Système de recettes audio

### 28.1 Exemple : footstep

```yaml
id: footstep_physical_universal
inputs:
  mass: gameplay.character.mass
  verticalImpulse: animation.foot.verticalImpulse
  slip: animation.foot.tangentialSlip
  surface: world.surfaceAudio
  footwear: character.footwear
layers:
  - impact:
      model: modal_noise_impact
      gain: curve(verticalImpulse)
      material: surface.material
  - grain:
      model: granular_surface
      density: surface.gravelSize
      enabled: surface.gravelWeight > 0.1
  - wet:
      model: squish_splash
      gain: surface.wetness * footwear.treadDepth
  - vegetation:
      model: rustle
      gain: surface.vegetationDensity
variation:
  rng: deterministic
  pitch: [-0.05, 0.05]
  grainOffset: random
lod:
  fullDistance: 8
  reducedDistance: 25
```

### 28.2 Exemple : biome ambience

```yaml
id: biome_ambience_forest_temperate
type: ambience_graph
inputs:
  wind: weather.windSpeed
  rain: weather.rainIntensity
  time: world.timeOfDay
  season: world.season
  density: biome.vegetationDensity
layers:
  - wind_leaves
  - birds_day
  - insects_evening
  - branch_creaks
  - distant_water_optional
rareEvents:
  - owl_call:
      condition: night && rng < 0.02
  - branch_snap:
      condition: windGust > 0.7
musicBias:
  mode: dorian
  density: low
```

### 28.3 Exemple : music theme

```yaml
id: world_music_language_calm_mystic
scale: dorian
tuning: equal_temperament_12
chords:
  - i
  - bVII
  - IV
  - v
cadence:
  avoidStrongResolution: true
motifs:
  lengthBeats: [3, 5, 8]
  intervalSet: [-2, 0, 2, 5, 7]
instruments:
  - additive_pad
  - modal_bells
  - granular_wind
arrangement:
  intensityControlledBy: gameplay.tension
  biomeLayerInfluence: 0.5
```

---

## 29. Qualité audio : éviter les pièges

### 29.1 Risques des sons procéduraux

- trop synthétique ;
- répétition algorithmique ;
- manque d’attaque réaliste ;
- paramètres mal calibrés ;
- trop de modulation ;
- pas assez de couches ;
- artefacts de granularité ;
- bruit blanc évident ;
- CPU trop élevé ;
- mix instable.

### 29.2 Solutions

- hybrider avec samples/grains ;
- calibrer contre des références réelles ;
- pré-rendre certains éléments ;
- utiliser des banques de profils matériaux ;
- limiter les ranges ;
- lisser les paramètres ;
- tests AB ;
- outils de visualisation ;
- snapshots de mix ;
- validation perceptuelle.

### 29.3 Règle de production

Chaque générateur doit avoir :
- version simple ;
- version haute qualité ;
- presets ;
- seed stable ;
- tests ;
- exemples ;
- limites ;
- LOD ;
- debug view ;
- offline render.

---

## 30. Pipeline d’authoring

### 30.1 AudioRecipeEditor

Fonctions :
- graph editor ;
- preview avec paramètres ;
- random seed audition ;
- rendu offline ;
- comparaison A/B ;
- courbes ;
- presets ;
- tagging ;
- matériaux ;
- export JSON/binaire ;
- profiling CPU ;
- spectrogramme ;
- loudness meter ;
- visualisation oscilloscopique.

### 30.2 WorldAudioDebugger

In-game :
- sources actives ;
- voix virtuelles ;
- events par seconde ;
- coût CPU ;
- bus levels ;
- snapshots actifs ;
- occlusion ;
- biome audio ;
- météo audio ;
- musique state ;
- seed audio ;
- LOD audio ;
- matériaux sous joueur.

### 30.3 Offline rendering

Permettre :
- rendre 100 variantes d’un pas ;
- rendre un biome pendant 5 minutes ;
- rendre une suite musicale ;
- générer des banques de grains ;
- vérifier pas de clipping ;
- exporter pour tests.

---

## 31. Format de fichiers

### 31.1 AudioRecipe

- YAML/JSON authoring ;
- format binaire runtime ;
- hash stable ;
- version ;
- dépendances ;
- tags ;
- fallback.

### 31.2 AudioGraph

- nodes ;
- edges ;
- parameters ;
- defaults ;
- ranges ;
- exposed controls ;
- LOD variants.

### 31.3 MaterialAudioProfile

```yaml
id: material_mud_wet
hardness: 0.1
roughness: 0.7
porosity: 0.9
wetnessResponse: strong
impact:
  attack: soft
  lowFreq: high
friction:
  suction: high
  granular: low
footstep:
  squish: high
  splash: medium
acoustic:
  absorption: high
  reflection: low
```

---

## 32. Implémentation Swift / bas niveau

### 32.1 Swift API

Swift est excellent pour :
- API gameplay ;
- data assets ;
- tools ;
- éditeur ;
- paramètres ;
- scheduling non realtime ;
- tests ;
- intégration macOS.

### 32.2 DSP temps réel

Pour le DSP :
- éviter ARC sur le thread audio ;
- éviter closures capturantes ;
- éviter allocations ;
- utiliser buffers préalloués ;
- envisager C/C++/C-compatible DSP kernels ;
- utiliser Accelerate/vDSP pour opérations vectorielles ;
- utiliser structs simples ;
- ring buffers lock-free.

### 32.3 Exemple API

```swift
final class IsoAudio {
    func post(_ event: AudioEvent)
    func setGlobal(_ parameter: AudioParameterID, _ value: Float)
    func setSnapshot(_ snapshot: MixSnapshotID, weight: Float, fade: Float)
    func registerEmitter(_ emitter: AudioEmitter)
    func updateListener(_ listener: AudioListener)
}
```

### 32.4 Realtime command

```swift
struct AudioCommand {
    var type: AudioCommandType
    var voiceId: UInt32
    var recipeId: UInt32
    var seed: UInt64
    var paramsOffset: UInt32
}
```

---

## 33. Possibilité GPU ?

La synthèse audio est généralement CPU, mais certains usages GPU peuvent être utiles offline ou non temps réel :

- génération offline de banques procédurales ;
- analyse spectrale ;
- convolution massive offline ;
- entraînement/évaluation ;
- rendu de variantes ;
- génération d’impulsions ;
- tools.

Pour le runtime M1, garder le rendu audio sur CPU est plus simple et plus sûr. Le GPU est déjà utilisé par Metal pour le rendu ; synchroniser audio/GPU en temps réel peut ajouter de la latence et de la complexité.

---

## 34. Roadmap d’implémentation

### Phase 1 — Fondations

- `IsoAudioEngine` minimal ;
- backend AVAudioEngine ou CoreAudio simple ;
- bus master/music/ambience/foley/world/ui ;
- event queue ;
- deterministic RNG ;
- sample player ;
- simple noise synth ;
- debug meters ;
- footstep basic material switching.

### Phase 2 — Graphes procéduraux

- `AudioRecipe`;
- node graph simple ;
- oscillators/noise/filter/envelope/mixer ;
- graph compiler ;
- presets ;
- offline renderer ;
- first procedural footstep.

### Phase 3 — Footsteps physiques

- surface audio sampling ;
- footwear ;
- wetness/mud/snow ;
- gravel/grass/leaves ;
- animation contacts ;
- LOD footstep ;
- tests de variantes.

### Phase 4 — Ambiences naturelles

- wind synth ;
- rain synth ;
- water synth ;
- biome ambience manager ;
- rare events ;
- weather transitions ;
- reverb zones.

### Phase 5 — Musique générative

- world music DNA ;
- harmony generator ;
- additive pads ;
- granular beds ;
- motif generator ;
- arrangement director ;
- transitions quantifiées.

### Phase 6 — Spatial/acoustic

- source spatializer ;
- occlusion raycasts ;
- reverb zones ;
- acoustic materials ;
- interior/exterior ;
- portals simple.

### Phase 7 — Moteur avancé

- modal impact synth ;
- friction synth ;
- creature voice synth ;
- mechanical synth ;
- profiler complet ;
- authoring UI ;
- PHASE bridge expérimental.

---

## 35. MVP concret pour IsoWorld

Le meilleur MVP pour prouver la valeur du moteur :

1. Terrain avec 6 matériaux audio :
   - stone ;
   - grass ;
   - gravel ;
   - mud ;
   - snow ;
   - wood.

2. Player footsteps procéduraux :
   - masse ;
   - vitesse ;
   - chaussure ;
   - humidité ;
   - pente ;
   - foot contact.

3. Ambiance biome :
   - vent ;
   - insectes ;
   - oiseaux ;
   - eau optional.

4. Météo :
   - pluie qui change les pas et ajoute impacts surface.

5. Musique :
   - drone additive + suite d’accords paramétrique ;
   - variations par seed ;
   - crossfade biome/tension.

6. Debug :
   - afficher surface audio sous les pieds ;
   - afficher events ;
   - afficher voix ;
   - exporter 50 variantes d’un pas.

Ce MVP donnera une preuve immédiate : même monde visuel, mais seed/biome/météo modifient profondément l’expérience sonore.

---

## 36. Conclusion

IsoWorld doit viser un moteur audio qui fait partie de la génération du monde.  
Le son ne doit pas être une couche décorative ajoutée après le rendu ; il doit être dérivé des mêmes règles que le terrain, les biomes, les props, la météo, les animations et le RPG.

La bonne architecture est :

```text
Apple backend + custom deterministic DSP engine + procedural graph authoring + world-aware recipes
```

Le système doit être capable de générer :
- des pas physiques précis ;
- des ambiances naturelles dynamiques ;
- des créatures vocales paramétriques ;
- des machines continues ;
- des contacts physiques ;
- des musiques génératives ;
- des thèmes de monde ;
- des transitions audio liées aux biomes, à la météo et au RPG.

La priorité est de construire d’abord une base fiable :
- event system ;
- mixer ;
- graph DSP ;
- footstep synth ;
- ambience synth ;
- music DNA ;
- debug tools.

Ensuite, chaque autre système IsoWorld pourra exposer des paramètres audio et enrichir naturellement l’expérience.

---

## 37. Sources et références utiles

- Apple Developer — PHASE : https://developer.apple.com/documentation/phase/
- Apple Developer — AVAudioEngine / Audio Engine : https://developer.apple.com/documentation/avfaudio/audio-engine
- Apple Developer — Audio Unit : https://developer.apple.com/documentation/audiounit/
- Apple Developer — Creating custom audio effects : https://developer.apple.com/documentation/avfaudio/creating-custom-audio-effects
- Unreal Engine — MetaSounds : https://dev.epicgames.com/documentation/unreal-engine/metasounds-the-next-generation-sound-sources-in-unreal-engine
- Unreal Engine blog — MetaSounds + Quartz : https://www.unrealengine.com/blog/exploring-metasounds-a-new-high-performance-audio-system-in-unreal-engine-5
- Audiokinetic Wwise documentation : https://www.audiokinetic.com/en/library/
- Audiokinetic Wwise Interactive Music : https://www.audiokinetic.com/en/public-library/2025.1.7_9143/?id=creating_interactive_music&source=Help
- Audiokinetic Wwise Synth One : https://www.audiokinetic.com/en/library/edge/?id=wwise_synth_one_plug_in&source=Help
- Audiokinetic SoundSeed Wind : https://www.audiokinetic.com/en/public-library/2025.1.8_9170/?id=wwise_soundseed_air_wind_plug_in&source=Help
- FMOD Studio documentation : https://www.fmod.com/docs/
- Steam Audio documentation : https://valvesoftware.github.io/steam-audio/
- Tsugi GameSynth : https://tsugi-studio.com/web/en/products-gamesynth.html
- AudioKit : https://www.audiokit.io/
- SuperCollider server architecture : https://doc.sccode.org/Reference/Server-Architecture.html
- Pure Data : https://puredata.info/
- Physically Based Sound for Computer Animation and Virtual Environments : https://graphics.stanford.edu/courses/sound/
- DAFx — Physically Based Sound Synthesis and Control of Footsteps Sounds : https://dafx10.iem.at/proceedings/papers/TurchetSerafinDimitrovNordahl_DAFx10_P50.pdf
- ACM — Physically-based Sound Effects for Interactive Simulation and Animation : https://dl.acm.org/doi/10.1145/383259.383322
- Cornell Sound Rendering for Physically Based Simulation : https://www.cs.cornell.edu/projects/Sound/
- DDSP-SFX : https://arxiv.org/abs/2309.08060
- DeepModal — real-time impact sound synthesis : https://hellojxt.github.io/DeepModal/
- Object-based synthesis of scraping and rolling sounds : https://arxiv.org/abs/2112.08984
- MIDI-DDSP : https://arxiv.org/abs/2112.09312
