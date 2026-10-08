extends Control

# Bande de touches en bas de l'écran : affiche, dans l'ordre d'arrivée,
# les touches à taper pour vaincre les ennemis présents.

const TILE_SIZE := Vector2(20, 20)
const TILE_SPACING := 24.0
const GROUP_SPACING := 10.0
const START_X := 12.0
const TILE_Y := 8.0

# fond de tuile = couleur du doigt assombrie, bordure = couleur du doigt
const TILE_DARKEN := 0.45
const COLOR_CURRENT := Color.WHITE
const COLOR_WRONG := Color(0.85, 0.1, 0.2)
const COLOR_GOOD := Color(0.3, 0.9, 0.4)
const COLOR_TOO_EARLY := Color(1, 0.6, 0.15)

# éclats autour d'une tuile validée
const BURST_COUNT := 8
const BURST_DISTANCE := 24.0
const BURST_SIZE := Vector2(3, 3)

@onready var _tiles_container: Control = $Tiles

# [{node, enemy, key}]
var _tiles: Array = []


func add_enemy(enemy: Enemy):
	for key in enemy.keys:
		var tile = _create_tile(key)
		tile.position = Vector2(size.x + 10, TILE_Y)
		_tiles_container.add_child(tile)
		_tiles.append({"node": tile, "enemy": enemy, "key": key})
	_layout()


# la première touche vient d'être tapée correctement : la tuile passe au vert,
# grossit, s'envole au-dessus de la bande et projette des éclats
func pop_key():
	if _tiles.is_empty():
		return
	var tile: Panel = _tiles.pop_front().node
	# hors du conteneur qui découpe son contenu, pour pouvoir sortir de la bande
	tile.reparent(self)
	tile.z_index = 1
	tile.pivot_offset = TILE_SIZE / 2
	var style: StyleBoxFlat = tile.get_theme_stylebox("panel")
	style.bg_color = COLOR_GOOD
	style.border_color = Color.WHITE
	style.set_border_width_all(2)

	var tween = tile.create_tween()
	tween.tween_property(tile, "scale", Vector2(1.7, 1.7), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", Vector2(1.3, 1.3), 0.08)
	tween.set_parallel()
	tween.tween_property(tile, "position:y", tile.position.y - 22, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "modulate:a", 0.0, 0.25).set_delay(0.1)
	tween.chain().tween_callback(tile.queue_free)

	_burst(tile.position + TILE_SIZE / 2)
	_layout()


func _burst(center: Vector2):
	for i in BURST_COUNT:
		var spark := ColorRect.new()
		spark.size = BURST_SIZE
		spark.color = COLOR_GOOD.lightened(0.4)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.position = center - BURST_SIZE / 2
		spark.z_index = 1
		add_child(spark)
		var direction = Vector2.RIGHT.rotated(TAU * i / BURST_COUNT)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "position", spark.position + direction * BURST_DISTANCE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.25).set_delay(0.15)
		tween.chain().tween_callback(spark.queue_free)


# bonne touche mais ennemi hors de portée : la tuile sautille en orange
func too_early():
	if _tiles.is_empty():
		return
	var tile: Panel = _tiles[0].node
	var style: StyleBoxFlat = tile.get_theme_stylebox("panel")
	style.border_color = COLOR_TOO_EARLY
	var tween = tile.create_tween()
	tween.tween_property(tile, "position:y", TILE_Y - 5, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "position:y", TILE_Y, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_callback(_refresh_current)


# l'ennemi a disparu (il a atteint le joueur) : on retire ses touches
func remove_enemy(enemy: Enemy):
	for tile_data in _tiles.duplicate():
		if tile_data.enemy == enemy:
			_tiles.erase(tile_data)
			var tile = tile_data.node
			var tween = tile.create_tween()
			tween.tween_property(tile, "modulate", Color(1, 0, 0, 0), 0.25)
			tween.tween_callback(tile.queue_free)
	_layout()


func wrong_key():
	if _tiles.is_empty():
		return
	var tile: Panel = _tiles[0].node
	var base_x = tile.position.x
	var tween = tile.create_tween()
	tile.get_theme_stylebox("panel").border_color = COLOR_WRONG
	for offset in [-3, 3, -2, 2, 0]:
		tween.tween_property(tile, "position:x", base_x + offset, 0.03)
	tween.tween_callback(_refresh_current)


func clear():
	for tile_data in _tiles:
		tile_data.node.queue_free()
	_tiles.clear()
	_layout()


func _create_tile(key: String) -> Panel:
	var tile := Panel.new()
	tile.size = TILE_SIZE
	var style := StyleBoxFlat.new()
	var finger_color = GlobalLessons.get_finger_color(key)
	style.bg_color = finger_color.darkened(TILE_DARKEN)
	style.border_color = finger_color
	style.set_border_width_all(1)
	tile.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = key.to_upper()
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.add_child(label)
	return tile


func _layout():
	var x = START_X
	var previous_enemy = null
	for i in _tiles.size():
		var tile_data = _tiles[i]
		if previous_enemy != null and tile_data.enemy != previous_enemy:
			x += GROUP_SPACING
		previous_enemy = tile_data.enemy
		var tile: Panel = tile_data.node
		var tween = tile.create_tween()
		tween.tween_property(tile, "position", Vector2(x, TILE_Y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		x += TILE_SPACING
	_refresh_current()


func _refresh_current():
	for i in _tiles.size():
		var tile: Panel = _tiles[i].node
		var style: StyleBoxFlat = tile.get_theme_stylebox("panel")
		style.border_color = COLOR_CURRENT if i == 0 else GlobalLessons.get_finger_color(_tiles[i].key)
		style.set_border_width_all(2 if i == 0 else 1)
