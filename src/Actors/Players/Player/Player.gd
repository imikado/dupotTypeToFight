extends Node2D

signal gameover_animation_finished

const ATTACK_LIST := ["attack1", "attack2", "attack3", "attack4"]
# frame des animations d'attaque où l'arme touche l'ennemi
const HIT_FRAME := 2

# ruée vers un ennemi trop loin ; course tranquille quand aucun ennemi n'est proche
# (la caméra suit le joueur, le décor défile à l'infini)
const DASH_SPEED := 750.0
const RUN_SPEED := 30.0

const HIT_ZONE_ALPHA_IDLE := 0.2
const HIT_ZONE_ALPHA_ACTIVE := 0.6

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hit_area: Area2D = $HitArea
@onready var _hit_zone: ColorRect = $HitZone

var _is_dead := false
# ennemis visés dont le coup n'a pas encore porté
var _pending_hits: Array[Enemy] = []

var _move_tween: Tween


func _ready():
	_sprite.play("idle")
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	GlobalEvents.player_take_damage.connect(_on_take_damage)
	GlobalEvents.player_gameover.connect(_on_gameover)


func _process(_delta):
	# la zone de frappe s'allume quand un ennemi est à portée
	var alpha = HIT_ZONE_ALPHA_ACTIVE if _hit_area.has_overlapping_areas() else HIT_ZONE_ALPHA_IDLE
	_hit_zone.modulate.a = move_toward(_hit_zone.modulate.a, alpha, 0.1)


# l'arme ne touche que les ennemis présents dans la zone de frappe
func can_hit(enemy: Enemy) -> bool:
	return _hit_area.overlaps_area(enemy.hurt_box)


# distance (en pixels) entre la zone de frappe et l'ennemi ; <= 0 : il est à portée
func distance_to_hit(enemy: Enemy) -> float:
	var hit_right = _get_shape_rect(_hit_area).end.x
	var enemy_left = _get_shape_rect(enemy.hurt_box).position.x
	return enemy_left - hit_right


func _get_shape_rect(area: Area2D) -> Rect2:
	var shape_node: CollisionShape2D = area.get_child(0)
	var size = (shape_node.shape as RectangleShape2D).size
	return Rect2(shape_node.global_position - size / 2, size)


# coup dans le vide : l'ennemi est encore trop loin
func whiff():
	attack()
	_hit_zone.modulate.a = 1.0
	_hit_zone.self_modulate = Color(1, 0.2, 0.2)
	var tween = create_tween()
	tween.tween_property(_hit_zone, "self_modulate", Color.WHITE, 0.3)


func attack(target: Enemy = null):
	if _is_dead:
		return
	if target:
		_pending_hits.append(target)
	_stop_moving()
	_play_attack()


# bonne touche mais ennemi trop loin : le joueur se rue sur lui et frappe en arrivant
func dash_attack(target: Enemy):
	if _is_dead:
		return
	# nouvelle ruée avant la fin de la précédente : la cible précédente est
	# frappée au passage, sinon son coup serait perdu
	if _is_dashing():
		_apply_hits()
	_pending_hits.append(target)
	_stop_moving()
	var destination = target.position.x - target.attack_distance
	var duration = abs(destination - position.x) / DASH_SPEED
	_sprite.stop()
	_sprite.play("walking")
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:x", destination, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_callback(_play_attack)


func _play_attack():
	# play() ne relance pas une animation déjà en cours : on force le redémarrage
	_sprite.stop()
	_sprite.play(ATTACK_LIST.pick_random())


func _stop_moving():
	if _move_tween:
		_move_tween.kill()


func _is_dashing() -> bool:
	return _move_tween != null and _move_tween.is_running()


# avance en courant, sauf pendant une attaque, une ruée ou un coup reçu
func run(delta: float):
	if _is_dead or _is_dashing() or _sprite.animation != "idle" and _sprite.animation != "walking":
		return
	position.x += RUN_SPEED * delta
	if _sprite.animation != "walking":
		_sprite.play("walking")


func stop_running():
	if not _is_dead and not _is_dashing() and _sprite.animation == "walking":
		_sprite.play("idle")


func _apply_hits():
	for enemy in _pending_hits:
		if is_instance_valid(enemy):
			enemy.hit()
	_pending_hits.clear()


func _on_frame_changed():
	if ATTACK_LIST.has(_sprite.animation) and _sprite.frame == HIT_FRAME:
		_apply_hits()


func _on_take_damage(_damage):
	# une attaque interrompue porte quand même ses coups
	_apply_hits()
	if _is_dead:
		return
	_sprite.stop()
	_sprite.play("damaged")
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 0.3, 0.3), 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)


func _on_gameover():
	_apply_hits()
	_stop_moving()
	_is_dead = true
	_sprite.stop()
	_sprite.play("gameover")


func _on_animation_finished():
	_apply_hits()
	if _sprite.animation == "gameover":
		gameover_animation_finished.emit()
		return
	_sprite.play("idle")
