# IsoWorld — Pipeline IA/ML Metal 4 pour la brique RPG

**Sujet couvert uniquement :** évaluer si IsoWorld doit intégrer une couche modèles / AI / ML autour de sa brique RPG procédurale déterministe, en tenant compte de Metal 4, PyTorch/MPS, Core ML, de l’architecture IsoWorld existante et des contraintes MacBook Pro M1.

**Fichier :** `metal4-ai-ml-rpg-pipeline.md`

**Date :** 2026-06-15

---

## 0. Réponse courte

Oui, c’est possible et pertinent d’entraîner des modèles spécifiques pour certains systèmes RPG d’IsoWorld, mais il ne faut pas faire du ML le cœur autoritaire du moteur.

La bonne approche est :

```text
Moteur déterministe IsoWorld
  -> génère règles, world state, factions, quêtes, PNJ, storylets, lieux, tags
  -> expose des snapshots stables et compacts
  -> demande à des modèles spécialisés des propositions / scores / formulations
  -> valide ces sorties par règles déterministes
  -> écrit uniquement les décisions validées dans WorldStateLedger / SaveDelta
```

Le ML doit donc être une **couche d’assistance, de scoring, de variation, de langage, de compression ou d’optimisation**, pas un générateur incontrôlé qui décide librement de l’état du monde.

La recommandation finale est d’intégrer un pipeline IA/ML, mais en trois niveaux :

1. **Offline / outils moteur** : entraînement, génération de datasets, validation de seeds, aide à l’authoring, génération de variantes, tests de cohérence.
2. **Runtime non autoritaire** : modèles qui proposent, classent, reformulent, compressent ou embellissent, mais ne modifient pas seuls les règles du monde.
3. **Runtime GPU serré** : petits modèles Core ML / Metal 4 pour des tâches compactes, bornées, profilées et synchronisées avec le frame graph.

---

## 1. Ce que Metal 4 change réellement

Metal 4 rend beaucoup plus crédible l’intégration de ML dans un moteur custom Apple Silicon, parce qu’il permet d’exécuter des réseaux ML sur le GPU timeline, aux côtés des passes compute et render, via des ressources de type tensor et un encoder ML. Apple présente notamment `MTLTensor`, `MTL4MachineLearningCommandEncoder`, les `MTLPackage`, et Shader ML pour intégrer des opérations ML directement dans les shaders.

Mais il faut distinguer quatre usages :

| Usage | Pertinence pour IsoWorld | Commentaire |
|---|---:|---|
| Entraîner des modèles | Moyenne à forte | Plutôt via PyTorch + backend MPS sur Mac, ou machine plus puissante / cloud. |
| Convertir / packager des modèles | Forte | Pipeline PyTorch/TensorFlow -> Core ML package -> Metal package. |
| Inférence runtime large | Moyenne | Possible, mais à budgéter strictement ; attention au M1. |
| Inférence runtime minuscule / shader ML | Très forte | Excellent pour scoring local, animation, rendering neural, matériaux, compression, heuristiques compactes. |

Conclusion importante : **Metal 4 rend l’inférence ML plus native dans le moteur**, mais le pipeline d’entraînement doit rester un pipeline d’outils, pas une activité normale du gameplay.

---

## 2. Décision architecturale IsoWorld

### 2.1 Décision recommandée

Ajouter une nouvelle couche :

```text
EngineCore
  AIModelCore
    ModelRegistry
    ModelMetadata
    FeatureSchemas
    InferenceRequest
    InferenceResult
    InferenceBudget
    DeterminismGuard
    OutputValidator
    ModelVersionTable
    ReplayHash

  RPGCore
    WorldRPGDNA
    WorldRuleset
    QuestSystem
    StoryletSystem
    FactionSystem
    NPCSocialSystem
    DirectorSystem
    WorldStateLedger

  Tooling
    MLAuthoringLab
    DatasetBuilder
    ModelTrainerProfiles
    EvaluationHarness
    SeedReplayHarness
    PromptAndCorpusLab
    ExportCoreMLPipeline
    MetalPackageBuilderBridge
```

