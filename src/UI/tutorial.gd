extends Control

# Tutoriel affiché avant le niveau 1 : où et comment poser les mains.
# 4 pages illustrées (touches zoomées et mains en pixel art), navigation avec
# Suivant (Espace / Entrée) et Passer (bouton ou Échap).

signal finished

const PAGES := [
	{"title": "TUTO_BUMPS_TITLE", "text": "TUTO_BUMPS_TEXT", "scene": "bumps"},
	{"title": "TUTO_HOME_TITLE", "text": "TUTO_HOME_TEXT", "scene": "home"},
	{"title": "TUTO_COLORS_TITLE", "text": "TUTO_COLORS_TEXT", "scene": "colors"},
	{"title": "TUTO_PLAY_TITLE", "text": "TUTO_PLAY_TEXT", "scene": "play"},
]

const HAND_LEFT := preload("res://src/UI/Hands/hand-left.png")
const HAND_RIGHT := preload("res://src/UI/Hands/hand-right.png")
const POINTER_LEFT := preload("res://src/UI/Hands/pointer-left.png")
const POINTER_RIGHT := preload("res://src/UI/Hands/pointer-right.png")
const WOLF := preload("res://src/Actors/Players/Player/player-attacking-02.png")
const ANT := preload("res://src/Actors/Enemies/Ant/ant-walking.png")

# géométrie des mains (voir tools/generate_tutorial_hands.py) : doigts espacés de
# 20 px, affichées en x2 pour tomber sur des touches espacées de 40 px
const HAND_SCALE := 2
# centres de l'auriculaire et de l'index de la main gauche dans l'image (la main
# droite en est le miroir)
const HAND_PINKY_X := 9.5
const HAND_INDEX_X := 69.5
const HAND_INDEX_TIP_Y := 4.0

# zone d'illustration
const STAGE_TOP := 74.0
const HOME_KEY_SIZE := 36.0
const HOME_KEY_STEP := 40.0

const COLOR_DIM := Color(0.02, 0.03, 0.08, 0.95)
const COLOR_BUMP := Color(1, 1, 1, 0.95)
const COLOR_HIGHLIGHT := Color(1, 1, 1)
const COLOR_RING := Color(0.3, 0.9, 0.4)

@onready var _title: Label = $Title
@onready var _text: Label = $Text
@onready var _next_button: Button = $NextButton
@onready var _skip_button: Button = $SkipButton
@onready var _hint: Label = $Hint

var _page := 0
var _time := 0.0
var _key_style := StyleBoxFlat.new()


func _ready():
	visible = false
	_key_style.set_corner_radius_all(4)
	_next_button.pressed.connect(_next)
	_skip_button.pressed.connect(_close)


func run():
	_page = 0
	visible = true
	_show_page()
	await finished


func _process(delta):
	if not visible:
		return
	_time += delta
	queue_redraw()


func _unhandled_input(event):
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		GlobalAudio.play("click")
		_next()
	elif event.keycode == KEY_ESCAPE:
		GlobalAudio.play("click")
		_close()
	get_viewport().set_input_as_handled()


func _next():
	if _page >= PAGES.size() - 1:
		_close()
		return
	_page += 1
	_show_page()


func _close():
	if not visible:
		return
	visible = false
	finished.emit()


func _show_page():
	var page = PAGES[_page]
	_title.text = tr(page.title)
	_text.text = tr(page.text)
	_next_button.text = tr("GO") if _page == PAGES.size() - 1 else tr("TUTO_NEXT")
	_skip_button.text = tr("TUTO_SKIP")
	_hint.text = tr("TUTO_HINT")
	_time = 0.0
	queue_redraw()


func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM)
	_draw_page_dots()
	match PAGES[_page].scene:
		"bumps":
			_draw_bumps()
		"home":
			_draw_home()
		"colors":
			_draw_colors()
		"play":
			_draw_play()


# --- pages ---

