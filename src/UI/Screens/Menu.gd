extends Control

@export var mainLevel: PackedScene

@onready var _play_button: Button = $Menu/PlayButton
@onready var _difficulty: OptionButton = $Menu/Difficulty
@onready var _layout: OptionButton = $Menu/Layout
@onready var _language: OptionButton = $Menu/Language
@onready var _best_score_label: Label = $BestScoreLabel
@onready var _enemy: Enemy = $Ant


func _ready():
	get_tree().paused = false
	# le premier plan du décor passerait devant les boutons
	$Background/Foreground.visible = false

	# l'ennemi du menu sert de décor : il ne doit pas avancer
	_enemy.set_physics_process(false)
	_enemy.setup(["f", "j"], null, 1)

	_difficulty.select(GlobalGame.getLevelDifficulty())
	_layout.select(GlobalGame.getKeyboardLayout())
	_language.select(GlobalGame.LANGUAGES.find(GlobalGame.getLanguage()))
	_refresh_texts()
	_play_button.grab_focus()


func _on_play_button_pressed():
	GlobalGame.resetGame()
	GlobalTransition.change_scene_to_packed(mainLevel)


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