Le moteur reste structuré autour de `WorldRPGDNA`, `WorldRuleset`, `QuestGraph`, `StoryletSystem`, `FactionSystem`, `DirectorSystem` et `WorldStateLedger`.

La couche AI/ML ne remplace aucun de ces systèmes. Elle les **augmente**.

### 2.2 Règle absolue

```text
Aucun modèle ne peut écrire directement dans l’état autoritaire du monde.
```

Un modèle peut produire :

- un score ;
- un classement ;
- une intention ;
- une reformulation ;
- une émotion probable ;
- une catégorie ;
- un embedding ;
- une proposition de quête ;
- un résumé ;
- une variation textuelle ;
- un diagnostic ;
- une prédiction de cohérence.

Mais l’écriture finale passe par :

```text
AIProposal
  -> RuleValidator
  -> DeterminismGuard
  -> BudgetGuard
  -> ContentSafetyGuard
  -> WorldStateLedger append
```

---

## 3. Pourquoi ne pas faire un modèle par système sans garde-fous

L’idée “un modèle pour chaque système” est séduisante, mais dangereuse si elle est appliquée naïvement.

Risques :

- explosion de complexité ;
- debugging difficile ;
- dérive non déterministe ;
- comportements impossibles à rejouer ;
- incohérences de lore ;
- coût GPU/CPU imprévisible ;
- dépendance à des poids de modèles difficiles à versionner ;
- sauvegardes fragiles si les modèles changent ;
- difficulté à tester les seeds ;
- gameplay moins lisible si le modèle invente trop.

La bonne granularité n’est donc pas “un modèle par système”, mais :

```text
un système déterministe par domaine
  + éventuellement un ou plusieurs modèles spécialisés par tâche bornée
```

Exemple :

```text
NPCSocialSystem déterministe
  + NPCIntentClassifier
  + DialogueStyleModel
  + RelationshipRiskScorer
  + MemorySummarizer
```

---

## 4. Cas 1 — Modèle pour interactions PNJ

### 4.1 Oui, c’est pertinent

Un modèle dédié aux interactions PNJ est l’un des meilleurs candidats.

Mais il ne doit pas être responsable de toute la conversation. Il doit être encadré par un système symbolique.

Architecture recommandée :

```text
WorldStateLedger
WorldRPGDNA
NPCProfile
FactionContext
LocalPlaceContext
RecentEvents
PlayerReputation
KnownFacts
DialogueRules
  -> NPCDialogueContextSnapshot
  -> Model inference
  -> DialogueProposal
  -> LoreValidator
  -> FactValidator
  -> ToneValidator
  -> ChoiceBuilder
  -> UI Dialogue
```

### 4.2 Ce que le modèle peut faire

- reformuler une réponse dans le ton du PNJ ;
- choisir une intention parmi une liste autorisée ;
- générer une ligne de dialogue courte ;
- résumer les souvenirs pertinents du PNJ ;
- classer les sujets dont le PNJ accepte de parler ;
- détecter l’émotion probable d’un PNJ ;
- produire des variantes non critiques ;
- adapter le vocabulaire au biome, à la faction, à l’époque, à la culture.

### 4.3 Ce que le modèle ne doit pas faire seul

- inventer un fait majeur du monde ;
- créer une quête autoritaire ;
- modifier une faction ;
- donner un objet réel au joueur ;
- tuer un PNJ ;
- changer un endgame ;
- réécrire une loi du monde ;
- casser une contrainte du seed.

### 4.4 Structure recommandée

```swift
struct NPCDialogueContextSnapshot: Codable, Hashable {
    let worldRPGTags: [GameplayTag]
    let npcID: StableID
    let npcArchetype: NPCArchetype
    let factionID: StableID?
    let cultureTags: [GameplayTag]
    let relationshipState: RelationshipState
    let knownFacts: [WorldFactID]
    let localRumors: [RumorID]
    let allowedTopics: [DialogueTopicID]
    let forbiddenClaims: [WorldFactID]
    let toneProfile: ToneProfile
    let playerRecentActions: [LedgerEventID]
}

struct DialogueProposal: Codable, Hashable {
    let intent: NPCDialogueIntent
    let text: String
    let referencedFacts: [WorldFactID]
    let emotionalDelta: EmotionalDelta
    let suggestedPlayerChoices: [DialogueChoiceProposal]
    let confidence: Float
}
```

