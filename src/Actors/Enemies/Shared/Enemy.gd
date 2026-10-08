class_name Enemy
extends Node2D

enum STATE {WALK, ATTACK, DAMAGED, DYING}

# distance minimale entre deux ennemis qui font la queue
const QUEUE_SPACING := 36.0

# pause entre deux attaques d'un ennemi arrivé au contact du joueur
const ATTACK_COOLDOWN := 1.0

@export var key_count := 1
@export var damage := 10
@export var speed := 30.0
# frame de l'animation "attack" où le coup porte (comme la HitBox de dupotBeatAndMatchToPass)
@export var attack_hit_frame := 3

var keys: Array = []
var front_enemy: Enemy = null

var _target_x := 0.0
var _state = STATE.WALK
var _attack_cooldown := 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: Area2D = $HurtBox


func setup(new_keys: Array, target_x: float, speed_coef: float):
	keys = new_keys
	_target_x = target_x
	speed *= speed_coef


func _ready():
	add_to_group(GlobalGame.GROUP_ENEMY)
	_sprite.play("walking")
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)


func _physics_process(delta):
	match _state:
		STATE.WALK:
			_walk(delta)
		STATE.ATTACK:
			_attack_cooldown -= delta
			if _attack_cooldown <= 0 and _sprite.animation != "attack" and not is_doomed() and not GlobalPlayer.is_dead():
				_sprite.play("attack")


# avance jusqu'au joueur ; si un ennemi est déjà devant (au contact ou en route),
# on attend derrière lui dans la file
func _walk(delta):
	var limit_x = _target_x
	if is_instance_valid(front_enemy) and front_enemy.is_alive():
		limit_x = max(limit_x, front_enemy.position.x + QUEUE_SPACING)

	position.x = move_toward(position.x, limit_x, speed * delta)

	if position.x <= _target_x:
		_state = STATE.ATTACK
		_attack_cooldown = 0.0
	elif position.x <= limit_x:
		_sprite.play("idle")
	else:
		_sprite.play("walking")


func is_alive() -> bool:
	return _state != STATE.DYING


func get_next_key() -> String:
	return keys[0]


func get_feet_position() -> Vector2:
	return global_position + Vector2(0, 30)


# la touche est validée dès la frappe au clavier ; le coup (hit) n'est
# appliqué qu'au moment où l'arme du joueur touche
func consume_key():
	keys.pop_front()


# toutes les touches ont été tapées : l'ennemi mourra au prochain coup reçu
func is_doomed() -> bool:
	return keys.is_empty()


func hit():
	if _state == STATE.DYING:
		return

	if is_doomed():
		print('die')
		_die()
		return

	_state = STATE.DAMAGED
	_sprite.stop()
	_sprite.play("damaged")
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 10, 0.1)


func _die():
	_state = STATE.DYING
	remove_from_group(GlobalGame.GROUP_ENEMY)
	hurt_box.set_deferred("monitorable", false)
	_sprite.stop()
	_sprite.play("died")
	GlobalEvents.enemy_die.emit(self)


func _vanish():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _on_animation_finished():
	match _sprite.animation:
		"attack":
			if _state != STATE.ATTACK:
				return
			# l'ennemi reste au contact et attaque à nouveau tant qu'il n'est pas tué
			_attack_cooldown = ATTACK_COOLDOWN
			_sprite.play("idle")
		"damaged":
			if _state == STATE.DAMAGED:
				_state = STATE.WALK
		"died":
			_vanish()


func _on_frame_changed():
	if _sprite.animation != "attack" or _sprite.frame != attack_hit_frame:
		return
	if _state != STATE.ATTACK or is_doomed():
		return
	GlobalEvents.enemy_attack_player.emit(self)
