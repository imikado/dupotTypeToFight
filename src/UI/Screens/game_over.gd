extends Control

@export_file("*.tscn") var level_scene_path: String
@export_file("*.tscn") var menu_scene_path: String

@onready var _score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var _stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var _record_label: Label = $Panel/VBoxContainer/RecordLabel
@onready var _replay_button: Button = $Panel/VBoxContainer/HBoxContainer/ReplayButton


func _ready():
	# le premier plan du décor passerait devant la fenêtre
	$Background/Foreground.visible = false
	var score = GlobalPlayer.get_score()
	_stats_label.text = tr("GAME_OVER_STATS") % [
		GlobalGame.getLevel(), GlobalPlayer.get_killed(), GlobalPlayer.get_best_combo()
	]
	_record_label.visible = score > 0 and score >= GlobalGame.getHighestScore()
	if _record_label.visible:
		GlobalAudio.play("record")
	# on rejoue le niveau perdu autant de fois qu'on veut, sans repartir du niveau 1
	_replay_button.text = tr("RETRY_LEVEL") % GlobalGame.getLevel()

	var tween = create_tween()
	tween.tween_method(_set_score_text, 0, score, 1.0)
	_replay_button.grab_focus()


func _set_score_text(scoreValue: int):
	_score_label.text = str(scoreValue)


func _on_replay_button_pressed():
	GlobalGame.resetGame(GlobalGame.getLevel(), true)
	GlobalTransition.change_scene_to_packed(load(level_scene_path))


func _on_menu_button_pressed():
	GlobalTransition.change_scene_to_packed(load(menu_scene_path))
