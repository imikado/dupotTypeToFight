extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export var game_over_scene: PackedScene
@export_file("*.tscn") var menu_scene_path: String

# positions à l'écran (la caméra suit le joueur, qui reste à gauche de l'écran)
const PLAYER_SCREEN_X := 240.0
const SPAWN_SCREEN_X := 500.0
# au-delà, l'ennemi n'est pas encore à l'écran : pas de ruée possible
const DASH_MAX_SCREEN_X := 460.0
# le joueur court tant que le premier ennemi est plus loin que ça
const RUN_STOP_DISTANCE := 120.0
const MAX_ENEMIES := 5
# flux régulier d'ennemis : un toutes les SPAWN_INTERVAL secondes (plus court aux
# niveaux élevés), tout de suite si l'écran est vide ; une apparition retardée
# (écran plein) a lieu dès qu'une place se libère
const SPAWN_INTERVAL_START := 2.2
const SPAWN_INTERVAL_PER_LEVEL := 0.12
const SPAWN_INTERVAL_MIN := 0.9
# variation aléatoire de l'intervalle, pour un rythme naturel mais régulier
const SPAWN_INTERVAL_JITTER := 0.15
# délai minimal entre deux apparitions, même quand l'écran se vide
const SPAWN_MIN_DELAY := 0.4
# écart minimal avec le dernier ennemi au point d'apparition
const SPAWN_MIN_SPACING := 40.0
const LEVEL_UP_HEAL := 20
# touches de repos des index : le joueur les appuie pour montrer qu'il est prêt
const READY_KEYS := ["f", "j"]
# durée d'affichage du clavier en transparence au début du niveau
const LAYOUT_DURATION := 4.0
# précision minimale pour passer au niveau suivant ; en dessous, le niveau est rejoué
const REQUIRED_ACCURACY := 0.94
# nombre de touches ratées montrées dans le bilan
const MISSED_KEYS_SHOWN := 3

signal player_ready
signal stats_closed

@onready var _player = $Player
@onready var _enemies: Node2D = $Enemies
@onready var _camera: Camera2D = $Camera2D
@onready var _hud = $Hud
@onready var _key_track = $Hud.key_track

var _level := 1
var _killed_in_level := 0
# ennemis vivants, dans l'ordre d'arrivée : le premier est la cible
var _queue: Array[Enemy] = []
var _is_gameover := false
var _is_level_starting := false
# assez d'ennemis tués : on attend que la file se vide avant le niveau suivant
var _is_level_complete := false
var _spawn_cooldown := 0.0
var _time_since_spawn := 0.0
var _is_waiting_ready := false
var _ready_pressed: Array = []
var _is_showing_stats := false
var _can_close_stats := false

# statistiques de la tentative en cours
var _good_keys := 0
var _errors := 0
# touche attendue -> nombre d'erreurs
var _missed := {}


func _ready():
	GlobalEvents.enemy_die.connect(_on_enemy_die)
	GlobalEvents.enemy_attack_player.connect(_on_enemy_attack_player)
	GlobalEvents.player_gameover.connect(_on_player_gameover)
	_player.gameover_animation_finished.connect(_on_player_gameover_animation_finished)
	_key_track.set_player(_player)
	_hud.resume_requested.connect(_set_paused.bind(false))
	_hud.menu_requested.connect(_go_to_menu)

	_start_level(GlobalGame.getLevel())


func _process(_delta):
	_camera.position.x = _screen_left() + get_viewport_rect().size.x / 2


func _physics_process(delta):
	var is_playing = not (_is_gameover or _is_level_starting or _is_showing_stats)
	var enemy_near = not _queue.is_empty() and _queue[0].position.x - _player.position.x < RUN_STOP_DISTANCE
	if is_playing:
		_update_spawn(delta)
	if is_playing and not enemy_near:
		_player.run(delta)
	else:
		_player.stop_running()


# bord gauche de l'écran dans le monde : le joueur y est toujours à PLAYER_SCREEN_X
func _screen_left() -> float:
	return _player.position.x - PLAYER_SCREEN_X


func _unhandled_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return

	if _is_gameover or get_tree().paused:
		return

	if event.keycode == KEY_TAB:
		_hud.toggle_keyboard()
		get_viewport().set_input_as_handled()
		return

	if _is_showing_stats:
		if _can_close_stats and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			stats_closed.emit()
		get_viewport().set_input_as_handled()
		return

	if event.unicode == 0:
		return

	var typed = String.chr(event.unicode).to_lower()
	if _is_waiting_ready:
		_on_ready_key_typed(typed)
	else:
		_on_key_typed(typed)
	get_viewport().set_input_as_handled()