### 4.5 Recommandation modèle

Pour la V2/V3, ne pas commencer avec un gros LLM runtime.

Commencer par :

- un modèle de **classification d’intention** ;
- un modèle de **style / réécriture courte** utilisé dans les outils ;
- un système de **templates dialogue + slots + variation** ;
- un validateur fort de faits ;
- une mémoire PNJ compressée par règles.

Un LLM local plus ambitieux peut devenir une option future, mais uniquement si :

- il tourne localement ;
- ses poids sont versionnés ;
- la température est contrôlée ;
- ses sorties sont validées ;
- le fallback template existe ;
- la conversation reste rejouable ou au moins résumée dans un ledger déterministe.

---

## 5. Cas 2 — Modèle pour quêtes procédurales déterministes

### 5.1 Oui, mais pas comme générateur principal

Le cœur des quêtes IsoWorld doit rester :

```text
Quest = Motivation + Contexte + Acteurs + Lieu + Obstacle + Choix + Conséquence + Récompense + Trace dans le monde
```

Donc le système principal doit rester un `QuestGraph` déterministe, basé sur :

- templates ;
- storylets ;
- facts ;
- factions ;
- lieux ;
- ressources ;
- contraintes ;
- validation de progression ;
- budgets narratifs ;
- compatibilité world rules.

Le ML est pertinent comme couche de scoring et de variation.

### 5.2 Rôles utiles du ML pour les quêtes

| Rôle ML | Pertinence | Autoritaire ? |
|---|---:|---:|
| Classer les meilleurs storylets candidats | Forte | Non |
| Prédire si une quête semble cohérente | Forte | Non |
| Détecter répétition ou monotonie | Forte | Non |
| Générer un résumé humain lisible | Forte | Non |
| Proposer des variantes de texte | Forte | Non |
| Évaluer la tension / difficulté probable | Moyenne à forte | Non |
| Générer librement une quête complète | Faible en runtime | Non |
| Générer offline des templates candidats | Forte | Après revue / validation |

### 5.3 Pipeline recommandé

```text
QuestCandidateGenerator déterministe
  -> produit 50-200 candidats depuis templates/storylets/planner
  -> QuestFeatureExtractor
  -> QuestCoherenceModel score
  -> QuestNoveltyModel score
  -> QuestPacingModel score
  -> RuleValidator
  -> sélection déterministe avec StableRNG pondéré
  -> QuestGraph commit
```

Important : le modèle ne choisit pas directement. Il donne des scores. La sélection finale se fait avec un algorithme déterministe versionné.

### 5.4 Exemple

```text
Seed: 918273
World tags: ecological_collapse, sacred_animals, no_direct_combat
Player state: discovered_river_drought, trusted_by_village

Système déterministe propose :
- réparer une pompe antique
- négocier avec une guilde d’irrigation
- suivre un animal migrateur
- cartographier les sources cachées
- voler un cristal d’eau

ML score :
- cohérence monde
- nouveauté vs quêtes déjà vues
- lisibilité
- tension non-combat
- coût de déplacement

Validator retire :
- voler un cristal d’eau si contraire au toneProfile actuel

Sélection finale :
- suivre un animal migrateur -> révèle sources cachées -> choix moral sur accès public ou rituel sacré
```

---

## 6. Cas 3 — Modèles pour faction, économie et sociétés

### 6.1 Pertinent en simulation agrégée

Les factions et settlements ne doivent pas simuler chaque habitant. Le ML peut aider à prédire ou scorer des états agrégés.

Exemples :

```text
FactionState + SettlementState + RecentLedgerEvents
  -> FactionReactionScorer
  -> candidate reactions
  -> deterministic faction rules
  -> world event / rumor / price shift
```

### 6.2 Ce que le ML peut apporter

- prédire quelles réactions semblent cohérentes ;
- scorer la probabilité d’un conflit ;
- détecter si deux cultures générées se ressemblent trop ;
- générer des noms / proverbes / rumeurs offline ;
- classer les rumeurs selon leur pertinence locale ;
- condenser l’histoire d’une faction en résumé lisible ;
- aider les outils à visualiser “pourquoi” une faction agit.

