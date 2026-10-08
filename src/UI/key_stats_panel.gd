extends Control

# Bilan en direct (en bas à gauche) : pour chaque touche, le nombre de frappes
# réussies (vert) et d'erreurs (rouge) dans le niveau. S'il y a trop de touches,
# seules les dernières tapées sont montrées (dans un ordre stable, sans sauts).

const COLUMNS := 3
const MAX_ENTRIES := 6
const ENTRY_SIZE := Vector2(36, 15)
const TILE_SIZE := Vector2(12, 12)
const FONT_SIZE := 6
const COUNT_WIDTH := 10.0

const COLOR_OK := Color(0.3, 0.9, 0.4)
const COLOR_KO := Color(0.95, 0.3, 0.35)
const TILE_DARKEN := 0.2
const FLASH_DURATION := 0.35
const BACKGROUND_MARGIN := 2.0

# touche -> {ok, ko, order (première frappe), last (dernière frappe), flash, flash_color}
var _stats := {}
var _counter := 0
var _background := StyleBoxFlat.new()
var _tile_style := StyleBoxFlat.new()


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_background.bg_color = Color(0.0627451, 0.0862745, 0.2, 0.92)
	_background.border_color = Color(0.34, 0.39, 0.73)
	_background.set_border_width_all(1)
	_background.set_corner_radius_all(5)
	_tile_style.set_border_width_all(1)
	_tile_style.set_corner_radius_all(2)


func reset():
	_stats.clear()
	visible = false
	queue_redraw()


# ok : frappe réussie sur cette touche ; sinon erreur alors qu'elle était attendue
func record(key: String, ok: bool):
	_counter += 1
	if not _stats.has(key):
		_stats[key] = {"ok": 0, "ko": 0, "order": _counter}
	var entry = _stats[key]
	entry[("ok" if ok else "ko")] += 1
	entry.last = _counter
	entry.flash = FLASH_DURATION
	entry.flash_color = COLOR_OK if ok else COLOR_KO
	visible = true
	queue_redraw()


func _process(delta):
	var flashing = false
	for key in _stats:
		var entry = _stats[key]
		if entry.get("flash", 0.0) > 0:
			entry.flash = max(0.0, entry.flash - delta)
			flashing = true
	if flashing:
		queue_redraw()


# les dernières touches tapées, dans l'ordre de leur première frappe
func _get_shown_keys() -> Array:
	var keys = _stats.keys()
	keys.sort_custom(func(a, b): return _stats[a].last > _stats[b].last)
	keys = keys.slice(0, MAX_ENTRIES)
	keys.sort_custom(func(a, b): return _stats[a].order < _stats[b].order)
	return keys


func _draw():
	if _stats.is_empty():
		return
	draw_style_box(_background, Rect2(-Vector2.ONE * BACKGROUND_MARGIN, size + Vector2.ONE * BACKGROUND_MARGIN * 2))
	var font = get_theme_default_font()
	var keys = _get_shown_keys()
	for i in keys.size():
		var key: String = keys[i]
		var entry = _stats[key]
		var origin = Vector2((i % COLUMNS) * ENTRY_SIZE.x, (i / COLUMNS) * ENTRY_SIZE.y) + Vector2(2, 2)

		var finger_color = GlobalLessons.get_finger_color(key)
		_tile_style.bg_color = finger_color.darkened(TILE_DARKEN)
		_tile_style.border_color = finger_color
		var flash = entry.get("flash", 0.0)
		if flash > 0:
			_tile_style.border_color = entry.flash_color.lerp(finger_color, 1.0 - flash / FLASH_DURATION)
		var tile_rect = Rect2(origin, TILE_SIZE)
		draw_style_box(_tile_style, tile_rect)
		_draw_text(font, key.to_upper(), tile_rect, Color.WHITE)

		var counts_x = origin.x + TILE_SIZE.x + 2
		_draw_text(font, str(entry.ok), Rect2(counts_x, origin.y, COUNT_WIDTH, TILE_SIZE.y), COLOR_OK)
		_draw_text(font, str(entry.ko), Rect2(counts_x + COUNT_WIDTH, origin.y, COUNT_WIDTH, TILE_SIZE.y), COLOR_KO)


# texte centré dans un rectangle, avec un contour noir pour rester lisible
func _draw_text(font: Font, text: String, rect: Rect2, color: Color):
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline = rect.position.y + (rect.size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2
	var position_x = rect.position.x + (rect.size.x - text_size.x) / 2
	draw_string_outline(font, Vector2(position_x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color.BLACK)
	draw_string(font, Vector2(position_x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
