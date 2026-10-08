extends Node2D

signal gameover_animation_finished

const ATTACK_LIST := ["attack1", "attack2", "attack3", "attack4"]
# frame des animations d'attaque où l'arme touche l'ennemi
const HIT_FRAME := 2

# ruée vers un ennemi trop loin, puis retour à la position de départ
const DASH_SPEED := 750.0
const RETURN_SPEED := 110.0
const RETURN_DELAY := 1.0

const HIT_ZONE_ALPHA_IDLE := 0.2
const HIT_ZONE_ALPHA_ACTIVE := 0.6

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hit_area: Area2D = $HitArea
@onready var _hit_zone: ColorRect = $HitZone

var _is_dead := false
# ennemis visés dont le coup n'a pas encore porté
var _pending_hits: Array[Enemy] = []

var _home_x := 0.0
var _move_tween: Tween
var _is_returning := false
var _return_timer: Timer


func _ready():
	_home_x = position.x
	_return_timer = Timer.new()
	_return_timer.one_shot = true
	_return_timer.wait_time = RETURN_DELAY
	_return_timer.timeout.connect(_on_return_timer_timeout)
	add_child(_return_timer)
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
	_return_timer.stop()
	_is_returning = false
	_sprite.flip_h = false


func _on_return_timer_timeout():
	if _is_dead or is_equal_approx(position.x, _home_x):
		return
	_is_returning = true
	_sprite.flip_h = true
	_sprite.play("walking")
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:x", _home_x, abs(position.x - _home_x) / RETURN_SPEED)
	_move_tween.tween_callback(_on_returned)


func _on_returned():
	_is_returning = false
	_sprite.flip_h = false
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
	_sprite.flip_h = false
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
	if _is_returning:
		_sprite.flip_h = true
		_sprite.play("walking")
		return
	_sprite.play("idle")
	# loin de sa position de départ : il y revient s'il n'est pas relancé entre-temps
	if not is_equal_approx(position.x, _home_x):
		_return_timer.start()
