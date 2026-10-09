# Bunker Z — Feuille de route pour se rapprocher du jeu original

Liste complète de ce qui sépare Bunker Z d'un mode Zombies de CoD, classée par domaine, avec l'état actuel,
la difficulté estimée et des pistes d'implémentation. Les noms, cartes et assets protégés du jeu original
restent à éviter : on reproduit les **mécaniques et l'ambiance**, avec du contenu original.

Légende — État : ✅ fait · 🟡 partiel · ❌ absent. Effort : S (≤ 1 h) · M (≈ 1 journée) · L (plusieurs jours) · XL (chantier majeur).

---

## 1. Déjà en place (bilan au 8 octobre 2026)

**Cœur du mode Zombies** : manches (PV et nombre croissants, marcheurs → coureurs → sprinteurs) · barricades à 6 planches
(réparation = points) · points (touche, kill, tête, couteau) · portes payantes · armes murales + rachat de munitions ·
boîte mystère qui déménage · courant · machine d'amélioration avec effet spécial par arme · 2 pièges ·
**10 atouts** (6 cumulables avec Triple Étui) · **10 power-ups** (Munitions max, Mort instantanée, Bombe, Points x2, Feu de vente,
Bonus de points, Sang de zombie, Munitions illimitées, Dernier survivant, Charpentier) · grenades · singe-leurre.

**Ennemis** : zombies (5 tenues, soldats, ouvriers, femmes) · chiens infernaux · tank · boss Colosse (manches 10/20/30) ·
kamikaze, cracheur, hurleur, brute (bouclier + charge), infecté (infection + nuage toxique) · démembrement + rampants ·
cadavres physiques (ragdoll).

**Contenu** : 13 armes à modèles réalistes et tirs dédiés · 2 cartes (Bunker abandonné, Laboratoire Sigma) avec sélection ·
téléporteur · quête secrète (3 fioles → synthèse du sérum) · bras du joueur animés (prise en main, pompe/verrou, lancers).

**Confort** : menus 3D · HUD à la craie · manette + remappage clavier/manette · tableau des scores · records ·
options audio/image · indicateurs de dégâts directionnels · musiques réelles · tests automatisés (~230 vérifications).

---

## 1 bis. Comparaison avec le mode Zombies original (ce qui manque encore)

**Écarts les plus visibles en jeu, par priorité :**
1. **Coop** (2.1/2.3) — c'est LE point fort de l'original (en ligne 2-4 joueurs, réanimation). Chantier XL, non testable seul.
2. **Mouvement** : sauter par-dessus les fenêtres (2.9), glisser/plonger (2.10), zombies qui grimpent (4.6).
3. **Armes** : deuxième niveau d'amélioration (3.1.4), accessoires (3.1.3), autres armes « miracle » (3.1.9), lance-roquettes, animations de rechargement par arme (3.1.2).
4. **Atouts** : ajouter double gain de points, gilet, recharge rapide, tir en rafale… (3.2) — rapide à faire.
5. **Équipements** : mines, Molotov, tourelle, bouclier d'émeute (3.3).
6. **Ambiance** : météo/orage (5.9), objets d'histoire (radios, ordinateurs, 5.7), musique secrète (5.6), annonceur vocal (7.2, désactivé), voix des personnages (7.3).
7. **Rendu** : Forward+ (6.1), décors PBR (6.2), sang sur la caméra (6.4).
8. **Structure du jeu** : difficulté (2.13), succès et statistiques à vie (8.5/8.6), sauvegarde (9.8), localisation (8.9).

**Ce qui est à parité ou proche de l'original :** boucle de manches, économie de points, boîte mystère, courant, atouts, power-ups,
amélioration d'armes, pièges, chiens, boss, quête secrète, variété de zombies spéciaux, démembrement.

**Jamais testé à la main :** équilibrage (économie, courbe des manches, DPS des nouvelles armes), sensations de tir, sons.

---

## 2. Gameplay principal