# touches F et J zoomées avec leur ergot ; les mains « curseur » viennent le toucher
func _draw_bumps():
	var key_size = 64.0
	var top = STAGE_TOP + 6
	var centers = [size.x / 2 - 56, size.x / 2 + 56]
	var letters = ["f", "j"]
	var pulse = 0.5 + 0.5 * sin(_time * 5)
	for i in 2:
		var rect = Rect2(centers[i] - key_size / 2, top, key_size, key_size)
		_draw_key(letters[i], rect, 24, true)
		# halo qui pulse autour de l'ergot
		var bump_center = Vector2(centers[i], rect.end.y - 14)
		draw_arc(bump_center, 9 + pulse * 3, 0, TAU, 32, Color(COLOR_RING, 0.4 + 0.6 * pulse), 2)
	# les index viennent tapoter l'ergot
	var bob = 4.0 * abs(sin(_time * 3))
	var pointer_scale = 3.0
	var tip_y = top + key_size - 12 + bob
	draw_texture_rect(POINTER_LEFT, Rect2(Vector2(centers[0] - 10.0 * pointer_scale, tip_y), POINTER_LEFT.get_size() * pointer_scale), false)
	draw_texture_rect(POINTER_RIGHT, Rect2(Vector2(centers[1] - 5.0 * pointer_scale, tip_y), POINTER_RIGHT.get_size() * pointer_scale), false)


# rangée de repos zoomée, les deux mains posées dessus, pouces sur la barre d'espace
func _draw_home():
	var row = _home_row()
	var x0 = (size.x - (row.length() * HOME_KEY_STEP - (HOME_KEY_STEP - HOME_KEY_SIZE))) / 2
	var pulse = 0.5 + 0.5 * sin(_time * 5)
	# barre d'espace sous les pouces, entre les deux mains
	var space_rect = Rect2(x0 + 3 * HOME_KEY_STEP, STAGE_TOP + 112, 4 * HOME_KEY_STEP - 4, 18)
	_key_style.bg_color = Color(0.164706, 0.172549, 0.4)
	_key_style.border_color = Color(0.34, 0.39, 0.73)
	_key_style.set_border_width_all(2)
	draw_style_box(_key_style, space_rect)
	for i in row.length():
		var key = row[i]
		var rect = Rect2(x0 + i * HOME_KEY_STEP, STAGE_TOP, HOME_KEY_SIZE, HOME_KEY_SIZE)
		_draw_key(key, rect, 12, key == "f" or key == "j")
		if key == "f" or key == "j":
			draw_rect(rect.grow(3), Color(COLOR_HIGHLIGHT, 0.3 + 0.7 * pulse), false, 2)
	# bouts des doigts au bas des touches (les lettres restent lisibles)
	var hand_y = STAGE_TOP + HOME_KEY_SIZE - 4 - HAND_INDEX_TIP_Y * HAND_SCALE
	var key_center = func(i): return x0 + i * HOME_KEY_STEP + HOME_KEY_SIZE / 2
	var left_x = key_center.call(0) - HAND_PINKY_X * HAND_SCALE
	var right_x = key_center.call(6) - (HAND_RIGHT.get_width() - 1 - HAND_INDEX_X) * HAND_SCALE
	draw_texture_rect(HAND_LEFT, Rect2(Vector2(left_x, hand_y), HAND_LEFT.get_size() * HAND_SCALE), false)
	draw_texture_rect(HAND_RIGHT, Rect2(Vector2(right_x, hand_y), HAND_RIGHT.get_size() * HAND_SCALE), false)


# clavier complet coloré par doigt (et nuancé par rangée)
func _draw_colors():
	var key_size = 30.0
	var step = 34.0
	var row_offsets = [0.0, 8.0, 24.0]
	var rows = GlobalLessons.get_keyboard_rows()
	var x0 = (size.x - 10 * step - 8) / 2
	for r in rows.size():
		for i in rows[r].length():
			var rect = Rect2(x0 + row_offsets[r] + i * step, STAGE_TOP + 4 + r * step, key_size, key_size)
			_draw_key(rows[r][i], rect, 10, rows[r][i] == "f" or rows[r][i] == "j")
	# légende : main gauche / main droite
	var font = get_theme_default_font()
	var legend_y = STAGE_TOP + 4 + 3 * step + 14
	var left_color = GlobalLessons.FINGER_COLORS["index gauche"]
	var right_color = GlobalLessons.FINGER_COLORS["index droit"]
	_draw_centered_text(font, tr("TUTO_LEFT_HAND"), Vector2(size.x / 2 - 90, legend_y), 8, left_color)
	_draw_centered_text(font, tr("TUTO_RIGHT_HAND"), Vector2(size.x / 2 + 90, legend_y), 8, right_color)