### 6.3 Ce qui doit rester déterministe

- frontières de territoire ;
- relations numériques ;
- ressources ;
- contrôle des lieux ;
- conséquences réelles ;
- déclenchement des guerres / paix ;
- migration ;
- prix ;
- évolution du ledger.

---

## 7. Audit complet des systèmes IsoWorld pouvant bénéficier d’AI/ML

### 7.1 Très haute pertinence

| Système | Usage ML recommandé | Type |
|---|---|---|
| PNJ / dialogue | intention, style, résumé mémoire, cohérence lore | runtime borné + offline |
| QuestGraph / Storylets | scoring, cohérence, variation, anti-répétition | runtime scoring + outils |
| Seed Lab | détection de seeds faibles, anomalies, monotonie | offline / tools |
| RPG World DNA Browser | explication, résumé, comparaison de mondes | tools |
| Factions / rumeurs | scoring de réactions, résumé, rumeurs contextualisées | runtime léger + tools |
| Tools Hub | assistant d’authoring, génération de variantes, validation | offline/tools |
| Animation | blend prediction, contacts, locomotion assistée | runtime compact |
| Rendering | neural materials, denoising, upscaling, compression | runtime GPU |

### 7.2 Pertinence moyenne

| Système | Usage ML recommandé | Attention |
|---|---|---|
| Terrain / biomes | classification esthétique, validation de lisibilité | ne pas remplacer le générateur déterministe |
| Props | scoring placement, variantes, densité visuelle | garder les règles et IDs stables |
| Settlements | scoring layouts, lisibilité de ville, diagnostic | la géométrie reste procédurale/règles |
| Audio | sélection de couches, mastering adaptatif, classification surface | coûts runtime à mesurer |
| UI/HUD | adaptation layout, résumé de quest log | accessibilité et déterminisme |
| Save System | compression sémantique, diagnostic migration | jamais de save opaque générée par modèle |

### 7.3 Faible pertinence en V2

| Système | Pourquoi |
|---|---|
| Physique autoritaire | doit rester stable, testable, déterministe |
| Collision | doit rester exacte et prévisible |
| Chunk streaming | la logique doit rester explicite |
| Sauvegarde de base | doit rester Codable/SQLite/ledger clair |
| Gameplay combat core | peut utiliser ML pour animation, mais pas pour règles de dégâts V2 |

---

## 8. Pipeline d’entraînement recommandé

### 8.1 Vue globale

```text
IsoWorld Tools Hub
  -> DatasetBuilder
  -> export JSONL / Parquet / SQLite views
  -> PyTorch training on Mac via MPS or external trainer
  -> evaluation harness
  -> export Core ML package
  -> metal-package-builder
  -> MTLPackage
  -> ModelRegistry
  -> runtime inference bridge
```

### 8.2 Sources de données internes

Créer des datasets à partir de :

- seeds générées ;
- WorldRPGDNA ;
- WorldRuleset ;
- QuestGraph ;
- Storylets ;
- FactionState ;
- SettlementState ;
- PlayerActionLedger ;
- WorldStateLedger ;
- validations de designers ;
- captures de playtests ;
- évaluations automatiques de Seed Lab ;
- rapports de cohérence ;
- textes authorés manuellement.

### 8.3 Dataset type pour les quêtes

```json
{
  "world_tags": ["ecological_collapse", "no_direct_combat"],
  "quest_template": "restore_biome_balance",
  "actors": ["river_village", "irrigation_guild"],
  "locations": ["dry_river", "old_pump"],
  "constraints": ["no_kill", "knowledge_progression"],
  "candidate_steps": ["discover_symptom", "find_source", "negotiate_access"],
  "designer_score_coherence": 0.91,
  "designer_score_novelty": 0.76,
  "auto_validation_passed": true
}
```

### 8.4 Dataset type pour PNJ

