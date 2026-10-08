extends CanvasLayer

signal resume_requested
signal menu_requested

const COLOR_NEW_KEY := "#ff9a3c"

@onready var key_track = $KeyTrack
@onready var keyboard_overlay = $KeyboardOverlay

@onready var _life_bar: ProgressBar = $LifeBar
@onready var _score_label: Label = $ScoreLabel
@onready var _combo_label: Label = $ComboLabel
@onready var _level_label: Label = $LevelLabel
@onready var _level_progress: ProgressBar = $LevelProgress
@onready var _keys_label: RichTextLabel = $KeysLabel
@onready var _banner: Control = $Banner
@onready var _banner_title: Label = $Banner/Title
@onready var _banner_subtitle: Label = $Banner/Subtitle
@onready var _pause_panel: Control = $PausePanel
@onready var _resume_button: Button = $PausePanel/VBoxContainer/ResumeButton


func _ready():
	GlobalEvents.player_health_changed.connect(_on_player_health_changed)
	GlobalEvents.score_changed.connect(_on_score_changed)
	GlobalEvents.combo_changed.connect(_on_combo_changed)

	_life_bar.max_value = GlobalPlayer.get_max_life()
	_life_bar.value = GlobalPlayer.get_life()
	_on_score_changed(GlobalPlayer.get_score())
	_on_combo_changed(GlobalPlayer.get_combo())
	_banner.modulate.a = 0
	_pause_panel.visible = false


func set_level(level: int, keys: Array, new_keys: Array):
	_level_label.text = "Niveau %d" % level
	var text := ""
	for key in keys:
		var letter = key.to_upper()
		if new_keys.has(key):
			letter = "[color=%s]%s[/color]" % [COLOR_NEW_KEY, letter]
		text += letter + " "
	_keys_label.text = "[right]%s[/right]" % text.strip_edges()


func set_level_progress(killed: int, needed: int):
	_level_progress.max_value = needed
	var tween = create_tween()
	tween.tween_property(_level_progress, "value", killed, 0.2)


func show_banner(title: String, subtitle: String, duration := 2.5):
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	var tween = create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	await tween.finished


func set_paused(paused: bool):
	_pause_panel.visible = paused
	if paused:
		_resume_button.grab_focus()


func _on_player_health_changed(new_value):
	var tween = create_tween()
	tween.tween_property(_life_bar, "value", new_value, 0.25)


func _on_score_changed(new_value):
	_score_label.text = str(new_value)


func _on_combo_changed(new_value):
	_combo_label.visible = new_value >= 5
	_combo_label.text = "combo %d  x%d" % [new_value, GlobalPlayer.get_multiplier()]


func _on_resume_button_pressed():
	resume_requested.emit()


func _on_menu_button_pressed():
	menu_requested.emit()
