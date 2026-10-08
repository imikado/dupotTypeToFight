extends Node

const GROUP_ENEMY := "enemy"

const PATH_HIGHSCORE := "user://highscore.dat"
const PATH_SETTINGS := "user://settings.dat"

enum LEVEL_DIFFICULTY {EASY, NORMAL}

enum KEYBOARD_LAYOUT {AZERTY, QWERTY}

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

var currentLevel = 1


func _ready():
	# par défaut, la langue du système si elle est traduite
	var system_language = OS.get_locale_language()
	_language = system_language if LANGUAGES.has(system_language) else DEFAULT_LANGUAGE
	loadSettings()
	TranslationServer.set_locale(_language)


func saveLevel(newLevel):
	currentLevel = newLevel


func getLevel():
	return currentLevel


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


func isKeyboardShown() -> bool:
	return _show_keyboard


func setKeyboardShown(shown: bool):
	_show_keyboard = shown
	saveSettings()


func resetGame():
	currentLevel = 1
	GlobalPlayer.reset_game()


func saveSettings():
	var settings = {"difficulty": _level_difficulty, "layout": _keyboard_layout, "language": _language, "show_keyboard": _show_keyboard}
	saveFile(PATH_SETTINGS, JSON.stringify(settings))


func loadSettings():
	if not FileAccess.file_exists(PATH_SETTINGS):
		return
	var parsed = JSON.parse_string(load_file(PATH_SETTINGS))
	if not parsed is Dictionary:
		return
	_keyboard_layout = int(parsed.get("layout", KEYBOARD_LAYOUT.AZERTY)) as KEYBOARD_LAYOUT
	_show_keyboard = bool(parsed.get("show_keyboard", false))
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
	highScoreList.append({"score": newScoreValue, "level": level, "date": dateTimeString})
	highScoreList.sort_custom(func(a, b): return a.score > b.score)
	highScoreList = highScoreList.slice(0, 10)

	saveFile(PATH_HIGHSCORE, JSON.stringify(highScoreList))


func getHighestScore() -> int:
	var highestScore = 0
	for highScoreLoop in getHighScoreList():
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