| # | Fonctionnalité | État | Effort | Notes d'implémentation |
|---|---|---|---|---|
| 2.1 | **Coop 2–4 joueurs en ligne** | 🟡 lobby, avatars, zombies et manches partagés (hôte autoritaire) ; reste : économie par joueur, portes/barricades/boîte/machines partagées, power-ups, réanimation, fin de partie commune | XL | `MultiplayerAPI` + ENet. Serveur autoritaire pour zombies/points. Réplication via `MultiplayerSynchronizer`. Points et atouts par joueur. |
| 2.2 | **Coop locale (écran partagé)** | ❌ | L | 2 `SubViewport` + 2 joueurs ; manettes requises (voir 7.3). |
| 2.3 | **Réanimation des coéquipiers** (maintenir F, 3 s ; jauge de saignement 30 s) | 🟡 | M | Aujourd'hui seul Second Souffle (auto) et la vie supplémentaire existent. Ajouter état « à terre » avec timer, ramper, pistolet seul. |
| 2.4 | **Mode à terre en solo** : perdre tous les atouts, tirer au pistolet pendant 3 s avant de mourir | ✅ | S | À terre 5 s : ramper et tirer au pistolet (Second Souffle : 3 s puis réanimation). Reste : réanimation par un coéquipier (coop). |
| 2.5 | **Vraies manches « spéciales »** : chiens, mais aussi manches de zombies qui sprintent, d'infectés explosifs, de boss | 🟡 chiens (manches 5-7), boss (tous les 10), tanks (tous les 5) ; pas de manches thématiques | M | `round_manager.gd` : table de manches spéciales au lieu d'un seul tirage. |
| 2.6 | **Plafond de zombies par joueur et par manche** réaliste (ex. 24 simultanés, 6+0,15·manche²…) | 🟡 | S | Ajuster `zombie_count()` et pondérer par nombre de joueurs. |
| 2.7 | **Vitesse des zombies par manche** (marcheurs → coureurs → sprinteurs à partir de la manche ~8) avec transition progressive | ✅ | S | Modèle d'animation « course » dédié (voir 4.5). |
| 2.8 | **Système de « kiting » / exploitation de l'IA** : zombies qui se bloquent, trains de zombies | ❌ | M | Navigation avec `NavigationAgent3D` avoidance activée + file d'attente aux fenêtres. |
| 2.9 | **Sauter par-dessus les fenêtres** pour le joueur (quand elle est dégagée, touche Saut) | ✅ | M | Zone interactive à la fenêtre, animation de saut, collision temporaire. |
| 2.10 | **Glisser / plonger** (slide, dive-to-prone) | ✅ glissade (accroupi en sprint) et plongeon (accroupi en l'air en sprint, atterrissage à plat ventre) | M | Pré-requis des atouts de plongeon (3.3). |
| 2.11 | **Arme de poing secondaire dédiée + couteau amélioré** (bowie, machette) | 🟡 | S | Le couteau est unique. Ajouter variantes achetables. |
| 2.12 | **Chargement de la partie, sauvegarde du meilleur score par carte** | 🟡 records globaux faits (pas encore par carte) | S | `ConfigFile` dans `user://`. |
| 2.13 | **Mode de difficulté** (Facile / Normal / Réaliste) : vitesse, dégâts reçus, régénération | ✅ | S | `GameManager.DIFFICULTIES`, réglage dans Options > Jeu. À équilibrer à la main. |

---

## 3. Armes, atouts et équipements

### 3.1 Armes
| # | Fonctionnalité | État | Effort |
|---|---|---|---|
| 3.1.1 | **Plus d'armes** (20+ : pistolets, SMG, fusils d'assaut, fusils à pompe, snipers, mitrailleuses, lance-roquettes) | 🟡 13 armes (5 de plus : revolver, Double Canon, Frelon, Spectre, Éclaireur) | M par lot de 5 |
| 3.1.2 | **Vrais modèles d'armes réalistes** + animations de rechargement/tir (au lieu des modèles « jouet » Kenney) | 🟡 modèles Quaternius (low-poly réalistes) sur 12 armes ; pas de nouvelles animations de rechargement par arme | L |
| 3.1.3 | **Accessoires** (viseurs, silencieux, poignées) | ❌ | M |
| 3.1.4 | **Deuxième niveau d'amélioration** (niveau II doré, 8000 points, dégâts x4) | ✅ | M |
| 3.1.5 | **Pénétration de balles** (traverser plusieurs zombies) | ❌ | S |
| 3.1.6 | **Munitions limitées par type** et ramassage au sol | ❌ | S |
| 3.1.7 | **Mode de tir** (auto/semi/rafale) commutable | ❌ | S |
| 3.1.8 | **Animations de visée réalistes** (zoom de lunette avec rendu séparé) | 🟡 | M |
| 3.1.9 | **Wonder Weapons uniques**, à construire à partir de pièces cachées | 🟡 Arc Tonnerre (3 pièces + établi, Bunker) ; manque le Laboratoire et d autres armes | L |

