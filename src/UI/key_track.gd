extends Control

# Piste de touches en bas de l'écran, façon jeu de rythme : chaque tuile glisse
# en continu vers la ligne de frappe (à gauche) au rythme de l'approche de son
# ennemi ; une tuile sur la ligne est à portée de coup.

signal key_validated(key: String)
signal key_missed(key: String)
signal key_too_early(key: String)

const TILE_SIZE := Vector2(24, 24)
const TILE_SPACING := 27.0
const TILE_Y := 3.0
const TILE_FONT_SIZE := 10
# ligne de frappe : position x des tuiles dont l'ennemi est à portée
const HIT_X := 13.0
# pixels de piste par pixel de distance entre le joueur et l'ennemi
const LANE_SCALE := 0.9
# vitesse de glissement des tuiles vers leur position (plus grand = plus vif)
const SLIDE_SHARPNESS := 14.0

# fond de tuile = couleur du doigt assombrie, bordure = couleur du doigt
const TILE_DARKEN := 0.2
const COLOR_CURRENT := Color.WHITE
const COLOR_WRONG := Color(0.85, 0.1, 0.2)
const COLOR_GOOD := Color(0.3, 0.9, 0.4)
const COLOR_TOO_EARLY := Color(1, 0.6, 0.15)
# cadre cible autour de l'emplacement de frappe (comme les récepteurs des jeux de rythme)
const COLOR_HIT_TARGET := Color(1, 1, 1, 0.35)
const COLOR_HIT_TARGET_ACTIVE := Color(0.3, 0.9, 0.4, 0.9)

# éclats autour d'une tuile validée
const BURST_COUNT := 8
const BURST_DISTANCE := 24.0
const BURST_SIZE := Vector2(3, 3)

@onready var _tiles_container: Control = $Tiles
@onready var _hit_target_style: StyleBoxFlat = $HitTarget.get_theme_stylebox("panel")

# [{node, enemy, key}]
var _tiles: Array = []
var _player = null


func set_player(player):
	_player = player


func _process(delta):
	var previous_x = -INF
	var previous_enemy = null
	var weight = 1.0 - exp(-SLIDE_SHARPNESS * delta)
	for tile_data in _tiles:
		var tile: Panel = tile_data.node
		var target_x = HIT_X
		if _player and is_instance_valid(tile_data.enemy):
			target_x += max(0.0, _player.distance_to_hit(tile_data.enemy)) * LANE_SCALE
		# les touches d'un même ennemi se suivent ; les tuiles ne se chevauchent jamais
		if tile_data.enemy == previous_enemy:
			target_x = previous_x + TILE_SPACING
		target_x = max(target_x, previous_x + TILE_SPACING)
		tile.position.x = lerp(tile.position.x, target_x, weight)
		previous_x = target_x
		previous_enemy = tile_data.enemy

	var in_range = not _tiles.is_empty() and get_current_distance() <= 0
	_hit_target_style.border_color = COLOR_HIT_TARGET_ACTIVE if in_range else COLOR_HIT_TARGET


# touche à taper : {key, enemy} ou {} s'il n'y en a pas
func get_current() -> Dictionary:
	return _tiles[0] if not _tiles.is_empty() else {}


func get_next_key() -> String:
	return _tiles[1].key if _tiles.size() > 1 else ""


# distance entre la zone de frappe et l'ennemi de la touche à taper
func get_current_distance() -> float:
	if _tiles.is_empty() or not _player or not is_instance_valid(_tiles[0].enemy):
		return INF
	return _player.distance_to_hit(_tiles[0].enemy)


func add_enemy(enemy: Enemy):
	for key in enemy.keys:
		var tile = _create_tile(key)
		tile.position = Vector2(size.x + 10, TILE_Y)
		_tiles_container.add_child(tile)
		_tiles.append({"node": tile, "enemy": enemy, "key": key})
	_refresh_current()


# la première touche vient d'être tapée correctement : la tuile passe au vert,
# grossit, s'envole au-dessus de la bande et projette des éclats
func pop_key():
	if _tiles.is_empty():
		return
	var tile_data = _tiles.pop_front()
	var tile: Panel = tile_data.node
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
	_refresh_current()
	key_validated.emit(tile_data.key)


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
	key_too_early.emit(_tiles[0].key)


# l'ennemi a disparu : on retire ses touches
func remove_enemy(enemy: Enemy):
	for tile_data in _tiles.duplicate():
		if tile_data.enemy == enemy:
			_tiles.erase(tile_data)
			var tile = tile_data.node
			var tween = tile.create_tween()
			tween.tween_property(tile, "modulate", Color(1, 0, 0, 0), 0.25)
			tween.tween_callback(tile.queue_free)
	_refresh_current()


# mauvaise touche : la tuile tremble (rotation, la position x suit la piste)
func wrong_key():
	if _tiles.is_empty():
		return
	var tile: Panel = _tiles[0].node
	tile.pivot_offset = TILE_SIZE / 2
	tile.get_theme_stylebox("panel").border_color = COLOR_WRONG
	var tween = tile.create_tween()
	for angle in [-0.3, 0.3, -0.2, 0.2, 0.0]:
		tween.tween_property(tile, "rotation", angle, 0.03)
	tween.tween_callback(_refresh_current)
	key_missed.emit(_tiles[0].key)


func clear():
	for tile_data in _tiles:
		tile_data.node.queue_free()
	_tiles.clear()


func _create_tile(key: String) -> Panel:
	var tile := Panel.new()
	tile.size = TILE_SIZE
	var style := StyleBoxFlat.new()
	var finger_color = GlobalLessons.get_key_color(key)
	style.bg_color = finger_color.darkened(TILE_DARKEN)
	style.border_color = finger_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	tile.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = key.to_upper()
	label.add_theme_font_size_override("font_size", TILE_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ancré sur toute la tuile et agrandi des deux côtés si la police dépasse :
	# le texte reste centré
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	tile.add_child(label)
	return tile


func _refresh_current():
	for i in _tiles.size():
		var tile: Panel = _tiles[i].node
		var style: StyleBoxFlat = tile.get_theme_stylebox("panel")
		style.border_color = COLOR_CURRENT if i == 0 else GlobalLessons.get_key_color(_tiles[i].key)
		style.set_border_width_all(3 if i == 0 else 2)
