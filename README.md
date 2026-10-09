# Bunker Z

FPS de survie par manches inspiré des modes zombies : barricades, points, armes murales,
portes payantes, boîte mystère, atouts, courant, machine d'amélioration, power-ups,
manches de chiens et tanks. Godot 4.7, GDScript, rendu Compatibility.

## Mécaniques avancées
- **Pièges** (courant requis, 1000 points, actifs 25 s, recharge 45 s) : électrique dans le couloir, à feu près de la fenêtre ouest de la grande salle. Ils tuent tous les zombies dans la zone et blessent le joueur.
- **Deux niveaux d'amélioration** : niveau 1 (5000 points, camouflage violet, dégâts x2,5) puis niveau II (8000 points, camouflage doré, dégâts x4, chargeurs x2). Munitions de niveau II : 6000 à l'arme murale.
- **Arme unique** (Bunker) : trois pièces cachées (Bobine, Batterie, Condensateur : coin de la salle de départ, couloir, derrière un pilier de la grande salle) à assembler à l'établi de la salle de départ → **Arc Tonnerre** (foudre qui rebondit sur 3 zombies, absente de la boîte mystère).
- **Boisson d'atout** : un flacon de la couleur de l'atout monte à la bouche pendant l'achat.
- **À terre** : à zéro vie, on tombe 5 s (3 s avec Second Souffle, qui réanime) ; on rampe et on tire au pistolet seul, les autres armes sont rendues à la réanimation.
- **Difficulté** (Options > Jeu) : Facile (dégâts x0,6, ennemis -20 % de santé, régénération rapide), Normal, Réaliste (dégâts x1,6, ennemis +30 % de santé et +10 % de vitesse, régénération lente).
- **Améliorations spéciales** : chaque arme améliorée gagne un effet — P9 et Longue-Vue : balles explosives ; Vipère et Tonnerre : balles incendiaires ; Carabine et K-74 : arc électrique qui rebondit sur 3 zombies ; Brise-Porte : souffle qui repousse.
- **Démembrement** : les balles concentrées sur un avant-bras ou un mollet arrachent le membre (morceau projeté, sang) ; perdre une jambe ou subir une explosion non mortelle peut transformer le zombie en rampant (plus lent, plus bas).

- **Singe-leurre** (touche T) : obtenu par 3 dans la boîte mystère. Posé au sol, il joue des cymbales 7 s, attire tous les zombies (pas les chiens ni le boss) puis explose.
- **Le Colosse** (manches 10, 20, 30…) : boss blindé qui apparaît dans un éclair au milieu de la manche. Son casque absorbe 75 % des dégâts à la tête jusqu'à se briser. Il charge à travers la salle et frappe le sol (dégâts de zone + projection). Barre de vie en haut de l'écran, 500 points et munitions max à sa mort. Les pièges le blessent sans le tuer net.

- **12 atouts, 6 cumulables** : Cuirasse, Main Leste, Tonique Éclair, Second Souffle, Triple Étui, Gilet Lourd (dégâts reçus -35 %), Course Folle (sprint +30 %), et Œil de Lynx (tête +50 %), Pied Léger (vitesse +20 %), Mains d'Or (points +50 %), Bouclier (immunité aux explosions, soin 2× plus rapide), Ravitailleur (réserves +50 %).
- **Tableau des scores** (Tab / bouton Retour) : manche, éliminations, tirs à la tête, précision, points, atouts achetés, temps de jeu.
- **Manette** (Xbox) : sticks, gâchettes, boutons, vibrations ; les indications `[F]` deviennent `[Y]` quand la manette est utilisée. Navigation dans les menus à la manette.
- **Annonceur** : désactivé (la voix de synthèse déplaisait). Le code `Audio.say` reste en place : il reprendra dès que des fichiers `assets/sounds/voice_*.wav` seront présents.
- **Manette** : A valide et B annule dans les menus.
- **Musique** : vraies boucles ambiance (menu et jeu), voir crédits.

