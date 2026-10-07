# Bunker Z

FPS de survie par manches inspiré des modes zombies : barricades, points, armes murales,
portes payantes, boîte mystère, atouts, courant, machine d'amélioration, power-ups,
manches de chiens et tanks. Godot 4.7, GDScript, rendu Compatibility.

## Mécaniques avancées
- **Pièges** (courant requis, 1000 points, actifs 25 s, recharge 45 s) : électrique dans le couloir, à feu près de la fenêtre ouest de la grande salle. Ils tuent tous les zombies dans la zone et blessent le joueur.
- **Améliorations spéciales** : chaque arme améliorée gagne un effet — P9 et Longue-Vue : balles explosives ; Vipère et Tonnerre : balles incendiaires ; Carabine et K-74 : arc électrique qui rebondit sur 3 zombies ; Brise-Porte : souffle qui repousse.
- **Démembrement** : les balles concentrées sur un avant-bras ou un mollet arrachent le membre (morceau projeté, sang) ; perdre une jambe ou subir une explosion non mortelle peut transformer le zombie en rampant (plus lent, plus bas).

- **Singe-leurre** (touche T) : obtenu par 3 dans la boîte mystère. Posé au sol, il joue des cymbales 7 s, attire tous les zombies (pas les chiens ni le boss) puis explose.
- **Le Colosse** (manches 10, 20, 30…) : boss blindé qui apparaît dans un éclair au milieu de la manche. Son casque absorbe 75 % des dégâts à la tête jusqu'à se briser. Il charge à travers la salle et frappe le sol (dégâts de zone + projection). Barre de vie en haut de l'écran, 500 points et munitions max à sa mort. Les pièges le blessent sans le tuer net.

- **10 atouts, 6 cumulables** : Cuirasse, Main Leste, Tonique Éclair, Second Souffle, Triple Étui, et Œil de Lynx (tête +50 %), Pied Léger (vitesse +20 %), Mains d'Or (points +50 %), Bouclier (immunité aux explosions, soin 2× plus rapide), Ravitailleur (réserves +50 %).
- **Tableau des scores** (Tab / bouton Retour) : manche, éliminations, tirs à la tête, précision, points, atouts achetés, temps de jeu.
- **Manette** (Xbox) : sticks, gâchettes, boutons, vibrations ; les indications `[F]` deviennent `[Y]` quand la manette est utilisée. Navigation dans les menus à la manette.
- **Annonceur** : voix française synthétique (Microsoft Hortense) filtrée « radio » pour les power-ups, le courant, le boss, les chiens et les manches 5, 10, 15…
- **Musique** : vraies boucles ambiance (menu et jeu), voir crédits.

- **Options** : volume général, musique, effets et voix séparés (bus audio), qualité des ombres (4 niveaux), limite d'images/s, VSync, plein écran, champ de vision, sensibilité. Sauvegardées dans `user://settings.cfg`.
- **Remappage** : menu Commandes, clavier/souris et manette séparément, réinitialisation en un clic ; les indications à l'écran suivent vos touches.
- **Records** (`user://records.cfg`) : manche, éliminations, tirs à la tête, points, plus longue survie, parties jouées ; menu RECORDS et message « Nouveau record » en fin de partie.
- **Power-ups** : Feu de vente (armes murales et boîte à 10 points, 30 s, la boîte ne déménage pas), Bonus de points (500 + 100 par manche), Sang de zombie (30 s : les zombies à plus de 2,5 m vous ignorent, écran teinté de bleu).

- **Bras du joueur** (`scripts/player/fps_arms.gd`) : modèle rigged avec manches ; IK à deux os qui place chaque main sur la poignée de l'arme (prises réglées par arme dans `weapon_db.gd`), doigts refermés, main gauche qui quitte l'arme pendant le rechargement.
- **Zombies** : 5 tenues (textures dérivées sans logo), silhouettes aléatoires, animation de course (sprinteurs penchés, bras qui pompent) et de reptation (bras tendus qui tirent).