# focus_keys : touches ratées lors de la tentative précédente du même niveau
func _start_level(level: int, focus_keys: Array = []):
	_level = level
	_killed_in_level = 0
	_is_level_complete = false
	_good_keys = 0
	_errors = 0
	_missed.clear()
	GlobalGame.saveLevel(level)

	var new_keys = GlobalLessons.get_new_keys(level)
	_hud.set_level(level, GlobalLessons.get_keys(level), new_keys)
	_hud.set_level_progress(0, _get_kills_to_pass())
	GlobalEvents.level_changed.emit(level, new_keys)

	var subtitle = tr("LEVEL_ALL_KEYS")
	if not new_keys.is_empty():
		subtitle = tr("LEVEL_NEW_KEYS") % " ".join(new_keys).to_upper()
	if not focus_keys.is_empty():
		subtitle = tr("LEVEL_FOCUS_KEYS") % " ".join(focus_keys).to_upper()

	_is_level_starting = true
	_hud.show_banner(tr("LEVEL") % level, subtitle)
	_hud.keyboard_overlay.show_level_keys(GlobalLessons.get_keys(level), new_keys, READY_KEYS)

	# le niveau ne démarre que quand le joueur a posé ses index sur F et J
	_ready_pressed.clear()
	_is_waiting_ready = true
	await player_ready
	_hud.keyboard_overlay.set_message(tr("GO"), Color.WHITE)
	await get_tree().create_timer(0.6).timeout
	# le clavier reste quelques secondes en transparence pour voir la disposition
	_hud.keyboard_overlay.show_layout(GlobalLessons.get_keys(level), LAYOUT_DURATION)
	await _hud.hide_banner()
	_is_level_starting = false


func _on_ready_key_typed(typed: String):
	if not READY_KEYS.has(typed) or _ready_pressed.has(typed):
		return
	_ready_pressed.append(typed)
	_hud.keyboard_overlay.mark_ready_key(typed)
	if _ready_pressed.size() == READY_KEYS.size():
		_is_waiting_ready = false
		player_ready.emit()


func _get_kills_to_pass() -> int:
	return 8 + 2 * _level


func _get_spawn_interval() -> float:
	return max(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_START - SPAWN_INTERVAL_PER_LEVEL * (_level - 1))


func _update_spawn(delta: float):
	_spawn_cooldown -= delta
	_time_since_spawn += delta
	if _is_level_complete or _queue.size() >= MAX_ENEMIES or _time_since_spawn < SPAWN_MIN_DELAY:
		return
	var spawn_x = _screen_left() + SPAWN_SCREEN_X
	if not _queue.is_empty() and spawn_x - _queue.back().position.x < SPAWN_MIN_SPACING:
		return
	if _spawn_cooldown <= 0 or not _has_enemy_incoming():
		_spawn_enemy()


# un ennemi est à l'écran ou sur le point d'y entrer (juste apparu à droite)
func _has_enemy_incoming() -> bool:
	var limit_x = _screen_left() + SPAWN_SCREEN_X + 1
	for enemy in _queue:
		if enemy.position.x <= limit_x:
			return true
	return false


func _get_speed_coef() -> float:
	return GlobalGame.enemy_speed_coef * (1.0 + 0.06 * (_level - 1))


# fourmis (1 touche) au début, puis araignées (2) et scarabées (3)
func _pick_enemy_scene() -> PackedScene:
	var max_index = 0
	if _level >= 3:
		max_index = 1
	if _level >= 5:
		max_index = 2
	max_index = min(max_index, enemy_scenes.size() - 1)
	# les fourmis restent majoritaires
	if randf() < 0.5:
		return enemy_scenes[0]
	return enemy_scenes[randi_range(0, max_index)]


func _spawn_enemy():
	if _is_gameover or _is_level_starting or _is_level_complete or _queue.size() >= MAX_ENEMIES:
		return

	var enemy: Enemy = _pick_enemy_scene().instantiate()
	var keys := []
	for i in enemy.key_count:
		keys.append(GlobalLessons.pick_key(_level, GlobalPlayer.get_weak_keys()))

	enemy.position = Vector2(_screen_left() + SPAWN_SCREEN_X, _player.position.y)
	enemy.setup(keys, _player, _get_speed_coef())
	if not _queue.is_empty():
		enemy.front_enemy = _queue.back()

	_enemies.add_child(enemy)
	_queue.append(enemy)
	_spawn_cooldown = _get_spawn_interval() * randf_range(1.0 - SPAWN_INTERVAL_JITTER, 1.0 + SPAWN_INTERVAL_JITTER)
	_time_since_spawn = 0.0
	_key_track.add_enemy(enemy)
	GlobalEvents.enemy_spawned.emit(enemy)