- **Exécutable Windows** : `Godot_..._console.exe --headless --path . --export-release "Windows Desktop" build/BunkerZ.exe` produit un `.exe` unique (≈ 160 Mo, données incluses) dans `build/` (ignoré par git). Nécessite les modèles d'export Godot 4.7.2 (Éditeur > Gérer les modèles d'export). Réglages et records sont enregistrés dans `%APPDATA%\Bunker Z\`.
- **Performances** : ombres désactivées par défaut (une seule ombre de lampe coûte plus de la moitié des images/s sur un GPU intégré ; les niveaux 1 à 3 ajoutent 1 lampe, 2 lampes, puis la lune), petits objets sans ombre et masqués au loin, occlusion par les murs, zombies animés à fréquence réduite quand ils sont loin, séparation et chemins moins coûteux. Mesure : `Godot_console.exe --path . res://tests/perf.tscn -- 24 sq0` (24 zombies ; options `sq0`..`sq3`, `msaa0`, `noglow`…).
- **Mode test** (Options > Test) : en jeu, F1 arme suivante (les 13 armes), F2 améliorer/retirer l'amélioration, F3 munitions pleines et +50000 points, F4 tous les atouts, F5 terminer la manche.
- **Options** : volume général, musique, effets et voix séparés (bus audio), qualité des ombres (4 niveaux), limite d'images/s, VSync, plein écran, champ de vision, sensibilité. Sauvegardées dans `user://settings.cfg`.
- **Remappage** : menu Commandes, clavier/souris et manette séparément, réinitialisation en un clic ; les indications à l'écran suivent vos touches.
- **Records** (`user://records.cfg`) : manche, éliminations, tirs à la tête, points, plus longue survie, parties jouées ; menu RECORDS et message « Nouveau record » en fin de partie.
- **Power-ups** : Feu de vente (armes murales et boîte à 10 points, 30 s, la boîte ne déménage pas), Bonus de points (500 + 100 par manche), Sang de zombie (30 s : les zombies à plus de 2,5 m vous ignorent, écran teinté de bleu).

- **Bras du joueur** (`scripts/player/fps_arms.gd`) : modèle rigged avec manches ; IK à deux os qui place chaque main sur la poignée de l'arme (prises réglées par arme dans `weapon_db.gd`), doigts refermés, main gauche qui quitte l'arme pendant le rechargement. Animations : prise en main (l'arme remonte en tournant), pompe du fusil à pompe (main avant) et verrou du sniper (main droite), lancer de grenade / singe-leurre (la main prend l'objet, l'autre retire la goupille, l'objet part à la libération, 0,5 s).
- **Cadavres physiques (ragdoll)** : à la mort, un zombie debout devient 10 corps rigides reliés par des articulations (`start_ragdoll` dans `zombie_model_real.gd`) qui pilotent les os ; projeté à l'opposé du joueur, en l'air pour une explosion. 8 ragdolls simultanés au maximum (au-delà : animation de mort classique) ; les rampants et les chiens gardent l'animation de mort.
- **Apparences** : à côté du civil de base, les zombies ordinaires sont des **soldats** (casque, gilet, sac, ceinture), des **ouvriers** (casque de chantier, gilet orange) ou des **femmes** (silhouette plus fine et plus petite, cheveux longs et jupe, ou queue-de-cheval et haut bleu). Même squelette : l'équipement suit les os, donc démembrement et ragdoll fonctionnent.
- **Zombies** : 5 tenues (textures dérivées sans logo), silhouettes aléatoires, animation de course (sprinteurs penchés, bras qui pompent) avec foulée amplifiée, genoux levés et torsion du buste, et de reptation (bras tendus qui tirent, buste qui se tord, jambes qui traînent).

