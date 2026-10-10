class_name Enemy
extends Node2D

enum STATE {WALK, ATTACK, DAMAGED, DYING}

# distance minimale entre deux ennemis qui font la queue
const QUEUE_SPACING := 36.0

# pause entre deux attaques d'un ennemi arrivé au contact du joueur
const ATTACK_COOLDOWN := 1.0

# mode Mots : le mot est écrit au-dessus de l'ennemi, lettres tapées estompées
const WORD_LABEL_Y := -30.0
const WORD_LABEL_WIDTH := 80.0
const COLOR_WORD_TYPED := "#7a8099"
const COLOR_WORD_NEXT := "#ffd23f"

@export var key_count := 1
# dégâts proches pour tous les ennemis (fourmi 10, araignée 12, scarabée 14) : la
# difficulté vient surtout du nombre de touches, pas de coups bien plus forts
@export var damage := 10
@export var speed := 30.0
# distance au centre du joueur où l'ennemi s'arrête pour attaquer (au contact du sprite)
@export var attack_distance := 22.0
# frame de l'animation "attack" où le coup porte (comme la HitBox de dupotBeatAndMatchToPass)
@export var attack_hit_frame := 3

var keys: Array = []
var front_enemy: Enemy = null
var _word := ""
var _word_label: RichTextLabel

# l'ennemi s'arrête au contact du joueur, là où il se trouve (il peut se ruer en avant)
var _player: Node2D = null
var _state = STATE.WALK
var _attack_cooldown := 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: Area2D = $HurtBox


# show_word : affiche les touches comme un mot au-dessus de l'ennemi (mode Mots)
func setup(new_keys: Array, player: Node2D, speed_coef: float, show_word := false):
	keys = new_keys
	_player = player
	speed *= speed_coef
	if show_word:
		_word = "".join(new_keys).to_upper()


func _get_target_x() -> float:
	if is_instance_valid(_player):
		return _player.position.x + attack_distance
	return position.x


func _ready():
	add_to_group(GlobalGame.GROUP_ENEMY)
	_sprite.play("walking")
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	if not _word.is_empty():
		_create_word_label()


func _create_word_label():
	_word_label = RichTextLabel.new()
	_word_label.bbcode_enabled = true
	_word_label.fit_content = true
	_word_label.scroll_active = false
	_word_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_word_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_label.add_theme_font_size_override("normal_font_size", 8)
	_word_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_word_label.add_theme_constant_override("outline_size", 3)
	_word_label.size = Vector2(WORD_LABEL_WIDTH, 0)
	_word_label.position = Vector2(-WORD_LABEL_WIDTH / 2, WORD_LABEL_Y)
	add_child(_word_label)
	_refresh_word_label()


# lettres déjà tapées en gris, prochaine lettre en jaune, le reste en blanc
func _refresh_word_label():
	if not _word_label:
		return
	var typed_count = _word.length() - keys.size()
	var text = "[color=%s]%s[/color]" % [COLOR_WORD_TYPED, _word.left(typed_count)]
	if typed_count < _word.length():
		text += "[color=%s]%s[/color]%s" % [COLOR_WORD_NEXT, _word[typed_count], _word.substr(typed_count + 1)]
	_word_label.text = "[center]%s[/center]" % text


func _physics_process(delta):
	match _state:
		STATE.WALK:
			_walk(delta)
		STATE.ATTACK:
			# le joueur a reculé : on le suit
			if position.x > _get_target_x() + 2 and _sprite.animation != "attack":
				_state = STATE.WALK
				return
			_attack_cooldown -= delta
			if _attack_cooldown <= 0 and _sprite.animation != "attack" and not is_doomed() and not GlobalPlayer.is_dead():
				_sprite.play("attack")


# avance jusqu'au joueur ; si un ennemi est déjà devant (au contact ou en route),
# on attend derrière lui dans la file
func _walk(delta):
	var target_x = _get_target_x()
	var limit_x = target_x
	if is_instance_valid(front_enemy) and front_enemy.is_alive():
		limit_x = max(limit_x, front_enemy.position.x + QUEUE_SPACING)

	position.x = move_toward(position.x, limit_x, speed * delta)

	if position.x <= target_x:
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
	_refresh_word_label()


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
	GlobalAudio.play("hit")
	_sprite.stop()
	_sprite.play("damaged")
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 10, 0.1)


func _die():
	_state = STATE.DYING
	if _word_label:
		_word_label.visible = false
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
