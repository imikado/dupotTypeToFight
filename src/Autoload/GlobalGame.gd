extends Node

const GROUP_ENEMY := "enemy"

const PATH_HIGHSCORE := "user://highscore.dat"
const PATH_SETTINGS := "user://settings.dat"
# niveaux débloqués et meilleur score de chaque niveau, par disposition de clavier
const PATH_PROGRESS := "user://progress.dat"

enum LEVEL_DIFFICULTY {EASY, NORMAL}

enum KEYBOARD_LAYOUT {AZERTY, QWERTY}

# apprentissage lettre par lettre, ou mots de plus en plus longs
enum GAME_MODE {LEARN, WORDS}

const LEVEL_EASY_PLAYER_START_LIFE = 100
const LEVEL_NORMAL_PLAYER_START_LIFE = 80

const LEVEL_EASY_SPEED_COEF = 0.7
const LEVEL_NORMAL_SPEED_COEF = 1.0

var player_start_life = LEVEL_EASY_PLAYER_START_LIFE
var enemy_speed_coef = LEVEL_EASY_SPEED_COEF

var _level_difficulty = LEVEL_DIFFICULTY.EASY
var _keyboard_layout = KEYBOARD_LAYOUT.AZERTY

# langues disponibles (colonnes de src/Locales/translations.csv)
const LANGUAGES := ["en", "fr"]
const DEFAULT_LANGUAGE := "en"

var _language := DEFAULT_LANGUAGE
# petit clavier permanent en bas de l'écran pendant le jeu
var _show_keyboard := false

# précision minimale pour passer au niveau suivant (choix dans les paramètres)
const REQUIRED_ACCURACY_CHOICES := [0.94, 0.9, 0.8, 0.7]
var _required_accuracy := 0.94

# tutoriel sur la position des mains avant le niveau 1 (désactivable dans les paramètres)
var _tutorial_enabled := true

var currentLevel = 1
var _game_mode := GAME_MODE.LEARN

# disposition (en texte, pour le JSON) ou "words" pour le mode Mots
# -> {"unlocked": niveau max, "best_scores": {niveau: score}}
const PROGRESS_KEY_WORDS := "words"
var _progress := {}


func _ready():
	# par défaut, la langue du système si elle est traduite
	var system_language = OS.get_locale_language()
	_language = system_language if LANGUAGES.has(system_language) else DEFAULT_LANGUAGE
	loadSettings()
	_load_progress()
	TranslationServer.set_locale(_language)


func saveLevel(newLevel):
	currentLevel = newLevel


func getLevel():
	return currentLevel


func getGameMode() -> GAME_MODE:
	return _game_mode


func setGameMode(mode: GAME_MODE):
	_game_mode = mode


func isWordsMode() -> bool:
	return _game_mode == GAME_MODE.WORDS


func getLevelDifficulty():
	return _level_difficulty


func isLevelDifficultyEasy():
	return _level_difficulty == LEVEL_DIFFICULTY.EASY


func loadDifficulty(levelDifficulty: LEVEL_DIFFICULTY):
	_level_difficulty = levelDifficulty
	if levelDifficulty == LEVEL_DIFFICULTY.EASY:
		player_start_life = LEVEL_EASY_PLAYER_START_LIFE
		enemy_speed_coef = LEVEL_EASY_SPEED_COEF
	elif levelDifficulty == LEVEL_DIFFICULTY.NORMAL:
		player_start_life = LEVEL_NORMAL_PLAYER_START_LIFE
		enemy_speed_coef = LEVEL_NORMAL_SPEED_COEF
	saveSettings()


func getKeyboardLayout():
	return _keyboard_layout


func loadKeyboardLayout(layout: KEYBOARD_LAYOUT):
	_keyboard_layout = layout
	saveSettings()


func getLanguage() -> String:
	return _language


func loadLanguage(language: String):
	if not LANGUAGES.has(language):
		return
	_language = language
	TranslationServer.set_locale(language)
	saveSettings()


func isTutorialEnabled() -> bool:
	return _tutorial_enabled


func setTutorialEnabled(enabled: bool):
	_tutorial_enabled = enabled
	saveSettings()


func getRequiredAccuracy() -> float:
	return _required_accuracy


func setRequiredAccuracy(required_accuracy: float):
	_required_accuracy = required_accuracy
	saveSettings()


func isKeyboardShown() -> bool:
	return _show_keyboard


func setKeyboardShown(shown: bool):
	_show_keyboard = shown
	saveSettings()


# keep_weak_keys : après un game over, on garde les points faibles du joueur
func resetGame(level := 1, keep_weak_keys := false):
	currentLevel = level
	GlobalPlayer.reset_game(keep_weak_keys)


