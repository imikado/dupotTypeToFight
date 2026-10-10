extends Node

# Bruitages et musiques (générés par tools/generate_sounds.py). Les bus Music et
# Sfx (default_bus_layout.tres) sont coupés selon les paramètres du joueur.

const BUS_MUSIC := "Music"
const BUS_SFX := "Sfx"

const MUSIC_MENU := preload("res://src/Audio/Music/menu.wav")
const MUSIC_LEVEL := preload("res://src/Audio/Music/level.wav")

const SFX := {
	"key": preload("res://src/Audio/Sfx/key.wav"),
	"wrong": preload("res://src/Audio/Sfx/wrong.wav"),
	"whiff": preload("res://src/Audio/Sfx/whiff.wav"),
	"dash": preload("res://src/Audio/Sfx/dash.wav"),
	"hit": preload("res://src/Audio/Sfx/hit.wav"),
	"die": preload("res://src/Audio/Sfx/die.wav"),
	"hurt": preload("res://src/Audio/Sfx/hurt.wav"),
	"combo": preload("res://src/Audio/Sfx/combo.wav"),
	"level_start": preload("res://src/Audio/Sfx/level_start.wav"),
	"go": preload("res://src/Audio/Sfx/go.wav"),
	"ready": preload("res://src/Audio/Sfx/ready.wav"),
	"level_passed": preload("res://src/Audio/Sfx/level_passed.wav"),
	"level_retry": preload("res://src/Audio/Sfx/level_retry.wav"),
	"gameover": preload("res://src/Audio/Sfx/gameover.wav"),
	"record": preload("res://src/Audio/Sfx/record.wav"),
	"click": preload("res://src/Audio/Sfx/click.wav"),
	"move": preload("res://src/Audio/Sfx/move.wav"),
}

# nombre de bruitages joués en même temps (frappe rapide, coups, morts...)
const SFX_PLAYERS := 10
# le bip des bonnes touches monte d'un demi-ton tous les COMBO_STEP coups, jusqu'à COMBO_PITCH_MAX
const COMBO_STEP := 5
const COMBO_PITCH_MAX := 1.5
# un combo de COMBO_JINGLE touches (le multiplicateur augmente) est salué par un arpège
const COMBO_JINGLE := 10
const MUSIC_FADE := 0.6

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music: AudioStreamPlayer
var _music_tween: Tween


func _ready():
	# le menu pause doit encore faire du bruit
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	add_child(_music)

	apply_settings()

	GlobalEvents.enemy_hit.connect(_on_enemy_hit)
	GlobalEvents.wrong_key.connect(func(_expected, _typed): play("wrong"))
	GlobalEvents.enemy_die.connect(func(_enemy): play("die"))
	GlobalEvents.player_take_damage.connect(func(_damage): play("hurt"))
	GlobalEvents.player_gameover.connect(_on_player_gameover)
	GlobalEvents.combo_changed.connect(_on_combo_changed)

	# boutons de toute l'interface : clic, et petit son en passant d'un bouton à l'autre au clavier
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)


# son et musique activés ou non dans les paramètres
func apply_settings():
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_SFX), not GlobalGame.isSoundEnabled())
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MUSIC), not GlobalGame.isMusicEnabled())


# des sons encore en cours à la fermeture du jeu seraient signalés comme fuites
func _exit_tree():
	for player in _sfx_players + [_music]:
		player.stop()
		player.stream = null


func play(sound: String, pitch := 1.0):
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	player.stream = SFX[sound]
	player.pitch_scale = pitch
	player.play()


func play_menu_music():
	_play_music(MUSIC_MENU)


func play_level_music():
	_play_music(MUSIC_LEVEL)


# la musique déjà en cours continue (menu -> tutoriel, niveau -> niveau suivant)
func _play_music(stream: AudioStream):
	if _music_tween:
		_music_tween.kill()
	_music.volume_db = 0.0
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music():
	if not _music.playing:
		return
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, MUSIC_FADE)
	_music_tween.tween_callback(_music.stop)


func _on_enemy_hit(_enemy, _key):
	var combo = GlobalPlayer.get_combo()
	play("key", min(COMBO_PITCH_MAX, pow(2.0, int(combo / COMBO_STEP) / 12.0)))


func _on_combo_changed(combo: int):
	if combo > 0 and combo % COMBO_JINGLE == 0:
		play("combo")


func _on_player_gameover():
	stop_music()
	play("gameover")


func _on_node_added(node: Node):
	if node is OptionButton:
		node.item_selected.connect(func(_index): play("click"))
	if node is BaseButton:
		node.pressed.connect(play.bind("click"))


func _on_gui_focus_changed(_control: Control):
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if Input.is_action_just_pressed(action):
			play("move")
			return