```json
{
  "npc_archetype": "elder_cartographer",
  "faction": "mountain_archive",
  "culture_tags": ["astronomy", "taboo_false_maps"],
  "relationship": "trusted",
  "known_facts": ["moving_forest_exists", "north_star_shifted"],
  "player_question_intent": "ask_about_route",
  "allowed_response_intents": ["warn", "teach", "refuse_detail"],
  "target_intent": "warn",
  "target_tone": "calm_mysterious",
  "sample_response": "La forêt ne bouge pas au hasard. Elle suit les erreurs des cartes."
}
```

---

## 9. Runtime inference : règles d’intégration

### 9.1 Budgets stricts

Chaque modèle doit déclarer :

```swift
struct InferenceBudget: Codable, Hashable {
    let maxLatencyMS: Float
    let maxMemoryMB: Float
    let maxCallsPerSecond: Float
    let allowedThread: InferenceThreadClass
    let allowedDuringFrame: Bool
    let fallbackRequired: Bool
}
```

Classes recommandées :

```text
FrameCritical       <= 1 ms, très petit modèle, idéalement GPU timeline
InteractiveShort    <= 16-50 ms, dialogue/UI, async possible
BackgroundTooling   > 50 ms, outils, debug, offline
BatchOffline        secondes/minutes, entraînement/évaluation
```

### 9.2 Fallback obligatoire

Tout modèle runtime doit avoir un fallback déterministe :

```text
ML disponible -> proposition enrichie
ML indisponible -> templates + règles + stable RNG
```

Le jeu doit rester jouable sans modèle.

### 9.3 Versioning

Chaque modèle doit être versionné :

```swift
struct ModelMetadata: Codable, Hashable {
    let modelID: String
    let semanticVersion: String
    let trainingDatasetHash: String
    let featureSchemaHash: String
    let outputSchemaHash: String
    let targetHardwareClass: HardwareClass
    let deterministicSelectionPolicyVersion: String
}
```

Le save doit stocker :

- la version du modèle utilisée pour les décisions importantes ;
- le hash des propositions acceptées si nécessaire ;
- les décisions finales, pas seulement le prompt ou le contexte.

---

## 10. Déterminisme et ML

### 10.1 Problème

Le ML peut être non déterministe à cause de :

- sampling ;
- différences de précision ;
- versions de modèles ;
- scheduling GPU ;
- formats de quantization ;
- OS / driver / hardware ;
- changements de tokenization ;
- appels async arrivant dans un ordre différent.

### 10.2 Solution IsoWorld

Séparer deux types de sorties :

```text
Authoritative Output
  -> doit être déterministe, validé, sérialisé.

Cosmetic / Expressive Output
  -> peut varier légèrement, mais ne modifie pas le monde.
```

Exemples :

| Sortie | Type | Règle |
|---|---|---|
| choix d’une quête active | authoritaire | finaliser par règle déterministe |
| texte exact d’une phrase PNJ | semi-cosmétique | sauvegarder si important |
| score de cohérence | non autoritaire | peut être recalculé |
| réaction de faction | authoritaire | valider + ledger |
| rumeur locale | semi-authoritaire | ID stable + texte sauvegardé ou template sauvegardé |
| résumé UI | cosmétique | peut être régénéré |

### 10.3 Pattern recommandé

```text
AIProposal is never truth.
LedgerEvent is truth.
```

---

## 11. Outils moteur à ajouter

### 11.1 ML Authoring Lab

Un nouvel outil dans le Tools Hub :

```text
Tools Hub
  -> RPG
    -> World DNA Browser
    -> Quest Graph Viewer
    -> Storylet Debugger
    -> Faction Simulator
    -> Director Timeline
    -> ML Authoring Lab
```

Fonctions :

- inspecter les datasets ;
- générer des exemples d’entraînement ;
- comparer deux modèles ;
- rejouer une seed avec / sans ML ;
- visualiser les propositions rejetées ;
- afficher les raisons de validation ;
- mesurer latence/mémoire ;
- exporter un diagnostic bundle ;
- créer des golden tests.

### 11.2 Quest Coherence Lab

- charge une seed ;
- génère un QuestGraph ;
- affiche les candidats ;
- montre les scores modèle ;
- montre les règles de rejet ;
- compare avec sélection sans ML ;
- exporte un rapport.