# progression du mode en cours : par disposition de clavier en apprentissage,
# commune aux deux dispositions en mode Mots
func _get_layout_progress() -> Dictionary:
	var key = PROGRESS_KEY_WORDS if isWordsMode() else str(_keyboard_layout)
	if not _progress.get(key) is Dictionary:
		_progress[key] = {}
	var layout_progress: Dictionary = _progress[key]
	if not layout_progress.get("best_scores") is Dictionary:
		layout_progress["best_scores"] = {}
	return layout_progress


# plus haut niveau atteint : tous les niveaux jusqu'à lui sont accessibles
func getUnlockedLevel() -> int:
	return max(1, int(_get_layout_progress().get("unlocked", 1)))


func unlockLevel(level: int):
	if level <= getUnlockedLevel():
		return
	_get_layout_progress()["unlocked"] = level
	_save_progress()


func getLevelBestScore(level: int) -> int:
	return int(_get_layout_progress().best_scores.get(str(level), 0))


# renvoie vrai si c'est un nouveau record pour ce niveau
func saveLevelScore(level: int, score: int) -> bool:
	if score <= getLevelBestScore(level):
		return false
	_get_layout_progress().best_scores[str(level)] = score
	_save_progress()
	return true


func _save_progress():
	saveFile(PATH_PROGRESS, JSON.stringify(_progress))


func _load_progress():
	if not FileAccess.file_exists(PATH_PROGRESS):
		return
	var parsed = JSON.parse_string(load_file(PATH_PROGRESS))
	_progress = parsed if parsed is Dictionary else {}


func saveSettings():
	var settings = {"difficulty": _level_difficulty, "layout": _keyboard_layout, "language": _language, "show_keyboard": _show_keyboard, "required_accuracy": _required_accuracy, "tutorial": _tutorial_enabled}
	saveFile(PATH_SETTINGS, JSON.stringify(settings))


func loadSettings():
	if not FileAccess.file_exists(PATH_SETTINGS):
		return
	var parsed = JSON.parse_string(load_file(PATH_SETTINGS))
	if not parsed is Dictionary:
		return
	_keyboard_layout = int(parsed.get("layout", KEYBOARD_LAYOUT.AZERTY)) as KEYBOARD_LAYOUT
	_show_keyboard = bool(parsed.get("show_keyboard", false))
	_tutorial_enabled = bool(parsed.get("tutorial", true))
	var required_accuracy = float(parsed.get("required_accuracy", _required_accuracy))
	if REQUIRED_ACCURACY_CHOICES.has(required_accuracy):
		_required_accuracy = required_accuracy
	var language = parsed.get("language", _language)
	if LANGUAGES.has(language):
		_language = language
	# loadDifficulty sauvegarde : on positionne la disposition et la langue avant
	loadDifficulty(int(parsed.get("difficulty", LEVEL_DIFFICULTY.EASY)) as LEVEL_DIFFICULTY)


func saveHighScore(newScoreValue, level):
	if newScoreValue <= 0:
		return

	var dt := Time.get_datetime_dict_from_system()
	var dateTimeString := "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]

	var highScoreList = getHighScoreList()
	highScoreList.append({"score": newScoreValue, "level": level, "mode": _game_mode, "date": dateTimeString})
	highScoreList.sort_custom(func(a, b): return a.score > b.score)
	# les 10 meilleurs de chaque mode
	var kept := []
	var count_by_mode := {}
	for entry in highScoreList:
		var mode = int(entry.get("mode", GAME_MODE.LEARN))
		count_by_mode[mode] = count_by_mode.get(mode, 0) + 1
		if count_by_mode[mode] <= 10:
			kept.append(entry)
	highScoreList = kept

	saveFile(PATH_HIGHSCORE, JSON.stringify(highScoreList))


# meilleur score d'une partie dans le mode donné (le mode en cours par défaut) ;
# les anciens scores, sans mode, sont ceux de l'apprentissage
func getHighestScore(mode: int = -1) -> int:
	if mode == -1:
		mode = _game_mode
	var highestScore = 0
	for highScoreLoop in getHighScoreList():
		if int(highScoreLoop.get("mode", GAME_MODE.LEARN)) != mode:
			continue
		if highScoreLoop.score > highestScore:
			highestScore = highScoreLoop.score
	return int(highestScore)


func getHighScoreList() -> Array:
	if not FileAccess.file_exists(PATH_HIGHSCORE):
		return []

	var parsed = JSON.parse_string(load_file(PATH_HIGHSCORE))
	if parsed is Array:
		return parsed

	return []


func saveFile(filepath: String, content: String) -> void:
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(content)


func load_file(filepath: String) -> String:
	if not FileAccess.file_exists(filepath):
		return ""
	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
