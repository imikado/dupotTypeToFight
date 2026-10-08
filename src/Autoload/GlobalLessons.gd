extends Node

# Progression inspirée des méthodes d'apprentissage de la dactylographie :
# on commence par les touches de repos des index (F et J), puis on élargit
# la rangée de repos, puis les touches d'index G/H, la rangée du haut et enfin
# celle du bas. Chaque entrée = les nouvelles touches débloquées à ce niveau.
const LESSONS := {
	0: [  # GlobalGame.KEYBOARD_LAYOUT.AZERTY
		["f", "j"],
		["d", "k"],
		["s", "l"],
		["q", "m"],
		["g", "h"],
		["r", "u"],
		["e", "i"],
		["z", "o"],
		["a", "p"],
		["t", "y"],
		["v", "n"],
		["c", "b"],
		["x", "w"],
	],
	1: [  # GlobalGame.KEYBOARD_LAYOUT.QWERTY
		["f", "j"],
		["d", "k"],
		["s", "l"],
		["a"],
		["g", "h"],
		["r", "u"],
		["e", "i"],
		["w", "o"],
		["q", "p"],
		["t", "y"],
		["v", "n"],
		["c", "m"],
		["x", "z", "b"],
	],
}

const FINGERS := {
	0: {  # GlobalGame.KEYBOARD_LAYOUT.AZERTY
		"auriculaire gauche": "aqw",
		"annulaire gauche": "zsx",
		"majeur gauche": "edc",
		"index gauche": "rfvtgb",
		"index droit": "yhnuj",
		"majeur droit": "ik",
		"annulaire droit": "ol",
		"auriculaire droit": "pm",
	},
	1: {  # GlobalGame.KEYBOARD_LAYOUT.QWERTY
		"auriculaire gauche": "qaz",
		"annulaire gauche": "wsx",
		"majeur gauche": "edc",
		"index gauche": "rfvtgb",
		"index droit": "yhnujm",
		"majeur droit": "ik",
		"annulaire droit": "ol",
		"auriculaire droit": "p",
	},
}


# une couleur par doigt : main gauche en tons chauds (rouge -> jaune), main droite
# dans les couleurs complémentaires (cyan -> indigo) ; chaque doigt a pour
# couleur la complémentaire de son symétrique (index F jaune / index J indigo).
# Les bleus sont un peu éclaircis pour rester aussi lisibles que les tons chauds.
const FINGER_COLORS := {
	"auriculaire gauche": Color(0.95, 0.33, 0.24),  # teinte 8°
	"annulaire gauche": Color(0.95, 0.57, 0.24),  # teinte 28°
	"majeur gauche": Color(0.95, 0.77, 0.24),  # teinte 45°
	"index gauche": Color(0.95, 0.93, 0.24),  # teinte 58°
	"index droit": Color(0.45, 0.47, 1.00),  # teinte 238° (complémentaire)
	"majeur droit": Color(0.45, 0.59, 1.00),  # teinte 225° (complémentaire)
	"annulaire droit": Color(0.45, 0.74, 1.00),  # teinte 208° (complémentaire)
	"auriculaire droit": Color(0.45, 0.93, 1.00),  # teinte 188° (complémentaire)
}
const COLOR_UNKNOWN_FINGER := Color(0.34, 0.39, 0.73)

# rangées du clavier (haut, repos, bas) pour chaque disposition
const KEYBOARD_ROWS := {
	0: ["azertyuiop", "qsdfghjklm", "wxcvbn"],  # GlobalGame.KEYBOARD_LAYOUT.AZERTY
	1: ["qwertyuiop", "asdfghjkl", "zxcvbnm"],  # GlobalGame.KEYBOARD_LAYOUT.QWERTY
}
# nuance selon la rangée : plus foncé en haut, normal sur la rangée de repos,
# plus clair en bas
const ROW_TOP_DARKEN := 0.25
const ROW_BOTTOM_LIGHTEN := 0.3


func _get_lessons() -> Array:
	return LESSONS[GlobalGame.getKeyboardLayout()]


func get_lesson_count() -> int:
	return _get_lessons().size()


# nouvelles touches introduites au niveau donné (vide après la dernière leçon)
func get_new_keys(level: int) -> Array:
	var lessons = _get_lessons()
	if level < 1 or level > lessons.size():
		return []
	return lessons[level - 1]


# toutes les touches disponibles jusqu'au niveau donné
func get_keys(level: int) -> Array:
	var keys := []
	var lessons = _get_lessons()
	for i in range(min(level, lessons.size())):
		keys.append_array(lessons[i])
	return keys


# tire une touche en privilégiant les nouvelles touches du niveau
# part des touches tirées parmi les points faibles du joueur, quand il en a
const WEAK_KEY_CHANCE := 0.4


# weak_keys : touche -> poids ; ces touches ratées reviennent plus souvent
func pick_key(level: int, weak_keys := {}) -> String:
	var available = get_keys(level)
	var weights := {}
	for key in weak_keys:
		if available.has(key):
			weights[key] = weak_keys[key]
	if not weights.is_empty() and randf() < WEAK_KEY_CHANCE:
		return _pick_weighted(weights)

	var new_keys = get_new_keys(level)
	if not new_keys.is_empty() and randf() < 0.5:
		return new_keys.pick_random()
	return get_keys(level).pick_random()


func _pick_weighted(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += weights[key]
	var roll = randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0:
			return key
	return weights.keys().back()


func get_finger(key: String) -> String:
	var fingers = FINGERS[GlobalGame.getKeyboardLayout()]
	for finger in fingers:
		if fingers[finger].contains(key):
			return finger
	return ""


func get_keyboard_rows() -> Array:
	return KEYBOARD_ROWS[GlobalGame.getKeyboardLayout()]


# rangée de la touche : 0 en haut, 1 rangée de repos, 2 en bas (-1 si absente)
func get_row(key: String) -> int:
	var rows = get_keyboard_rows()
	for i in rows.size():
		if rows[i].contains(key):
			return i
	return -1


# couleur d'une touche : celle de son doigt, nuancée selon sa rangée
func get_key_color(key: String) -> Color:
	var color: Color = FINGER_COLORS.get(get_finger(key), COLOR_UNKNOWN_FINGER)
	match get_row(key):
		0:
			return color.darkened(ROW_TOP_DARKEN)
		2:
			return color.lightened(ROW_BOTTOM_LIGHTEN)
	return color
