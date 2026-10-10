extends Control

@export var mainLevel: PackedScene
@export_file("*.tscn") var tutorial_scene_path: String

# les deux modes de jeu : Training (lettre par lettre) et Arcade (mots)
@onready var _play_button: Button = $Modes/TrainingButton
@onready var _words_button: Button = $Modes/ArcadeButton
@onready var _training_best: Label = $Modes/TrainingButton/VBox/Best
@onready var _arcade_best: Label = $Modes/ArcadeButton/VBox/Best
@onready var _settings_button: Button = $Menu/SettingsButton
@onready var _settings_panel: Control = $SettingsPanel
@onready var _difficulty: OptionButton = $SettingsPanel/VBoxContainer/Grid/Difficulty
@onready var _layout: OptionButton = $SettingsPanel/VBoxContainer/Grid/Layout
@onready var _language: OptionButton = $SettingsPanel/VBoxContainer/Grid/Language
@onready var _required_accuracy: OptionButton = $SettingsPanel/VBoxContainer/Grid/RequiredAccuracy
@onready var _tutorial: OptionButton = $SettingsPanel/VBoxContainer/Grid/Tutorial
@onready var _sound: OptionButton = $SettingsPanel/VBoxContainer/Grid/Sound
@onready var _music: OptionButton = $SettingsPanel/VBoxContainer/Grid/Music
@onready var _level_panel: Control = $LevelPanel
@onready var _level_grid: GridContainer = $LevelPanel/VBoxContainer/Scroll/Grid
@onready var _level_info: Label = $LevelPanel/VBoxContainer/InfoLabel
@onready var _quit_button: Button = $Menu/QuitButton
@onready var _enemy: Enemy = $Ant


func _ready():
	get_tree().paused = false
	GlobalAudio.play_menu_music()
	# le premier plan du décor passerait devant les boutons
	$Background/Foreground.visible = false

	# l'ennemi du menu sert de décor : il ne doit pas avancer
	_enemy.set_physics_process(false)
	_enemy.setup(["f", "j"], null, 1)

	# dans un navigateur (export HTML5), on ne peut pas quitter le jeu
	_quit_button.visible = not OS.has_feature("web")

	_difficulty.select(GlobalGame.getLevelDifficulty())
	_layout.select(GlobalGame.getKeyboardLayout())
	_language.select(GlobalGame.LANGUAGES.find(GlobalGame.getLanguage()))
	_required_accuracy.select(GlobalGame.REQUIRED_ACCURACY_CHOICES.find(GlobalGame.getRequiredAccuracy()))
	_tutorial.select(0 if GlobalGame.isTutorialEnabled() else 1)
	_sound.select(0 if GlobalGame.isSoundEnabled() else 1)
	_music.select(0 if GlobalGame.isMusicEnabled() else 1)
	_settings_panel.visible = false
	_level_panel.visible = false
	_refresh_texts()
	_play_button.grab_focus()


# mode : GlobalGame.GAME_MODE (apprentissage lettre par lettre ou mots) ;
# tant que seul le niveau 1 est débloqué, on joue directement ; sinon on choisit
# parmi les niveaux déjà atteints
func _on_play_button_pressed(mode: int):
	GlobalGame.setGameMode(mode)
	if GlobalGame.getUnlockedLevel() <= 1:
		_start_game(1)
	else:
		_open_level_panel()


func _start_game(level: int):
	GlobalGame.resetGame(level)
	# tutoriel sur la position des mains avant le niveau 1 de l'apprentissage,
	# sauf s'il est désactivé
	if level == 1 and not GlobalGame.isWordsMode() and GlobalGame.isTutorialEnabled():
		GlobalTransition.change_scene_to_packed(load(tutorial_scene_path))
	else:
		GlobalTransition.change_scene_to_packed(mainLevel)


# un bouton par niveau atteint, avec son meilleur score
func _open_level_panel():
	for child in _level_grid.get_children():
		child.queue_free()
	var unlocked = GlobalGame.getUnlockedLevel()
	var last_button: Button
	for level in range(1, unlocked + 1):
		var best = GlobalGame.getLevelBestScore(level)
		var button := Button.new()
		button.text = "%d\n%s" % [level, str(best) if best > 0 else "-"]
		button.custom_minimum_size = Vector2(38, 0)
		button.pressed.connect(_start_game.bind(level))
		button.focus_entered.connect(_show_level_info.bind(level))
		button.mouse_entered.connect(_show_level_info.bind(level))
		_level_grid.add_child(button)
		last_button = button
	_level_panel.visible = true
	# le dernier niveau atteint est proposé par défaut
	last_button.grab_focus()
	_show_level_info(unlocked)


func _show_level_info(level: int):
	var new_keys = GlobalLessons.get_new_keys(level)
	var keys_text = tr("LEVEL_ALL_KEYS")
	if GlobalGame.isWordsMode():
		keys_text = tr("LEVEL_WORDS") % GlobalWords.get_word_length(level)
	elif not new_keys.is_empty():
		keys_text = tr("LEVEL_NEW_KEYS") % " ".join(new_keys).to_upper()
	_level_info.text = "%s : %s\n%s" % [tr("LEVEL") % level, keys_text, tr("LEVEL_BEST_SCORE") % GlobalGame.getLevelBestScore(level)]


func _on_level_back_button_pressed():
	_level_panel.visible = false
	(_words_button if GlobalGame.isWordsMode() else _play_button).grab_focus()


# fenêtre des paramètres : difficulté, clavier, langue, précision pour passer un
# niveau, tutoriel avant le niveau 1, bruitages et musique
func _on_settings_button_pressed():
	_settings_panel.visible = true
	_difficulty.grab_focus()


func _on_back_button_pressed():
	_settings_panel.visible = false
	_settings_button.grab_focus()


func _unhandled_input(event):
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel.visible:
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()
	elif _level_panel.visible:
		_on_level_back_button_pressed()
		get_viewport().set_input_as_handled()


# 0 : Oui, 1 : Non
func _on_tutorial_item_selected(index: int):
	GlobalGame.setTutorialEnabled(index == 0)


# 0 : Oui, 1 : Non
func _on_sound_item_selected(index: int):
	GlobalGame.setSoundEnabled(index == 0)


# 0 : Oui, 1 : Non
func _on_music_item_selected(index: int):
	GlobalGame.setMusicEnabled(index == 0)


func _on_required_accuracy_item_selected(index: int):
	GlobalGame.setRequiredAccuracy(GlobalGame.REQUIRED_ACCURACY_CHOICES[index])


func _on_difficulty_item_selected(index: int):
	GlobalGame.loadDifficulty(index)


func _on_layout_item_selected(index: int):
	GlobalGame.loadKeyboardLayout(index)


# textes composés dans le code : les autres se traduisent seuls au changement de langue
func _refresh_texts():
	_training_best.text = tr("MODE_BEST") % GlobalGame.getHighestScore(GlobalGame.GAME_MODE.LEARN)
	_arcade_best.text = tr("MODE_BEST") % GlobalGame.getHighestScore(GlobalGame.GAME_MODE.WORDS)


func _on_language_item_selected(index: int):
	GlobalGame.loadLanguage(GlobalGame.LANGUAGES[index])
	_refresh_texts()


func _on_quit_button_pressed():
	get_tree().quit()
