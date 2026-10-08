extends Control

@export var mainLevel: PackedScene
@export_file("*.tscn") var tutorial_scene_path: String

@onready var _play_button: Button = $Menu/PlayButton
@onready var _settings_button: Button = $Menu/SettingsButton
@onready var _settings_panel: Control = $SettingsPanel
@onready var _difficulty: OptionButton = $SettingsPanel/VBoxContainer/Grid/Difficulty
@onready var _layout: OptionButton = $SettingsPanel/VBoxContainer/Grid/Layout
@onready var _language: OptionButton = $SettingsPanel/VBoxContainer/Grid/Language
@onready var _required_accuracy: OptionButton = $SettingsPanel/VBoxContainer/Grid/RequiredAccuracy
@onready var _tutorial: OptionButton = $SettingsPanel/VBoxContainer/Grid/Tutorial
@onready var _best_score_label: Label = $BestScoreLabel
@onready var _quit_button: Button = $Menu/QuitButton
@onready var _enemy: Enemy = $Ant


func _ready():
	get_tree().paused = false
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
	_settings_panel.visible = false
	_refresh_texts()
	_play_button.grab_focus()


func _on_play_button_pressed():
	GlobalGame.resetGame()
	# tutoriel sur la position des mains avant le niveau 1, sauf s'il est désactivé
	if GlobalGame.isTutorialEnabled():
		GlobalTransition.change_scene_to_packed(load(tutorial_scene_path))
	else:
		GlobalTransition.change_scene_to_packed(mainLevel)


# fenêtre des paramètres : difficulté, clavier, langue, précision pour passer un
# niveau, tutoriel avant le niveau 1
func _on_settings_button_pressed():
	_settings_panel.visible = true
	_difficulty.grab_focus()


func _on_back_button_pressed():
	_settings_panel.visible = false
	_settings_button.grab_focus()


func _unhandled_input(event):
	if _settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()


# 0 : Oui, 1 : Non
func _on_tutorial_item_selected(index: int):
	GlobalGame.setTutorialEnabled(index == 0)


func _on_required_accuracy_item_selected(index: int):
	GlobalGame.setRequiredAccuracy(GlobalGame.REQUIRED_ACCURACY_CHOICES[index])


func _on_difficulty_item_selected(index: int):
	GlobalGame.loadDifficulty(index)


func _on_layout_item_selected(index: int):
	GlobalGame.loadKeyboardLayout(index)


# textes composés dans le code : les autres se traduisent seuls au changement de langue
func _refresh_texts():
	_best_score_label.text = tr("MENU_BEST_SCORE") % GlobalGame.getHighestScore()


func _on_language_item_selected(index: int):
	GlobalGame.loadLanguage(GlobalGame.LANGUAGES[index])
	_refresh_texts()


func _on_quit_button_pressed():
	get_tree().quit()
