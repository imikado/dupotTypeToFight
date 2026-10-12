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

# listes modifiées par le joueur (écran des paramètres), par langue :
# langue -> {"longueur": [mots]} ; une langue présente remplace entièrement la
# liste par défaut (on peut ainsi supprimer ou ajouter des tailles)
const PATH_CUSTOM_WORDS := "user://words.dat"
# tailles qu'on peut ajouter dans l'éditeur
const EDIT_MIN_LENGTH := 2
const EDIT_MAX_LENGTH := 15
# lettres accentuées ramenées à la lettre simple quand le joueur saisit ses mots
const ACCENTS := {
	"à": "a", "â": "a", "ä": "a", "á": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "í": "i",
	"ô": "o", "ö": "o", "ó": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ç": "c", "ñ": "n", "ÿ": "y",
}

var _custom := {}
# langue -> {longueur: [mots]}
var _cache := {}


func _ready():
	_load_custom()


func _get_language() -> String:
	var language = GlobalGame.getLanguage()
	if not WORDS.has(language):
		language = GlobalGame.DEFAULT_LANGUAGE
	return language


# listes de la langue du jeu : longueur -> [mots]
func _get_lists() -> Dictionary:
	var language = _get_language()
	if not _cache.has(language):
		var lists := {}
		if _custom.has(language):
			for length in _custom[language]:
				lists[int(length)] = Array(_custom[language][length])
		else:
			for length in WORDS[language]:
				lists[length] = Array(WORDS[language][length].split(" ", false))
		_cache[language] = lists
	return _cache[language]


# tailles jouables (au moins un mot), de la plus courte à la plus longue
func get_lengths() -> Array:
	var lists = _get_lists()
	var lengths = lists.keys().filter(func(length): return not lists[length].is_empty())
	lengths.sort()
	return lengths


# toutes les tailles de l'éditeur, même vides
func get_all_lengths() -> Array:
	var lengths = _get_lists().keys()
	lengths.sort()
	return lengths


# longueur des mots au niveau donné : la plus courte taille aux premiers niveaux,
# puis la suivante... (la liste par défaut si le joueur a tout vidé)
func get_word_length(level: int) -> int:
	var lengths = get_lengths()
	if lengths.is_empty():
		return MIN_LENGTH
	return lengths[min(lengths.size() - 1, int((level - 1) / LEVELS_PER_LENGTH))]


func get_words(length: int) -> Array:
	var words = _get_lists().get(length, [])
	if words.is_empty() and get_lengths().is_empty():
		var language = _get_language()
		return Array(WORDS[language].get(length, WORDS[language][MIN_LENGTH]).split(" ", false))
	return words


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


# --- édition des listes (écran des paramètres) ---

# mots d'une taille tels qu'enregistrés (vide si la taille est vide ou absente)
func get_list(length: int) -> Array:
	return _get_lists().get(length, []).duplicate()


# découpe le texte saisi : mots en minuscules sans accents, de la bonne taille ;
# -> {"words": [mots retenus], "rejected": [mots ignorés],
#     "wrong_length": [mots ignorés car pas de la bonne taille]}
func parse_words(text: String, length: int) -> Dictionary:
	var words := []
	var rejected := []
	var wrong_length := []
	var regex := RegEx.create_from_string("^[a-z]+$")
	for raw in text.replace(",", " ").replace(";", " ").replace("\n", " ").replace("\t", " ").split(" ", false):
		var word = _strip_accents(raw.to_lower())
		if word.length() != length:
			rejected.append(raw)
			wrong_length.append(raw)
		elif regex.search(word) == null:
			rejected.append(raw)
		elif not words.has(word):
			words.append(word)
	return {"words": words, "rejected": rejected, "wrong_length": wrong_length}


func _strip_accents(word: String) -> String:
	for accent in ACCENTS:
		word = word.replace(accent, ACCENTS[accent])
	return word


func set_words(length: int, words: Array):
	_get_lists()[length] = words.duplicate()
	_save_custom()


func add_length(length: int):
	var lists = _get_lists()
	if not lists.has(length):
		lists[length] = []
		_save_custom()


func remove_length(length: int):
	_get_lists().erase(length)
	_save_custom()


func is_customized() -> bool:
	return _custom.has(_get_language())


# retour à la liste fournie avec le jeu, pour la langue en cours
func reset_to_default():
	var language = _get_language()
	_custom.erase(language)
	_cache.erase(language)
	GlobalGame.saveFile(PATH_CUSTOM_WORDS, JSON.stringify(_custom))


func _save_custom():
	var lists := {}
	var source = _get_lists()
	for length in source:
		lists[str(length)] = source[length]
	_custom[_get_language()] = lists
	GlobalGame.saveFile(PATH_CUSTOM_WORDS, JSON.stringify(_custom))


func _load_custom():
	if not FileAccess.file_exists(PATH_CUSTOM_WORDS):
		return
	var parsed = JSON.parse_string(GlobalGame.load_file(PATH_CUSTOM_WORDS))
	if not parsed is Dictionary:
		return
	for language in parsed:
		if WORDS.has(language) and parsed[language] is Dictionary:
			var lists := {}
			for length in parsed[language]:
				if str(length).is_valid_int() and parsed[language][length] is Array:
					lists[str(length)] = parsed[language][length].map(func(word): return str(word))
			_custom[language] = lists