### 3.2 Atouts
✅ Fait (12) : Cuirasse, Main Leste, Tonique Éclair, Second Souffle, Triple Étui, Œil de Lynx, Pied Léger, Mains d'Or (points +50 %), Bouclier, Ravitailleur, Gilet Lourd, Course Folle. Restent à ajouter : **sprint illimité**, **visée automatique tête**,
**explosions amies sans dégâts + explosion à l'atterrissage**, **rechargement rapide**, **recharge de grenades**,
**vision des zombies à travers les murs**, **Mule Kick** (3ᵉ arme — équivalent de Triple Étui, déjà présent).
Effort : S par atout. Ajouter l'**icône HUD réaliste** et un **jingle propre à chaque atout**.

### 3.3 Équipements
| Équipement | État | Effort |
|---|---|---|
| Grenades à fragmentation | ✅ | — |
| Singe-leurre | ✅ | — |
| Mines bondissantes | ❌ | S |
| Cocktail Molotov | ❌ | S |
| Grenades fumigènes / étourdissantes | ❌ | S |
| Tourelle posable | ❌ | M |
| Bouclier d'émeute (construit à partir de pièces) | ❌ | M |

### 3.4 Power-ups
✅ Fait (10) : Munitions max, Mort instantanée, Bombe, Points x2, Feu de vente, Bonus de points, Sang de zombie, Munitions illimitées, Dernier survivant (en solo : une vie supplémentaire ; en coop il réanimera tous les joueurs), Charpentier.

---

## 4. Ennemis

| # | Fonctionnalité | État | Effort | Détail |
|---|---|---|---|---|
| 4.1 | **Plusieurs modèles de zombies** (hommes, femmes, soldats, scientifiques, ouvriers) | 🟡 1 corps de base, 5 tenues, silhouettes variées, soldats, ouvriers et femmes (équipement et cheveux ajoutés ; pas de vrai maillage féminin) | M | Aujourd'hui tous partagent le t-shirt « PIXELHOUSE ». Recolorer/retexturer ou ajouter 3–4 modèles. |
| 4.2 | **Zombies sortant du sol** | ❌ | M | Spawn avec animation et particules de terre. |
| 4.3 | **Zombies explosifs** (exploser au contact) | ✅ Kamikaze | S | Variante de `zombie.gd`. |
| 4.4 | **Zombies spéciaux** (cracheur, hurleur, brute, infecté) | ✅ kamikaze, cracheur, hurleur, brute (bouclier + charge) et infecté (infection + nuage toxique) | M par type | Attaques à distance, aura, grand PV. |
| 4.5 | **Animation de course** dédiée et animation de reptation | ✅ procédurales (à remplacer par de vraies animations si disponibles) | M | Retargeting d'animations Mixamo (licence à vérifier) ou Quaternius. |
| 4.6 | **Zombies qui grimpent aux murs / échelles** | ❌ | L | Points de navigation spéciaux. |
| 4.7 | **Boss supplémentaires** (un par 10 manches, avec phases) | 🟡 1 boss | M par boss | Réutiliser le patron du Colosse. |
| 4.8 | **Dégâts localisés** : tête, torse, membres avec multiplicateurs ; casques/gilets brisables | 🟡 | M | Étendre `on_limb_hit()`. |
| 4.9 | **Cadavres persistants** (ragdoll physique) | ✅ 10 corps rigides + articulations (pas persistants : disparaissent après 5 s) | M | `PhysicalBoneSimulator3D` sur le squelette. |
| 4.10 | **Vrais chiens infernaux** avec modèle dédié et attaque d'éclair | 🟡 | M | Aujourd'hui un loup low-poly. |

---

## 5. Cartes et niveau

