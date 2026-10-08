extends Control

@export var mainLevel: PackedScene

@onready var _play_button: Button = $Menu/PlayButton
@onready var _difficulty: OptionButton = $Menu/Difficulty
@onready var _layout: OptionButton = $Menu/Layout
@onready var _best_score_label: Label = $BestScoreLabel
@onready var _enemy: Enemy = $Ant


func _ready():
	get_tree().paused = false

	# l'ennemi du menu sert de décor : il ne doit pas avancer
	_enemy.set_physics_process(false)
	_enemy.setup(["f", "j"], 0, 1)

	_difficulty.select(GlobalGame.getLevelDifficulty())
	_layout.select(GlobalGame.getKeyboardLayout())
	_best_score_label.text = "Meilleur score : %d" % GlobalGame.getHighestScore()
	_play_button.grab_focus()


func _on_play_button_pressed():
	GlobalGame.resetGame()
	GlobalTransition.change_scene_to_packed(mainLevel)


func _on_difficulty_item_selected(index: int):
	GlobalGame.loadDifficulty(index)


func _on_layout_item_selected(index: int):
	GlobalGame.loadKeyboardLayout(index)


func _on_quit_button_pressed():
	get_tree().quit()