- **Arsenal** (13 armes, `weapon_db.gd`) : P9, Justicier (revolver), Carabine M2, Vipère et Frelon (pistolets-mitrailleurs), Brise-Porte et Double Canon (fusils à pompe), K-74, Spectre (bullpup), Tonnerre (mitrailleuse), Éclaireur (fusil de précision semi-auto) et Longue-Vue (sniper), plus le Désintégrateur (arme futuriste, boîte mystère). Modèles 3D réalistes Quaternius, tir enregistré propre à chaque arme. Les armes longues sont poussées vers le joueur et le centre de l'écran pour que les deux mains les atteignent ; en visée, l'arme est calée sur sa ligne de mire.
- **Cartes** : choix au clic sur *Jouer*. **Bunker abandonné** (3 zones) et **Laboratoire Sigma** (4 zones : accueil, couloir, salle des cuves, réacteur), 11 fenêtres, 12 atouts, 6 armes murales, un piège, la boîte mystère et la machine d'amélioration.
- **Téléporteur** (laboratoire) : deux plateformes (accueil ↔ réacteur), courant requis, 750 points, recharge 25 s. La première utilisation ouvre la zone du réacteur sans payer sa porte.
- **Quête secrète** (laboratoire) : les archives de l'accueil donnent trois indices ; il faut retrouver 3 fioles de sérum cachées (accueil, couloir, cuves), les rapporter à la console du réacteur (courant requis) et tenir 40 s pendant la synthèse. Récompense : une vie supplémentaire, munitions max et 3000 points.
- **Brute** (dès la manche 7) : grosse silhouette, 3 fois plus de vie, bouclier métallique qui absorbe 65 % des tirs au corps venant de face (jusqu'à se briser ; la tête et les explosions l'ignorent), charge à 7,5 m/s qui projette le joueur.
- **Infecté** (dès la manche 9) : rapide, teint verdâtre ; ses griffes infectent (perte de vie continue 10 s, plus de régénération) et, à sa mort, il laisse un nuage toxique 5 s qui infecte à nouveau.
- **Zombies spéciaux** (apparition progressive) : **Kamikaze** (dès la manche 6) rouge et lumineux, il s'arrête à 2 m, clignote 0,7 s puis explose (dégâts de zone, pas de points s'il se fait sauter) ; abattu à distance il explose aussi. **Cracheur** (manche 8) vert, garde 6-14 m de distance et crache des boules d'acide (25 dégâts, flaque verte). **Hurleur** (manche 10) pâle, hurle : étourdit le joueur (son étouffé, secousse, 12 dégâts) et enrage tous les zombies pendant 7 s (+45 % de vitesse). Une bannière explique chaque type à sa première apparition.

- **Indicateurs de dégâts directionnels** : flèche rouge autour du réticule vers la source du coup (zombie, acide, explosion, boss), qui s'efface en 2,6 s.
- **Power-ups** supplémentaires : **Munitions illimitées** (30 s, les chargeurs ne baissent plus) et **Dernier survivant** (une vie supplémentaire : le prochain coup fatal est annulé, soin complet et 3 s d'invulnérabilité ; cumulable).
- **Options image** : anticrénelage MSAA (désactivé/2x/4x/8x), résolution de la fenêtre, échelle de rendu 3D (50-100 %).
- **Musique** : fin de manche (« abyss »), jingle de mort.

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
Armes : « Ultimate Gun Pack » de [Quaternius](https://quaternius.com) (CC0, `assets/models/guns/LICENSE.txt`) ; tirs : « The Free Firearm Sound Library » de Ben Jaszczak et al. (CC0, `assets/sounds/CREDITS_GUNS.txt`).
Armes futuristes, personnage de secours et sons d'impact : [Kenney](https://www.kenney.nl) (CC0) —
Blaster Kit, Animated Characters Survivors, Impact Sounds. Voir `assets/LICENSE_kenney.txt`.
Textures : [ambientCG](https://ambientcg.com) (CC0) — voir `assets/textures/CREDITS.txt`.
Sons réels : tirs de Vincent Sevedge (CC-BY 3.0), rechargements, cris de zombies et rugissement du boss (CC0) — voir `assets/sounds/CREDITS.txt`.
Musique : « Ambient Horror Track 01 » (CC0), « Dark Ambience Loop » d'Iwan Gabovitch (CC-BY 3.0), « String and piano horror stings » (CC0) et « Game over short jingle » (CC0), OpenGameArt. Sons restants : synthétisés au lancement (`autoload/audio.gd`).