| # | Fonctionnalité | État | Effort |
|---|---|---|---|
| 5.1 | **Plusieurs cartes** + écran de sélection | ✅ Bunker abandonné et Laboratoire Sigma (sélection au clic sur Jouer) | L par carte |
| 5.2 | **Carte plus grande** : extérieur jouable, étages, escaliers, toits | ❌ | L |
| 5.3 | **Zones à débloquer en cascade** avec spawns dynamiques par zone | 🟡 | M |
| 5.4 | **Téléporteur** relié au courant, avec cooldown | ✅ laboratoire : accueil ↔ réacteur, 750 points, recharge 25 s | M |
| 5.5 | **Easter egg principal** (quête à étapes avec indices, récompense, fin de partie) | 🟡 laboratoire : 3 fioles cachées + indices + synthèse ; récompense (vie, munitions, points), pas de fin de partie | L |
| 5.6 | **Musique secrète** (3 objets à activer) | ❌ | S |
| 5.7 | **Objets interactifs d'ambiance** (radios, téléphones, ordinateurs qui racontent l'histoire) | ✅ 4 radios/ordinateurs dans le bunker, 1 dans le labo (histoire de l'Abri 7) | M |
| 5.8 | **Éléments dynamiques** : portes à vérin, ascenseurs, ponts, trappes | ❌ | M |
| 5.9 | **Météo** : pluie, orage avec éclairs, brouillard variable | 🟡 pluie à ciel ouvert, éclairs et tonnerre (option) ; pas de brouillard variable | M |
| 5.10 | **Cycle jour/nuit** ou changement d'ambiance par manche | ❌ | S |
| 5.11 | **Baking de lumière / occlusion** pour une meilleure performance | ❌ | M |
| 5.12 | **Level design à la main avec modules** (kit de murs/pièces) au lieu d'un code procédural | ❌ | L |

---

## 6. Esthétique et rendu

| # | Fonctionnalité | État | Effort |
|---|---|---|---|
| 6.1 | **Passer en Forward+** (SDFGI, SSAO, SSR, volumetric fog) | ❌ | M — nécessite un GPU compatible ; le projet est en Compatibility. |
| 6.2 | **Modèles et textures réalistes** pour le décor (props PBR haute qualité) | 🟡 | L |
| 6.3 | **Décals de sang et d'impact** (vrais `Decal` projetés sur les murs) | 🟡 | S |
| 6.4 | **Sang sur la caméra** quand on est blessé ou qu'on tue de près | ❌ | S |
| 6.5 | **Bras du joueur** dans la vue (FPS arms) avec animations | ✅ bras + IK, rechargement, prise en main, pompe/verrou, lancer de grenade et de singe | L |
| 6.6 | **Animation de la caméra** : balancement, sprint, atterrissage, mort | 🟡 | S |
| 6.7 | **Effets d'atouts à la boisson** (animation de bouteille) | ✅ flacon coloré qui monte à la bouche | M |
| 6.8 | **Étourdissement / flou de mouvement** après une explosion | ❌ | S |
| 6.9 | **Réglages graphiques** (qualité des ombres, résolution, VSync, FPS max) | ✅ ombres, VSync, FPS max, MSAA, résolution, échelle de rendu | S |
| 6.10 | **Écran de chargement** et transitions | 🟡 | S |

---

## 7. Audio

| # | Fonctionnalité | État | Effort |
|---|---|---|---|
| 7.1 | **Musique de fond** réelle (ambiance, manche, mort) | ✅ | S |
| 7.2 | **Annonceur** qui parle (« Munitions max », « Mort instantanée »…) | 🟡 vraies voix anglaises Kenney (CC0) : manches 5/10 composées, power-ups, boss, chiens… ; pas de phrases françaises ni de réplique par arme | S |
| 7.3 | **Voix des personnages** (réactions, réanimation) | ❌ | M |
| 7.4 | **Son 3D spatialisé** avec réverbération par pièce (bus audio + `AudioEffectReverb`) | 🟡 | M |
| 7.5 | **Sons d'armes uniques** par arme (aujourd'hui partagés entre plusieurs) | ✅ tirs enregistrés dédiés (le Tonnerre réutilise celui du K-74 en plus grave) ; rechargements encore partagés | S |
| 7.6 | **Sons de pas variés** par matériau | 🟡 | S |
| 7.7 | **Mixage** : musique/effets/voix avec 3 curseurs dans les options | ✅ | S |
| 7.8 | **Ambiance sonore dynamique** : grésillement des lumières, gouttes, vent | ❌ | S |

---

## 8. Interface et confort

