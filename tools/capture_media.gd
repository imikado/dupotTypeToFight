extends SceneTree

# Capture des GIF et captures d'écran de présentation : un bot joue à la place du
# joueur (avec quelques erreurs). Utilisé par tools/capture_media.sh.
#
# Scénarios (variable d'environnement SCENARIO) :
# - gif_training, gif_arcade : partie au niveau 3, à enregistrer avec --write-movie
# - shot_training, shot_arcade, shot_ready, shot_error, shot_stats, shot_menu,
#   shot_levels : une capture PNG dans le fichier SHOT
#
# Attention : modifie les données utilisateur du jeu (paramètres, progression) ;
# le script shell les sauvegarde et les restaure.

const LEVEL_SCENE := "res://src/Levels/level.tscn"
const MENU_SCENE := "res://src/UI/Screens/Menu.tscn"
const LEVEL := 3
const GIF_DURATION := 16.0
const ERROR_RATE := 0.07

var _scenario := OS.get_environment("SCENARIO")
var _shot_path := OS.get_environment("SHOT")
var _level
var _bot_enabled := false
var _bot_cooldown := 0.0
var _force_error := false
var _error_rate := ERROR_RATE


func _initialize():
	seed(42)
	_run.call_deferred()


func _run():
	var game = root.get_node("GlobalGame")
	game.loadLanguage("en")
	game.loadKeyboardLayout(game.KEYBOARD_LAYOUT.AZERTY)
	game.loadDifficulty(game.LEVEL_DIFFICULTY.EASY)
	game.setKeyboardShown(true)
	var words = _scenario.ends_with("arcade")
	game.setGameMode(game.GAME_MODE.WORDS if words else game.GAME_MODE.LEARN)

	match _scenario:
		"shot_menu":
			# scores de démonstration (les données sont vierges au départ)
			game.setGameMode(game.GAME_MODE.LEARN)
			game.saveHighScore(1840, 6)
			game.setGameMode(game.GAME_MODE.WORDS)
			game.saveHighScore(1320, 4)
			await _show_menu()
			await _wait(1.0)
			await _shot()
		"shot_levels":
			game.setGameMode(game.GAME_MODE.LEARN)
			game.unlockLevel(6)
			for level in range(1, 6):
				game.saveLevelScore(level, 400 + level * 130)
			var menu = await _show_menu()
			menu._on_play_button_pressed(game.GAME_MODE.LEARN)
			await _wait(0.5)
			await _shot()
		"shot_ready":
			await _start_level()
			await _wait(1.6)
			_press("f")
			await _wait(0.6)
			await _shot()
		"shot_training", "shot_arcade":
			await _start_level()
			await _press_ready_keys()
			_bot_enabled = true
			await _wait(7.5 if words else 8.5)
			# le bot s'arrête le temps que les animations de frappe se terminent
			_bot_enabled = false
			await _wait(0.6)
			await _shot()
		"shot_error":
			await _start_level()
			await _press_ready_keys()
			_bot_enabled = true
			await _wait(5.0)
			_force_error = true
			while _force_error:
				await process_frame
			await _wait(0.35)
			await _shot()
		"shot_stats":
			await _start_level()
			# fin de niveau réussie : il ne reste que deux ennemis à vaincre, après
			# une partie bien jouée (bilan réaliste)
			_level._killed_in_level = _level._get_kills_to_pass() - 2
			await _press_ready_keys()
			_level._good_keys = 52
			_level._errors = 2
			_level._missed = {"l": 2}
			root.get_node("GlobalPlayer")._score = 610
			_error_rate = 0.0
			_bot_enabled = true
			while not _level._can_close_stats:
				await process_frame
			await _wait(0.3)
			await _shot()
		"gif_training", "gif_arcade":
			await _start_level()
			await _press_ready_keys()
			_bot_enabled = true
			await _wait(GIF_DURATION - 3.0)
	quit()


func _show_menu():
	var menu = load(MENU_SCENE).instantiate()
	root.add_child(menu)
	await process_frame
	return menu


func _start_level():
	root.get_node("GlobalGame").resetGame(LEVEL)
	_level = load(LEVEL_SCENE).instantiate()
	root.add_child(_level)
	await process_frame


func _press_ready_keys():
	await _wait(1.4)
	for key in _level._ready_keys.duplicate():
		_press(key)
		await _wait(0.3)
	await _wait(0.8)


func _wait(seconds: float):
	await create_timer(seconds).timeout


func _press(key: String):
	var event := InputEventKey.new()
	event.keycode = OS.find_keycode_from_string(key.to_upper())
	event.unicode = key.unicode_at(0)
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventKey = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)


func _shot():
	await process_frame
	root.get_texture().get_image().save_png(_shot_path)


func _process(delta: float) -> bool:
	if not _bot_enabled or not is_instance_valid(_level):
		return false
	_bot_cooldown -= delta
	if _bot_cooldown > 0 or _level._is_level_starting or _level._is_showing_stats or _level._queue.is_empty():
		return false
	var target = _level._queue[0]
	# on attend que l'ennemi soit à l'écran (parfois on se rue sur lui)
	if target.position.x - _level._screen_left() > _level.DASH_MAX_SCREEN_X - 30:
		return false
	var expected: String = target.get_next_key()
	if _force_error or randf() < _error_rate:
		_force_error = false
		var keys: Array = _level._get_level_keys().filter(func(key): return key != expected)
		_press(keys.pick_random())
		_bot_cooldown = 0.5
		return false
	_press(expected)
	# frappes plus rapides à l'intérieur d'un mot
	_bot_cooldown = randf_range(0.12, 0.22) if target.keys.size() > 0 else randf_range(0.25, 0.45)
	return false
