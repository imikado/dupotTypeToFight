extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export var game_over_scene: PackedScene
@export_file("*.tscn") var menu_scene_path: String

const SPAWN_X := 520.0
const MAX_ENEMIES := 5
const LEVEL_UP_HEAL := 20
# touches de repos des index : le joueur les appuie pour montrer qu'il est prêt
const READY_KEYS := ["f", "j"]

signal player_ready

@onready var _player = $Player
@onready var _enemies: Node2D = $Enemies
@onready var _spawn_timer: Timer = $SpawnTimer
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
var _is_waiting_ready := false
var _ready_pressed: Array = []


func _ready():
	GlobalEvents.enemy_die.connect(_on_enemy_die)
	GlobalEvents.enemy_attack_player.connect(_on_enemy_attack_player)
	GlobalEvents.player_gameover.connect(_on_player_gameover)
	_player.gameover_animation_finished.connect(_on_player_gameover_animation_finished)
	_hud.resume_requested.connect(_set_paused.bind(false))
	_hud.menu_requested.connect(_go_to_menu)

	_start_level(GlobalGame.getLevel())


func _unhandled_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return

	if _is_gameover or get_tree().paused or event.unicode == 0:
		return

	var typed = String.chr(event.unicode).to_lower()
	if _is_waiting_ready:
		_on_ready_key_typed(typed)
	else:
		_on_key_typed(typed)
	get_viewport().set_input_as_handled()


func _start_level(level: int):
	_level = level
	_killed_in_level = 0
	_is_level_complete = false
	GlobalGame.saveLevel(level)

	var new_keys = GlobalLessons.get_new_keys(level)
	_hud.set_level(level, GlobalLessons.get_keys(level), new_keys)
	_hud.set_level_progress(0, _get_kills_to_pass())
	GlobalEvents.level_changed.emit(level, new_keys)

	var subtitle = tr("LEVEL_ALL_KEYS")
	if not new_keys.is_empty():
		subtitle = tr("LEVEL_NEW_KEYS") % " ".join(new_keys).to_upper()

	_is_level_starting = true
	_spawn_timer.stop()
	_hud.show_banner(tr("LEVEL") % level, subtitle)
	_hud.keyboard_overlay.show_level_keys(GlobalLessons.get_keys(level), new_keys, READY_KEYS)

	# le niveau ne démarre que quand le joueur a posé ses index sur F et J
	_ready_pressed.clear()
	_is_waiting_ready = true
	await player_ready
	_hud.keyboard_overlay.set_message(tr("GO"), Color.WHITE)
	await get_tree().create_timer(0.6).timeout
	_hud.keyboard_overlay.hide_keyboard()
	await _hud.hide_banner()
	_is_level_starting = false
	if _is_gameover:
		return
	_spawn_timer.wait_time = _get_spawn_interval()
	_spawn_timer.start()
	_spawn_enemy()


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
	return max(1.2, 3.6 - 0.2 * _level)


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
		keys.append(GlobalLessons.pick_key(_level))

	enemy.position = Vector2(SPAWN_X, _player.position.y)
	enemy.setup(keys, _player.position.x + enemy.attack_distance, _get_speed_coef())
	if not _queue.is_empty():
		enemy.front_enemy = _queue.back()

	_enemies.add_child(enemy)
	_queue.append(enemy)
	_key_track.add_enemy(enemy)
	GlobalEvents.enemy_spawned.emit(enemy)


func _on_key_typed(typed: String):
	if _queue.is_empty():
		return

	var target: Enemy = _queue[0]
	if typed != target.get_next_key():
		GlobalPlayer.reset_combo()
		_key_track.wrong_key()
		GlobalEvents.wrong_key.emit(target.get_next_key(), typed)
		return

	if not _player.can_hit(target):
		# bonne touche mais ennemi hors de portée : coup dans le vide
		GlobalPlayer.reset_combo()
		_player.whiff()
		return

	GlobalPlayer.add_good_key()
	_key_track.pop_key()
	GlobalEvents.enemy_hit.emit(target, typed)
	target.consume_key()
	# la frappe suivante vise déjà l'ennemi d'après, même si le coup n'a pas encore porté
	if target.is_doomed():
		_remove_from_queue(target)
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
			_spawn_timer.stop()

	if _is_level_complete and _queue.is_empty():
		_level_up()


func _on_enemy_attack_player(enemy: Enemy):
	if _is_gameover:
		return
	GlobalPlayer.take_damage(enemy.damage)


func _level_up():
	GlobalPlayer.heal(LEVEL_UP_HEAL)
	_start_level(_level + 1)


func _on_player_gameover():
	_is_gameover = true
	_spawn_timer.stop()
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


func _on_spawn_timer_timeout():
	_spawn_enemy()
