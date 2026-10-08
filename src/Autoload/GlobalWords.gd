extends Node

# Mode « Mots » : chaque ennemi porte un mot à taper. Les mots s'allongent avec
# les niveaux : 3 lettres, puis 4, 5... Listes sans accents (uniquement a-z),
# dans la langue du jeu.

const MIN_LENGTH := 3
const MAX_LENGTH := 7
# nombre de niveaux pour chaque longueur de mot
const LEVELS_PER_LENGTH := 2
# part des mots choisis parce qu'ils contiennent un point faible du joueur
const WEAK_KEY_CHANCE := 0.4

const WORDS := {
	"en": {
		3: "cat dog sun cup hat red bed box car bus pen map fox egg ink jam key leg man net owl pig rat sea sky tea toy van web yes zoo arm bag bat cow day ear fan fig hen ice jar kid lip mud nut oak",
		4: "fish bird tree book door rain snow wind moon star milk cake ball game home hand foot nose king frog lion bear duck goat wolf ship boat road city park rock sand blue pink gold time jump walk play sing",
		5: "apple house water green black white chair table bread horse mouse tiger zebra train plane beach ocean river cloud storm happy smile dance music piano lemon grape candy queen pizza world light night sweet",
		6: "orange banana yellow purple garden window kitten rabbit monkey turtle castle forest island summer winter spring flower butter cookie pencil school friend family doctor planet rocket guitar dragon",
		7: "kitchen chicken dolphin giraffe penguin rainbow morning evening library teacher student holiday balloon blanket picture monster journey weather sunrise cartoon",
	},
	"fr": {
		3: "ami arc bal bas bol bus cas cou cri dos eau feu fil fin jeu jus lac lit loi lui mer mot mur nez nid nom nul oie pas peu pin pot rat riz roi rue sac sel sol sou tas toi une vin vue car sud col",
		4: "ours lune loup chat pain lait miel bois main pied joue nuit jour vent pont port rose bleu vert noir gris roux tour four sous dans avec pour mais ciel cerf bras dent nord pull jupe note page fils robe lent vite doux fort",
		5: "chien sapin lapin vache pomme poire neige table livre arbre fleur herbe plage nuage pluie route ville place porte tigre sucre jambe plume stylo verre carte reine jouer chant blanc rouge jaune vingt douze seize trois piano ouest",
		6: "chaise soleil farine beurre ventre crayon prince quatre cheval maison jardin oiseau poulet lettre bouche cerise orange banane tomate violet bonnet chemin voyage danser sortir partir dormir courir mouton souris renard castor",
		7: "oreille carotte chanter musique voiture journal poisson dauphin pompier fromage chemise cadeaux bonjour marcher manteau vitesse grenier abricot",
	},
}

var _cache := {}


# longueur des mots au niveau donné : 3 lettres aux premiers niveaux, puis 4...
func get_word_length(level: int) -> int:
	return min(MAX_LENGTH, MIN_LENGTH + int((level - 1) / LEVELS_PER_LENGTH))


func get_words(length: int) -> Array:
	var language = GlobalGame.getLanguage()
	if not WORDS.has(language):
		language = GlobalGame.DEFAULT_LANGUAGE
	var cache_key = "%s_%d" % [language, length]
	if not _cache.has(cache_key):
		_cache[cache_key] = WORDS[language][length].split(" ", false)
	return _cache[cache_key]


# weak_keys : touche -> poids ; les mots contenant une touche ratée reviennent plus souvent
func pick_word(level: int, weak_keys := {}) -> String:
	var words = get_words(get_word_length(level))
	if not weak_keys.is_empty() and randf() < WEAK_KEY_CHANCE:
		var weak_key = GlobalLessons.pick_weighted(weak_keys)
		var matching = words.filter(func(word): return word.contains(weak_key))
		if not matching.is_empty():
			return matching.pick_random()
	return words.pick_random()


# toutes les lettres du clavier : les mots peuvent les utiliser toutes
func get_keys() -> Array:
	var keys := []
	for row in GlobalLessons.get_keyboard_rows():
		for key in row:
			keys.append(key)
	return keys