# le héros face à un ennemi, la touche qui tombe au centre
func _draw_play():
	var ground_y = STAGE_TOP + 128
	var wolf_frame = Rect2(64, 0, 64, 64)
	var ant_frame = Rect2(0, 0, 64, 64)
	draw_texture_rect_region(WOLF, Rect2(size.x / 2 - 150, ground_y - 128, 128, 128), wolf_frame)
	# l'ennemi regarde vers la gauche
	draw_set_transform(Vector2(size.x / 2 + 150, ground_y - 128), 0, Vector2(-2, 2))
	draw_texture_rect_region(ANT, Rect2(0, 0, 64, 64), ant_frame)
	draw_set_transform(Vector2.ZERO)
	# la touche tombe puis rebondit, l'anneau se resserre
	var cycle = fmod(_time, 1.6)
	var fall = clamp(cycle / 0.35, 0.0, 1.0)
	var key_size = 40.0
	var center = Vector2(size.x / 2, STAGE_TOP + 46 - (1.0 - fall * fall) * 40)
	var ring = lerp(40.0, key_size / 2 + 4, clamp((cycle - 0.35) / 1.0, 0.0, 1.0))
	draw_arc(center, ring, 0, TAU, 48, COLOR_RING, 2)
	_draw_key("f", Rect2(center - Vector2.ONE * key_size / 2, Vector2.ONE * key_size), 16, false)


# --- dessin ---

# indicateur de page : un point par page, plein pour la page en cours
func _draw_page_dots():
	var spacing = 12.0
	var y = size.y - 26
	var x0 = size.x / 2 - (PAGES.size() - 1) * spacing / 2
	for i in PAGES.size():
		var center = Vector2(x0 + i * spacing, y)
		if i == _page:
			draw_circle(center, 3.5, Color(1, 0.823529, 0.247059))
		else:
			draw_arc(center, 3, 0, TAU, 16, Color(1, 1, 1, 0.6), 1.5)

func _home_row() -> String:
	var row: String = GlobalLessons.get_keyboard_rows()[1]
	# en QWERTY, l'auriculaire droit se pose sur « ; »
	return row if row.length() >= 10 else row + ";"


# touche au style du jeu : fond = couleur du doigt assombrie, bordure = couleur du doigt
func _draw_key(key: String, rect: Rect2, font_size: int, with_bump: bool):
	var color = GlobalLessons.get_key_color(key) if key != ";" else GlobalLessons.FINGER_COLORS["auriculaire droit"]
	_key_style.bg_color = color.darkened(0.2)
	_key_style.border_color = color
	_key_style.set_border_width_all(2 if rect.size.x < 50 else 3)
	draw_style_box(_key_style, rect)
	var font = get_theme_default_font()
	_draw_centered_text(font, key.to_upper(), rect.get_center() - Vector2(0, rect.size.y * 0.08), font_size, Color.WHITE)
	if with_bump:
		# petit ergot en relief sous la lettre
		var bump = Rect2(rect.get_center().x - rect.size.x * 0.16, rect.end.y - rect.size.y * 0.22, rect.size.x * 0.32, max(2.0, rect.size.y * 0.06))
		draw_rect(bump.grow(1), Color(0, 0, 0, 0.6))
		draw_rect(bump, COLOR_BUMP)


func _draw_centered_text(font: Font, text: String, center: Vector2, font_size: int, color: Color):
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	var pos = Vector2(center.x - text_size.x / 2, baseline)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
