extends Node2D

signal gameover_animation_finished

const ATTACK_LIST := ["attack1", "attack2", "attack3", "attack4"]
# frame des animations d'attaque où l'arme touche l'ennemi
const HIT_FRAME := 2
# mode Arcade : les lettres d'un même mot enchaînent les attaques dans l'ordre
# (chaque planche commence dans la pose où finit la précédente), puis alternent
# les deux dernières ; l'enchaînement repart du début après une pause trop longue
const CHAIN_LOOP_START := 2
const CHAIN_MAX_DELAY := 0.6

# ruée vers un ennemi trop loin ; course tranquille quand aucun ennemi n'est proche
# (la caméra suit le joueur, le décor défile à l'infini)
const DASH_SPEED := 750.0
const RUN_SPEED := 30.0
# course pour rejoindre un ennemi lointain : vitesse maximale, et les jambes
# s'animent plus vite (jusqu'à RUN_ANIMATION_MAX_SCALE fois)
const RUN_SPEED_MAX := 220.0
const RUN_ANIMATION_MAX_SCALE := 2.5

const HIT_ZONE_ALPHA_IDLE := 0.2
const HIT_ZONE_ALPHA_ACTIVE := 0.6

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hit_area: Area2D = $HitArea
@onready var _hit_zone: ColorRect = $HitZone

var _is_dead := false
# ennemis visés dont le coup n'a pas encore porté
var _pending_hits: Array[Enemy] = []

var _move_tween: Tween

# enchaînement en cours : ennemi visé, attaque jouée (index dans ATTACK_LIST) et heure
var _chain_target: Enemy = null
var _chain_index := -1
var _chain_time := 0.0


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
	_chain_target = null
	attack()
	GlobalAudio.play("whiff")
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
	_play_attack(target)


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
	GlobalAudio.play("dash")
	var destination = target.position.x - target.attack_distance
	var duration = abs(destination - position.x) / DASH_SPEED
	_sprite.stop()
	_sprite.play("walking")
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:x", destination, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_callback(_play_attack.bind(target))


# target peut avoir disparu pendant une ruée
func _play_attack(target = null):
	# play() ne relance pas une animation déjà en cours : on force le redémarrage
	_sprite.stop()
	_sprite.speed_scale = 1.0
	_sprite.play(_get_attack_animation(target))


func _get_attack_animation(target) -> String:
	if not is_instance_valid(target) or not GlobalGame.isWordsMode():
		return ATTACK_LIST.pick_random()
	var now = Time.get_ticks_msec() / 1000.0
	if target == _chain_target and now - _chain_time <= CHAIN_MAX_DELAY:
		_chain_index = _chain_index + 1 if _chain_index < ATTACK_LIST.size() - 1 else CHAIN_LOOP_START
	else:
		_chain_index = 0
	_chain_target = target
	_chain_time = now
	return ATTACK_LIST[_chain_index]


func _stop_moving():
	if _move_tween:
		_move_tween.kill()


func _is_dashing() -> bool:
	return _move_tween != null and _move_tween.is_running()


# avance en courant, sauf pendant une attaque, une ruée ou un coup reçu ;
# catch_up : vitesse en plus pour rejoindre un ennemi encore loin
func run(delta: float, catch_up := 0.0):
	if _is_dead or _is_dashing() or _sprite.animation != "idle" and _sprite.animation != "walking":
		return
	var speed = min(RUN_SPEED + catch_up, RUN_SPEED_MAX)
	position.x += speed * delta
	_sprite.speed_scale = min(speed / RUN_SPEED, RUN_ANIMATION_MAX_SCALE)
	if _sprite.animation != "walking":
		_sprite.play("walking")


func stop_running():
	if not _is_dead and not _is_dashing() and _sprite.animation == "walking":
		_sprite.speed_scale = 1.0
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
	_sprite.speed_scale = 1.0
	_sprite.play("damaged")
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 0.3, 0.3), 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)


func _on_gameover():
	_apply_hits()
	_stop_moving()
	_is_dead = true
	_sprite.stop()
	_sprite.speed_scale = 1.0
	_sprite.play("gameover")


func _on_animation_finished():
	_apply_hits()
	if _sprite.animation == "gameover":
		gameover_animation_finished.emit()
		return
	_sprite.play("idle")