### 11.3 NPC Conversation Lab

- choisit un PNJ ;
- injecte un état monde ;
- affiche les facts connus/interdits ;
- demande une conversation ;
- affiche chaque proposition ;
- marque les hallucinations ;
- enregistre les bons exemples dans le dataset.

### 11.4 Seed AI Audit

Pour chaque seed de test :

```text
Seed -> WorldRPGDNA -> QuestGraph -> Factions -> Settlements -> Director Events
  -> ML audit
  -> report:
      coherence_score
      repetition_score
      dead_end_risk
      monotony_risk
      lore_conflict_risk
      budget_risk
```

---

## 12. Modèles proposés par priorité

### 12.1 Modèle A — QuestCoherenceScorer

**Priorité : très haute.**

But : scorer un candidat de quête.

Entrée :

- tags monde ;
- type de quête ;
- acteurs ;
- lieux ;
- contraintes ;
- étapes ;
- état joueur ;
- quêtes déjà actives.

Sortie :

```swift
struct QuestScoreOutput: Codable, Hashable {
    let coherence: Float
    let novelty: Float
    let pacingFit: Float
    let worldFit: Float
    let riskDeadEnd: Float
    let explanationCode: QuestScoreReason
}
```

Usage : runtime async ou tools.

### 12.2 Modèle B — NPCIntentModel

**Priorité : haute.**

But : choisir ou scorer l’intention d’un PNJ dans une situation.

Sortie :

- warn ;
- help ;
- refuse ;
- lie ;
- redirect ;
- ask_payment ;
- reveal_rumor ;
- offer_trade ;
- escalate_conflict ;
- calm_down.

Le texte final peut rester template au départ.

### 12.3 Modèle C — DialogueStyleRewriter

**Priorité : moyenne.**

But : transformer une phrase canonique en variante stylée.

Exemple :

```text
Canonical: "The river is dangerous after sunset."
Culture/tone: mountain_archive, calm_mysterious
Output: "Après le coucher, la rivière ne suit plus son lit. Évite-la."
```

Usage conseillé : d’abord offline / tools, puis runtime si les performances sont bonnes.

### 12.4 Modèle D — FactionReactionScorer

**Priorité : moyenne à haute.**

But : scorer la réaction probable d’une faction à un événement ledger.

Le système déterministe décide ensuite.

### 12.5 Modèle E — SeedQualityAuditor

**Priorité : très haute côté outils.**

But : détecter les seeds RPG peu intéressantes, incohérentes ou cassées.

Sorties :

- score diversité ;
- score lisibilité ;
- score risque dead-end ;
- score répétition ;
- score pacing ;
- score cohérence biome/RPG ;
- suggestions de debug.

### 12.6 Modèle F — NarrativePlaceClassifier

**Priorité : moyenne.**

But : identifier quels lieux générés peuvent porter une valeur narrative.

Entrée : terrain, biome, props, accès, ressources, proximité faction, visibilité.

Sortie :

- shrine_candidate ;
- ambush_site ;
- trade_crossroad ;
- hermit_place ;
- ruin_memory_site ;
- ritual_site ;
- quest_anchor.

### 12.7 Modèle G — Runtime Embedding / Similarity

**Priorité : moyenne.**

But : comparer facts, rumeurs, quêtes, dialogues, cultures.

Usage :

- éviter répétitions ;
- retrouver les facts pertinents ;
- résumer mémoire PNJ ;
- classer les rumeurs.

Attention : stocker les IDs et décisions, pas seulement les embeddings.

---

## 13. Ce qu’il ne faut pas faire

### 13.1 Ne pas mettre un LLM au centre du moteur

À éviter :

```text
Player asks NPC
  -> LLM receives entire world
  -> LLM invents answer, quest, item, consequence
  -> world accepts
```

C’est incompatible avec l’objectif IsoWorld : génération procédurale déterministe, validation, sauvegarde robuste, replay de seeds, debug outils.

### 13.2 Ne pas entraîner pendant une partie normale

À éviter :

```text
Gameplay runtime -> fine-tune model live -> save model diff
```

Problèmes :