| # | Fonctionnalité | État | Effort |
|---|---|---|---|
| 8.1 | **Prise en charge manette** (axes, gâchettes, vibrations, remappage) | ✅ A/B valident et annulent dans les menus ; remappage disponible | M |
| 8.2 | **Remappage des touches** | ✅ | M |
| 8.3 | **Tableau des scores** (Tab) avec éliminations, tirs à la tête, réanimations, points | ✅ (réanimations à ajouter avec la coop) | S |
| 8.4 | **Écran de fin détaillé** (manches, portes ouvertes, achats, précision) | 🟡 | S |
| 8.5 | **Succès / défis** (ex. « manche 10 sans atout ») | ❌ | M |
| 8.6 | **Statistiques à vie** | ❌ | S |
| 8.7 | **Minimap / boussole** | ❌ | M |
| 8.8 | **Accessibilité** : taille du texte, daltonisme, sous-titres, arachnophobie/sang réduit | ❌ | S |
| 8.9 | **Localisation** (FR/EN) avec `TranslationServer` | ❌ | M |
| 8.10 | **Indicateurs de dégâts directionnels** | ✅ | S |
| 8.11 | **Pause automatique** à la perte de focus | ❌ | S |

---

## 9. Technique et qualité

| # | Sujet | Effort |
|---|---|---|
| 9.1 | **Optimisation** : `MultiMeshInstance3D` pour le décor, pool d'objets pour zombies et particules, LOD, occlusion culling | M |
| 9.2 | **Mesurer les performances** : 24 zombies à 60 FPS sur une machine modeste (profileur) | S |
| 9.3 | **Refactorer `game.gd`** : séparer carte, spawns, effets, menu en nœuds distincts | M |
| 9.4 | **Passer le contenu en ressources** (`.tres`) : armes, atouts, manches, power-ups — éditables dans l'inspecteur | M |
| 9.5 | **Construire la carte dans l'éditeur** (scènes `.tscn`) plutôt que par code | L |
| 9.6 | **Tests** : intégration CI (GitHub Actions + Godot headless), tests unitaires (GUT) | M |
| 9.7 | **Export** Windows/Linux/Web avec icône, métadonnées, installeur | S |
| 9.8 | **Sauvegarde/reprise** de partie | M |
| 9.9 | **Gestion du réseau** (si coop) : prédiction, interpolation, anti-triche basique | XL |
| 9.10 | **Journalisation et télémétrie anonyme** (opt-in) pour équilibrer les manches | S |

---

## 10. Équilibrage (à ajuster en jouant)

- **Économie :** valeurs de points des portes/armes/atouts à comparer avec la progression réelle d'une partie.
- **Courbe des manches :** PV des zombies aux manches 15+, temps de pause entre manches, apparition des coureurs.
- **Armes :** DPS par arme et par prix ; rapport entre amélioration (5000) et gain.
- **Pièges :** coût vs rentabilité (aucun point par kill) ; durée de recharge.
- **Boss :** PV, vitesse de charge, fréquence du coup au sol, réactivité du casque.
- **Singe-leurre :** durée (7 s), rayon d'explosion, nombre par boîte.
- **Régénération du joueur :** délai et vitesse selon la difficulté.

---

## 11. Plan d'attaque suggéré

1. **Court terme (≈ 1 semaine)** — impact immédiat sans gros chantier :
   musique réelle (7.1), annonceur (7.2), tableau des scores (8.3), 5 atouts de plus (3.2), power-ups (3.4),
   manette (8.1), options audio/graphiques (7.7, 6.9), meilleurs scores (2.12).
2. **Moyen terme (≈ 1 mois)** — le jeu se « sent » comme l'original :
   plus d'armes + modèles réalistes (3.1), animations de course/reptation (4.5), variété de zombies (4.1),
   zombies spéciaux (4.4), deuxième carte (5.1), téléporteur (5.4), easter egg (5.5), bras du joueur (6.5).
3. **Long terme** — le gros morceau :
   coop en ligne (2.1) avec réanimation (2.3), Forward+ et éclairage global (6.1), carte construite dans l'éditeur (5.12, 9.5).

---

## 12. Ressources gratuites utiles

| Besoin | Où chercher | Licences à privilégier |
|---|---|---|
| Armes, props, décors | Kenney, Quaternius, Poly Haven | CC0 |
| Textures PBR | ambientCG, Poly Haven | CC0 |
| Personnages animés | Mixamo (compte Adobe), Quaternius | à vérifier |
| Sons, voix, musiques | OpenGameArt, freesound.org, Kenney | CC0 / CC-BY |
| Polices | Google Fonts | OFL |

Toujours noter la licence et l'auteur dans `README.md` et dans le menu Crédits dès qu'un asset est ajouté.
