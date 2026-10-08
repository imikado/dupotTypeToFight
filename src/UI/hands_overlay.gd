class_name HandsOverlay
extends Control

# Mains gauche et droite en pixel art, posées sur la rangée de repos
# (index sur F et J), affichées en transparence par-dessus le clavier.
# Un doigt peut être coloré pour indiquer lequel utiliser.

const TEXTURE_LEFT := preload("res://src/UI/Hands/hand-left.png")
const TEXTURE_RIGHT := preload("res://src/UI/Hands/hand-right.png")

# doigts de gauche à droite, avec leur touche de repos (index dans la rangée du milieu)
const FINGERS := [
	"auriculaire gauche", "annulaire gauche", "majeur gauche", "index gauche",
	"index droit", "majeur droit", "annulaire droit", "auriculaire droit",
]
const HOME_INDEX := [0, 1, 2, 3, 6, 7, 8, 9]

# géométrie de hand-left.png (hand-right.png en est le miroir) :
# centre de chaque doigt de l'auriculaire à l'index, haut du bout des doigts, haut de la paume
const IMAGE_FINGER_X := [7, 25, 43, 61]
const IMAGE_TIP_Y := [4, 1, 0, 1]
const IMAGE_PALM_Y := 28
const HIGHLIGHT_WIDTH := 8

const HANDS_ALPHA := 0.8
const HIGHLIGHT_ALPHA := 0.85

var _left_position := Vector2.ZERO
var _right_position := Vector2.ZERO
# nom du doigt -> rectangle du doigt (coordonnées locales)
var _finger_rects := {}
# nom du doigt -> couleur
var _highlights := {}


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# home_row_x(index) donne le centre horizontal d'une touche de la rangée de repos,
# tip_y la hauteur où poser le bout des doigts
func setup(home_row_x: Callable, tip_y: float):
	var width = TEXTURE_LEFT.get_width()
	_left_position = Vector2(roundi(home_row_x.call(HOME_INDEX[0]) - IMAGE_FINGER_X[0]), roundi(tip_y))
	# dans l'image miroir, l'index (dernier doigt de la main gauche) est le premier
	var right_index_x = width - 1 - IMAGE_FINGER_X[3]
	_right_position = Vector2(roundi(home_row_x.call(HOME_INDEX[4]) - right_index_x), roundi(tip_y))

	_finger_rects.clear()
	for i in 4:
		var left_x = _left_position.x + IMAGE_FINGER_X[i]
		var right_x = _right_position.x + width - 1 - IMAGE_FINGER_X[i]
		_finger_rects[FINGERS[i]] = _finger_rect(left_x, IMAGE_TIP_Y[i])
		_finger_rects[FINGERS[7 - i]] = _finger_rect(right_x, IMAGE_TIP_Y[i])

	custom_minimum_size = Vector2(_right_position.x + width, tip_y + TEXTURE_LEFT.get_height())
	queue_redraw()


func _finger_rect(center_x: float, tip: int) -> Rect2:
	return Rect2(
		center_x - HIGHLIGHT_WIDTH / 2,
		_left_position.y + tip + 1,
		HIGHLIGHT_WIDTH,
		IMAGE_PALM_Y - tip
	)


func set_highlights(highlights: Dictionary):
	_highlights = highlights
	queue_redraw()


func _draw():
	var hands_color = Color(1, 1, 1, HANDS_ALPHA)
	draw_texture(TEXTURE_LEFT, _left_position, hands_color)
	draw_texture(TEXTURE_RIGHT, _right_position, hands_color)

	for finger in _highlights:
		if not _finger_rects.has(finger):
			continue
		var color: Color = _highlights[finger]
		color.a = HIGHLIGHT_ALPHA
		draw_rect(_finger_rects[finger], color)