- coût énorme ;
- non déterminisme ;
- save fragile ;
- impossible à reproduire ;
- bugs difficiles ;
- poids utilisateur à migrer.

À la place :

```text
Gameplay -> log opt-in / local dataset
Tools -> train/evaluate offline
Runtime futur -> modèle versionné
```

### 13.3 Ne pas remplacer les validators

Un modèle peut dire “cette quête semble valide”.

Mais le moteur doit vérifier :

- lieux atteignables ;
- objets existants ;
- factions compatibles ;
- récompenses valides ;
- absence de contradiction ;
- progression possible ;
- budgets respectés ;
- sauvegarde possible.

---

## 14. Intégration Metal 4 concrète

### 14.1 Pipeline Core ML / Metal Package

Pour les modèles destinés au runtime Metal :

```text
PyTorch / TensorFlow authoring
  -> Core ML conversion
  -> Core ML package
  -> metal-package-builder
  -> MTLPackage
  -> MTLLibrary
  -> MTL4MachineLearningPipelineState
  -> MTL4MachineLearningCommandEncoder
  -> MTLTensor inputs / outputs
```

Ce pipeline est surtout adapté aux modèles compacts et bien typés : scoring, classification, petits réseaux, neural rendering, compression, animation.

### 14.2 Quand utiliser `MTL4MachineLearningCommandEncoder`

À utiliser si :

- le modèle doit être synchronisé avec le GPU timeline ;
- les entrées/sorties sont déjà GPU ;
- le modèle travaille sur des tensors d’image, géométrie, animation ou rendering ;
- la latence doit être intégrée au frame graph ;
- on veut éviter des allers-retours CPU/GPU.

Exemples IsoWorld :

- neural material compression ;
- denoising / occlusion / lighting assist ;
- animation contact scorer ;
- terrain visual classifier ;
- prop density post-process ;
- mini scoring de crowd/settlement si data GPU.

### 14.3 Quand ne pas l’utiliser

Ne pas utiliser Metal 4 ML encoder pour :

- gros dialogue génératif ;
- planification de quêtes complexe ;
- outils d’authoring lourds ;
- batch training ;
- génération de textes longs ;
- analyse de milliers de seeds offline.

Ces tâches sont mieux dans :

- PyTorch/MPS ;
- Core ML hors frame critical ;
- outils Swift async ;
- scripts Python ;
- pipeline offline.

---

## 15. Contraintes MacBook Pro M1

IsoWorld cible actuellement un moteur Swift/Metal sur MacBook Pro M1. Il faut donc être très prudent.

Règles :

- commencer avec petits modèles ;
- mesurer avant d’élargir ;
- préférer scoring/classification à génération longue ;
- limiter la taille des tensors ;
- exécuter hors frame critical quand possible ;
- ajouter un toggle global “AI/ML runtime off” ;
- conserver fallback déterministe ;
- profiler dans Instruments / Metal debugger ;
- ne jamais dépendre d’un modèle pour ouvrir un world réel.

Budgets initiaux conseillés :

| Classe | Budget cible M1 |
|---|---:|
| NPC intent | < 5 ms async |
| Quest scoring batch | < 50 ms async pour 50 candidats |
| Seed audit tools | libre, non runtime |
| Dialogue rewrite | offline d’abord |
| GPU frame ML | < 1-2 ms si activé |
| LLM local | non recommandé en V2 runtime |

---

## 16. Sauvegarde et compatibilité

Le save system doit considérer les modèles comme des dépendances versionnées.

À sauvegarder :

```swift
struct AIMLDecisionRecord: Codable, Hashable {
    let decisionID: StableID
    let modelID: String
    let modelVersion: String
    let featureSchemaHash: String
    let inputSummaryHash: String
    let outputHash: String
    let acceptedByValidator: Bool
    let committedLedgerEventID: LedgerEventID?
}
```

À ne pas faire :

- sauvegarder seulement un prompt ;
- compter sur le modèle pour régénérer exactement la même réponse ;
- rendre une quête dépendante d’un modèle absent ;
- casser une save si un modèle est mis à jour.

Migration :

