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


# une couleur par doigt : tons chauds pour la main gauche, froids pour la droite
const FINGER_COLORS := {
	"auriculaire gauche": Color(0.9, 0.3, 0.35),
	"annulaire gauche": Color(0.95, 0.55, 0.2),
	"majeur gauche": Color(0.9, 0.8, 0.25),
	"index gauche": Color(0.5, 0.82, 0.3),
	"index droit": Color(0.25, 0.75, 0.9),
	"majeur droit": Color(0.35, 0.5, 0.95),
	"annulaire droit": Color(0.62, 0.42, 0.92),
	"auriculaire droit": Color(0.88, 0.42, 0.82),
}
const COLOR_UNKNOWN_FINGER := Color(0.34, 0.39, 0.73)


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
func pick_key(level: int) -> String:
	var new_keys = get_new_keys(level)
	if not new_keys.is_empty() and randf() < 0.5:
		return new_keys.pick_random()
	return get_keys(level).pick_random()


func get_finger(key: String) -> String:
	var fingers = FINGERS[GlobalGame.getKeyboardLayout()]
	for finger in fingers:
		if fingers[finger].contains(key):
			return finger
	return ""


func get_finger_color(key: String) -> Color:
	return FINGER_COLORS.get(get_finger(key), COLOR_UNKNOWN_FINGER)