## Lancer
Ouvrir le projet dans Godot 4.7 et appuyer sur F5 (scène principale : `scenes/main_menu.tscn`).
`scenes/game.tscn` peut aussi être lancée directement (F6).

## Contrôles
ZQSD/WASD : se déplacer · Souris : viser · Clic gauche : tirer · Clic droit : viser (ADS)
R : recharger · F : interagir / acheter (maintenir pour réparer) · Maj : sprint · Ctrl : accroupi
Espace : sauter · V : couteau · G : grenade · 1/2/3 ou molette : armes · Échap : pause

## Structure
- `autoload/` : `GameManager` (points, manche, atouts, power-ups, réglages, contrôles), `Audio` (sons + synthèse de secours)
- `scenes/game.gd` : construction de la carte « Bunker abandonné », apparitions, power-ups, explosions
- `scripts/game/round_manager.gd` : manches (PV, nombre, vitesse, chiens, tanks)
- `scripts/player/` : joueur FPS et armes (`weapon_holder.gd`)
- `scripts/weapons/weapon_db.gd` : caractéristiques des armes
- `scripts/zombies/` : IA (fenêtre → planches → poursuite), modèle riggé
- `scripts/interactables/` : barricade, porte, arme murale, atout, boîte, amélioration, courant

## Tests
```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn
```
Joue une partie accélérée et vérifie navigation, manches, économie, atouts, boîte, amélioration et power-ups.

## Direction artistique
- `scripts/util/materials.gd` : matériaux texturés PBR (triplanaires, sans UV) — béton, briques, enduit, bois, métal, terre
- `scripts/game/map_art.gd` : habillage de la carte (lampes suspendues avec ombres, gyrophare, tuyaux, poutres, caisses, fûts, sacs de sable, étagères, générateur, arbres morts, inscriptions au pochoir, sang, poussière)
- `scripts/util/effects.gd` + `shaders/` : particules (sang, étincelles, explosions), flaques de sang, post-traitement (vignette, grain, voile rouge de blessure)
- `scenes/ui/ui_theme.gd` : thème d'interface (polices Windows Impact / Bahnschrift / Stencil via `SystemFont`)
- Menu principal sur fond 3D animé (`scenes/main_menu.gd`), menu pause et écran de fin superposés au jeu

## Crédits
Bras du joueur : « FPS Arms (Rigged Only) » (CC0, maillage de base MakeHuman), OpenGameArt — voir `assets/models/arms/LICENSE.txt`.
Zombies : modèle « Zombie » de [Pixelhouse](http://pixelhouse.com.ar) (CC-BY 3.0, [OpenGameArt](https://opengameart.org/content/zombie-0)) — voir `assets/models/zombie_real/LICENSE.txt`.
Chiens : loup « Winter Wolf + Normal Wolf » de umask007 (CC-BY-SA 3.0, [OpenGameArt](https://opengameart.org/content/winter-wolf-normal-wolf)), converti en glTF — voir `assets/models/dog/LICENSE.txt`.
Modèles d'armes, personnage de secours et sons d'impact : [Kenney](https://www.kenney.nl) (CC0) —
Blaster Kit, Animated Characters Survivors, Impact Sounds. Voir `assets/LICENSE_kenney.txt`.
Textures : [ambientCG](https://ambientcg.com) (CC0) — voir `assets/textures/CREDITS.txt`.
Sons réels : tirs de Vincent Sevedge (CC-BY 3.0), rechargements, cris de zombies et rugissement du boss (CC0) — voir `assets/sounds/CREDITS.txt`.
Musique : « Ambient Horror Track 01 » (CC0) et « Dark Ambience Loop » d'Iwan Gabovitch (CC-BY 3.0), OpenGameArt. Annonceur : voix de synthèse générée localement. Sons restants : synthétisés au lancement (`autoload/audio.gd`).
