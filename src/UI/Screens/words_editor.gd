extends Panel

# écran des paramètres pour modifier les mots du mode Arcade, taille par taille,
# dans la langue du jeu ; on peut aussi ajouter ou supprimer des tailles

signal closed

const LANGUAGE_NAMES := {"en": "English", "fr": "Français"}
# nombre de mots de mauvaise taille cités dans le message d'erreur
const ERROR_WORDS_SHOWN := 5

@onready var _title: Label = $VBoxContainer/Title
@onready var _sizes: OptionButton = $VBoxContainer/SizeRow/Sizes
@onready var _remove_button: Button = $VBoxContainer/SizeRow/RemoveButton
@onready var _new_size: SpinBox = $VBoxContainer/SizeRow/NewSize
@onready var _add_button: Button = $VBoxContainer/SizeRow/AddButton
@onready var _text: TextEdit = $VBoxContainer/Text
@onready var _info: Label = $VBoxContainer/InfoLabel
@onready var _error: Label = $VBoxContainer/ErrorLabel
@onready var _save_button: Button = $VBoxContainer/ButtonRow/SaveButton
@onready var _reset_button: Button = $VBoxContainer/ButtonRow/ResetButton
@onready var _back_button: Button = $VBoxContainer/ButtonRow/BackButton

var _length := 0
# bouton qui attend une seconde pression pour confirmer (suppression, réinitialisation)
var _confirm_button: Button


func _ready():
	_new_size.min_value = GlobalWords.EDIT_MIN_LENGTH
	_new_size.max_value = GlobalWords.EDIT_MAX_LENGTH
	_text.text_changed.connect(_on_text_changed)
	visible = false


func open():
	_title.text = tr("WORDS_TITLE") % LANGUAGE_NAMES.get(GlobalGame.getLanguage(), GlobalGame.getLanguage())
	var lengths = GlobalWords.get_all_lengths()
	_show_length(lengths[0] if not lengths.is_empty() else GlobalWords.MIN_LENGTH)
	visible = true
	_sizes.grab_focus()


func close():
	_save()
	_cancel_confirm()
	visible = false
	closed.emit()


func _show_length(length: int):
	_length = length
	_refresh_sizes()
	_text.text = " ".join(GlobalWords.get_list(length))
	_text.set_meta("dirty", false)
	_show_count()


func _refresh_sizes():
	_sizes.clear()
	var lengths = GlobalWords.get_all_lengths()
	for length in lengths:
		_sizes.add_item(tr("WORDS_SIZE_ITEM") % [length, GlobalWords.get_list(length).size()], length)
	_sizes.select(lengths.find(_length))
	_remove_button.disabled = lengths.size() <= 1
	_new_size.value = _next_free_length()


# première taille absente, pour proposer une nouvelle taille
func _next_free_length() -> int:
	var lengths = GlobalWords.get_all_lengths()
	for length in range(GlobalWords.EDIT_MIN_LENGTH, GlobalWords.EDIT_MAX_LENGTH + 1):
		if not lengths.has(length):
			return length
	return GlobalWords.EDIT_MAX_LENGTH


func _show_count(rejected: Array = []):
	var parsed = GlobalWords.parse_words(_text.text, _length)
	var count = parsed.words.size()
	var text = tr("WORDS_COUNT") % count if count > 0 else tr("WORDS_EMPTY")
	if not rejected.is_empty():
		text += "  -  " + tr("WORDS_REJECTED") % " ".join(rejected)
	_info.text = text
	_show_length_error(parsed.wrong_length)


# vérification pendant la saisie : on cite les premiers mots qui n'ont pas la taille choisie
func _show_length_error(wrong_length: Array):
	_error.visible = not wrong_length.is_empty()
	if wrong_length.is_empty():
		return
	var shown = ", ".join(wrong_length.slice(0, ERROR_WORDS_SHOWN))
	if wrong_length.size() > ERROR_WORDS_SHOWN:
		shown += " " + tr("WORDS_LENGTH_ERROR_MORE") % (wrong_length.size() - ERROR_WORDS_SHOWN)
	_error.text = tr("WORDS_LENGTH_ERROR") % [_length, shown]


# enregistre la taille affichée : les mots invalides ou de mauvaise taille sont écartés
func _save() -> Array:
	if _length == 0 or not _text.get_meta("dirty", false):
		return []
	var parsed = GlobalWords.parse_words(_text.text, _length)
	GlobalWords.set_words(_length, parsed.words)
	_text.text = " ".join(parsed.words)
	_text.set_meta("dirty", false)
	_refresh_sizes()
	return parsed.rejected


func _on_text_changed():
	_text.set_meta("dirty", true)
	_show_count()


func _on_sizes_item_selected(index: int):
	_cancel_confirm()
	_save()
	_show_length(_sizes.get_item_id(index))


func _on_save_button_pressed():
	_cancel_confirm()
	var rejected = _save()
	_show_count(rejected)
	if rejected.is_empty():
		_info.text += "  -  " + tr("WORDS_SAVED")


func _on_add_button_pressed():
	_cancel_confirm()
	_save()
	var length = int(_new_size.value)
	GlobalWords.add_length(length)
	_show_length(length)
	_text.grab_focus()


func _on_remove_button_pressed():
	if not _ask_confirm(_remove_button):
		return
	GlobalWords.remove_length(_length)
	_show_length(GlobalWords.get_all_lengths()[0])
	_sizes.grab_focus()


func _on_reset_button_pressed():
	if not _ask_confirm(_reset_button):
		return
	GlobalWords.reset_to_default()
	_show_length(GlobalWords.get_all_lengths()[0])
	_sizes.grab_focus()


# première pression : le bouton demande confirmation ; seconde : on valide
func _ask_confirm(button: Button) -> bool:
	if _confirm_button == button:
		_cancel_confirm()
		return true
	_cancel_confirm()
	_confirm_button = button
	button.set_meta("text", button.text)
	button.text = "WORDS_CONFIRM"
	return false


func _cancel_confirm():
	if _confirm_button:
		_confirm_button.text = _confirm_button.get_meta("text")
		_confirm_button = null


func _on_back_button_pressed():
	close()
