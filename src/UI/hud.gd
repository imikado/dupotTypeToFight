extends CanvasLayer

signal resume_requested
signal menu_requested

const COLOR_NEW_KEY := "#ff9a3c"

# couleur de la barre de vie selon la part de vie restante
const COLOR_LIFE_HIGH := Color(0.2, 0.76, 0.28)
const COLOR_LIFE_MEDIUM := Color(0.95, 0.55, 0.15)
const COLOR_LIFE_LOW := Color(0.85, 0.15, 0.25)
const LIFE_MEDIUM_RATIO := 0.6
const LIFE_LOW_RATIO := 0.3

@onready var key_track = $KeyTrack
@onready var keyboard_overlay = $KeyboardOverlay
@onready var level_stats = $LevelStats
@onready var _key_prompt = $KeyPrompt
@onready var _mini_keyboard = $MiniKeyboard
@onready var key_stats = $KeyStats
@onready var _keyboard_button: Button = $KeyboardButton

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

var _life_fill: StyleBoxFlat
# mode Arcade : interface allégée, sans la bande du bas
var _is_light := false


func _ready():
	GlobalEvents.player_health_changed.connect(_on_player_health_changed)
	GlobalEvents.score_changed.connect(_on_score_changed)
	GlobalEvents.combo_changed.connect(_on_combo_changed)

	_life_bar.max_value = GlobalPlayer.get_max_life()
	_life_bar.value = GlobalPlayer.get_life()
	# copie du style pour pouvoir changer sa couleur sans toucher à la ressource de la scène
	_life_fill = _life_bar.get_theme_stylebox("fill").duplicate()
	_life_bar.add_theme_stylebox_override("fill", _life_fill)
	_life_fill.bg_color = _get_life_color(GlobalPlayer.get_life())
	_on_score_changed(GlobalPlayer.get_score())
	_on_combo_changed(GlobalPlayer.get_combo())
	_banner.modulate.a = 0
	_key_prompt.setup(key_track)
	keyboard_overlay.set_key_track(key_track)
	_mini_keyboard.setup(key_track)
	_keyboard_button.button_pressed = GlobalGame.isKeyboardShown()
	_mini_keyboard.visible = GlobalGame.isKeyboardShown()
	_pause_panel.visible = false


# keys_text : texte affiché à la place de la liste des touches (mode Mots)
func set_level(level: int, keys: Array, new_keys: Array, keys_text := ""):
	_level_label.text = tr("LEVEL") % level
	_mini_keyboard.set_available_keys(keys)
	if not keys_text.is_empty():
		_keys_label.text = "[right]%s[/right]" % keys_text
		return
	var text := ""
	for key in keys:
		var letter = key.to_upper()
		if new_keys.has(key):
			letter = "[color=%s]%s[/color]" % [COLOR_NEW_KEY, letter]
		text += letter + " "
	_keys_label.text = "[right]%s[/right]" % text.strip_edges()


# mode triche activé : petit point vert dans le coin en haut à droite
func show_cheat_indicator():
	var dot := ColorRect.new()
	dot.color = Color(0.2, 0.9, 0.3)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -4
	dot.offset_top = 1
	dot.offset_right = -1
	dot.offset_bottom = 4
	add_child(dot)


func set_level_progress(killed: int, needed: int):
	_level_progress.max_value = needed
	var tween = create_tween()
	tween.tween_property(_level_progress, "value", killed, 0.2)


# la bannière reste affichée jusqu'à hide_banner()
func show_banner(title: String, subtitle: String):
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	var tween = create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.3)


func hide_banner():
	var tween = create_tween()
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	await tween.finished


func set_paused(paused: bool):
	_pause_panel.visible = paused
	if paused:
		_resume_button.grab_focus()


func _on_player_health_changed(new_value):
	var tween = create_tween().set_parallel()
	tween.tween_property(_life_bar, "value", new_value, 0.25)
	tween.tween_property(_life_fill, "bg_color", _get_life_color(new_value), 0.25)


func _get_life_color(life: float) -> Color:
	var ratio = life / _life_bar.max_value
	if ratio > LIFE_MEDIUM_RATIO:
		return COLOR_LIFE_HIGH
	if ratio > LIFE_LOW_RATIO:
		return COLOR_LIFE_MEDIUM
	return COLOR_LIFE_LOW


func _on_score_changed(new_value):
	_score_label.text = str(new_value)


func _on_combo_changed(new_value):
	_combo_label.visible = new_value >= 5
	_combo_label.text = "combo %d  x%d" % [new_value, GlobalPlayer.get_multiplier()]


# mode Arcade : on cache la bande du bas (bilan des touches, petit clavier, piste
# des touches) et on descend la grande touche et le clavier d'aide de offset
func set_light_layout(offset: float):
	_is_light = true
	key_stats.enabled = false
	key_stats.visible = false
	_mini_keyboard.visible = false
	_keyboard_button.visible = false
	# la piste continue de suivre les touches (la grande touche s'en sert), sans être vue
	key_track.visible = false
	_key_prompt.shift_y(offset)
	keyboard_overlay.y_offset = offset


# petit clavier permanent en bas de l'écran (bouton en haut ou touche Tab)
func toggle_keyboard():
	if _is_light:
		return
	_keyboard_button.button_pressed = not _keyboard_button.button_pressed


func _on_keyboard_button_toggled(pressed: bool):
	_mini_keyboard.visible = pressed
	GlobalGame.setKeyboardShown(pressed)


func _on_resume_button_pressed():
	resume_requested.emit()


func _on_menu_button_pressed():
	menu_requested.emit()