```text
Si modèle absent ou version différente :
  - garder les décisions déjà commit dans le ledger
  - utiliser fallback pour futures décisions
  - marquer le monde comme AIModelCompatibility.degraded si nécessaire
```

---

## 17. Roadmap proposée

### Phase 1 — Documentation et contrats

- créer `AIModelCore` ;
- définir `ModelRegistry` ;
- définir `InferenceRequest` / `InferenceResult` ;
- définir `AIProposal` ;
- définir `OutputValidator` ;
- définir `AIMLDecisionRecord` ;
- ajouter un onglet `ML Authoring Lab` dans les outils.

### Phase 2 — Dataset sans modèle

- exporter seeds RPG ;
- exporter QuestGraph candidates ;
- exporter dialogues templates ;
- exporter faction reactions ;
- exporter reports Seed Lab ;
- créer JSONL de training ;
- créer golden datasets.

### Phase 3 — Premier modèle utile : QuestCoherenceScorer

- modèle simple ;
- entraînement via PyTorch/MPS ;
- évaluation offline ;
- intégration tools ;
- comparaison modèle vs règles ;
- aucun impact runtime au début.

### Phase 4 — NPCIntentModel

- classification d’intention ;
- contexte compact ;
- sorties typées ;
- validation facts ;
- fallback template ;
- conversation lab.

### Phase 5 — Runtime opt-in

- activer scoring quêtes en async ;
- activer intent PNJ ;
- sauvegarder décisions ;
- profiler ;
- comparer avec seeds golden ;
- ajouter option désactivation complète.

### Phase 6 — Metal 4 runtime GPU

- convertir un petit modèle en Core ML package ;
- packager en MTLPackage ;
- intégrer un `MetalMLInferencePass` ;
- tester `MTLTensor` inputs/outputs ;
- mesurer M1 ;
- garder fallback CPU/règles.

---

## 18. Position finale

L’intégration AI/ML est pertinente pour IsoWorld, surtout parce que le RPG procédural profond aura besoin de :

- cohérence narrative ;
- variations riches ;
- dialogue plus vivant ;
- validation de seeds ;
- détection de répétition ;
- outils d’authoring puissants ;
- diagnostics automatiques ;
- scoring de quêtes et storylets ;
- meilleure lisibilité des mondes générés.

Mais IsoWorld ne doit pas devenir un moteur “LLM-first”.

La ligne directrice doit rester :

```text
Rules generate truth.
ML proposes meaning.
Validators protect coherence.
Ledger records reality.
```

Donc :

- **oui** à des modèles spécifiques ;
- **oui** à PyTorch/MPS pour entraîner sur Mac ;
- **oui** à Core ML / Metal 4 pour runtime inference ciblée ;
- **oui** à Shader ML pour micro-réseaux graphics/animation ;
- **non** au modèle libre qui modifie l’état du monde ;
- **non** au fine-tuning pendant une partie ;
- **non** à une dépendance obligatoire au ML pour jouer ;
- **non** à des décisions non rejouables non sauvegardées.

Cette approche garde l’ADN IsoWorld : procédural, déterministe, testable, mais ouvre la porte à une couche moderne d’intelligence assistée.

---

## 19. Sources techniques consultées

- Apple Developer — Metal overview : https://developer.apple.com/metal/
- Apple Developer — Combine Metal 4 machine learning and graphics, WWDC25 : https://developer.apple.com/videos/play/wwdc2025/262/
- Apple Developer — Accelerated PyTorch training on Mac : https://developer.apple.com/metal/pytorch/
- Apple Developer — Metal Performance Shaders Graph : https://developer.apple.com/documentation/metalperformanceshadersgraph

---

## 20. Fichiers IsoWorld reliés

Ce document complète, sans les remplacer :

- `procedural-deterministic-rpg-system.md`
- `procedural-app-flow-shell-tools-system.md`
- `procedural-save-system.md`
- `procedural-parametric-character-system.md`
- `procedural-physics-driven-animation-system.md`
- `procedural-modern-rendering.md`
- `modern-texture-lighting-pipeline.md`
- `V2_ENGINE_IMPLEMENTATION_PLAN.md`
- `V2_ENGINE_PROGRESS_TRACKER.md`
