extends Control

# Écran de tutoriel entre le menu et le jeu : le niveau n'est chargé qu'une fois
# le tutoriel terminé ou passé (rien ne tourne en arrière-plan).

@export var level_scene: PackedScene

@onready var _tutorial = $Tutorial


func _ready():
	# le premier plan du décor passerait devant le tutoriel
	$Background/Foreground.visible = false
	await _tutorial.run()
	GlobalTransition.change_scene_to_packed(level_scene)
