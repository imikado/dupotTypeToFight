extends Node2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	_sprite.play("strike")
	_sprite.animation_finished.connect(queue_free)