func _on_key_typed(typed: String):
	if _queue.is_empty():
		return

	var target: Enemy = _queue[0]
	var expected = target.get_next_key()
	if typed != expected:
		_errors += 1
		_missed[expected] = _missed.get(expected, 0) + 1
		GlobalPlayer.add_key_error(expected)
		GlobalPlayer.reset_combo()
		_key_track.wrong_key()
		GlobalEvents.wrong_key.emit(target.get_next_key(), typed)
		return

	# bonne touche mais ennemi hors de portée : le joueur se rue sur lui s'il est
	# à l'écran, sinon c'est un coup dans le vide
	var must_dash = not _player.can_hit(target)
	if must_dash and target.position.x - _screen_left() > DASH_MAX_SCREEN_X:
		GlobalPlayer.reset_combo()
		_player.whiff()
		_key_track.too_early()
		return

	_good_keys += 1
	GlobalPlayer.add_key_success(typed)
	GlobalPlayer.add_good_key()
	_key_track.pop_key()
	GlobalEvents.enemy_hit.emit(target, typed)
	target.consume_key()
	# la frappe suivante vise déjà l'ennemi d'après, même si le coup n'a pas encore porté
	if target.is_doomed():
		_remove_from_queue(target)
	if must_dash:
		_player.dash_attack(target)
	else:
		_player.attack(target)


func _remove_from_queue(enemy: Enemy):
	var index = _queue.find(enemy)
	if index == -1:
		return
	_queue.remove_at(index)
	# l'ennemi suivant doit maintenant suivre celui qui précédait
	if index < _queue.size():
		_queue[index].front_enemy = _queue[index - 1] if index > 0 else null


func _on_enemy_die(enemy: Enemy):
	_remove_from_queue(enemy)
	GlobalPlayer.add_kill()
	if not _is_level_complete and not _is_level_starting:
		_killed_in_level += 1
		_hud.set_level_progress(_killed_in_level, _get_kills_to_pass())
		if _killed_in_level >= _get_kills_to_pass():
			# plus d'apparitions : le joueur finit les ennemis restants avant
			# l'écran « Prêt ? » du niveau suivant
			_is_level_complete = true

	if _is_level_complete and _queue.is_empty() and not _is_showing_stats:
		_end_level()


func _on_enemy_attack_player(enemy: Enemy):
	if _is_gameover:
		return
	GlobalPlayer.take_damage(enemy.damage)


func get_accuracy() -> float:
	var total = _good_keys + _errors
	return 1.0 if total == 0 else float(_good_keys) / total


# bilan du niveau : on avance si la précision est suffisante, sinon on rejoue
# le niveau en insistant sur les touches ratées
func _end_level():
	var accuracy = get_accuracy()
	var passed = accuracy >= REQUIRED_ACCURACY
	var missed_keys = _missed.keys()
	missed_keys.sort_custom(func(a, b): return _missed[a] > _missed[b])
	missed_keys = missed_keys.slice(0, MISSED_KEYS_SHOWN)

	_is_showing_stats = true
	_can_close_stats = false
	await _hud.level_stats.show_stats(passed, accuracy, REQUIRED_ACCURACY, _good_keys, _errors, missed_keys)
	_can_close_stats = true
	await stats_closed
	_is_showing_stats = false
	await _hud.level_stats.hide_stats()
	if _is_gameover:
		return

	if passed:
		GlobalPlayer.heal(LEVEL_UP_HEAL)
		_start_level(_level + 1)
	else:
		_start_level(_level, missed_keys)


func _on_player_gameover():
	_is_gameover = true
	GlobalGame.saveHighScore(GlobalPlayer.get_score(), _level)


func _on_player_gameover_animation_finished():
	await get_tree().create_timer(0.8).timeout
	GlobalTransition.change_scene_to_packed(game_over_scene)


func _set_paused(paused: bool):
	if _is_gameover:
		return
	get_tree().paused = paused
	_hud.set_paused(paused)


func _go_to_menu():
	get_tree().paused = false
	GlobalTransition.change_scene_to_packed(load(menu_scene_path))
