extends Panel

# Bilan affiché à la fin d'un niveau : précision, bonnes touches, erreurs et
# touches les plus ratées. Le niveau suivant n'est débloqué qu'au-delà de la
# précision demandée ; sinon le niveau est rejoué.

const COLOR_PASSED := Color(0.2, 0.76, 0.28)
const COLOR_RETRY := Color(0.95, 0.55, 0.15)

@onready var _title_label: Label = $VBoxContainer/TitleLabel
@onready var _accuracy_label: Label = $VBoxContainer/AccuracyLabel
@onready var _accuracy_bar: ProgressBar = $VBoxContainer/AccuracyBar
@onready var _required_marker: ColorRect = $VBoxContainer/AccuracyBar/RequiredMarker
@onready var _details_label: Label = $VBoxContainer/DetailsLabel
@onready var _missed_label: RichTextLabel = $VBoxContainer/MissedLabel
@onready var _result_label: Label = $VBoxContainer/ResultLabel
@onready var _continue_label: Label = $VBoxContainer/ContinueLabel

var _bar_fill: StyleBoxFlat
var _blink_tween: Tween


func _ready():
	visible = false
	modulate.a = 0
	_bar_fill = _accuracy_bar.get_theme_stylebox("fill").duplicate()
	_accuracy_bar.add_theme_stylebox_override("fill", _bar_fill)


# accuracy et required entre 0 et 1 ; missed_keys triées de la plus ratée à la moins ratée
func show_stats(passed: bool, accuracy: float, required: float, good: int, errors: int, missed_keys: Array):
	var color = COLOR_PASSED if passed else COLOR_RETRY
	_title_label.text = tr("STATS_LEVEL_PASSED") if passed else tr("STATS_LEVEL_RETRY")
	_title_label.add_theme_color_override("font_color", color)

	_accuracy_label.text = tr("STATS_ACCURACY") % roundi(accuracy * 100)
	_bar_fill.bg_color = color
	_accuracy_bar.value = 0
	# repère du seuil, ancré en proportion de la barre (indépendant de sa taille)
	_required_marker.anchor_left = required
	_required_marker.anchor_right = required
	_required_marker.offset_left = -1
	_required_marker.offset_right = 1

	_details_label.text = tr("STATS_GOOD_ERRORS") % [good, errors]

	if missed_keys.is_empty():
		_missed_label.text = "[center]%s[/center]" % tr("STATS_NO_MISSED_KEY")
	else:
		var keys_text := ""
		for key in missed_keys:
			keys_text += "[color=#%s]%s[/color] " % [GlobalLessons.get_key_color(key).to_html(false), key.to_upper()]
		_missed_label.text = "[center]%s[/center]" % (tr("STATS_MISSED_KEYS") % keys_text.strip_edges())

	_result_label.text = tr("STATS_NEXT_LEVEL") if passed else tr("STATS_REQUIRED") % roundi(required * 100)
	_continue_label.text = tr("STATS_CONTINUE")
	_continue_label.modulate.a = 0

	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(_accuracy_bar, "value", accuracy * 100, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# l'invitation à continuer n'apparaît qu'une fois le bilan affiché
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_continue_label, "modulate:a", 1.0, 0.4)
	_blink_tween.tween_property(_continue_label, "modulate:a", 0.3, 0.4)


func hide_stats():
	if _blink_tween:
		_blink_tween.kill()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false
