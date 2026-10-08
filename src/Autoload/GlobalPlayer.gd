extends Node

var _life := 100
var _max_life := 100
var _score := 0
var _combo := 0
var _best_combo := 0
var _killed := 0

# points faibles : touche -> score, augmenté à chaque erreur sur cette touche et
# diminué à chaque réussite ; les touches faibles sont reproposées plus souvent
const WEAKNESS_ON_ERROR := 2
const WEAKNESS_ON_SUCCESS := 1
var _weak_keys := {}


func reset_game(keep_weak_keys := false):
	_max_life = GlobalGame.player_start_life
	_life = _max_life
	_score = 0
	_combo = 0
	_best_combo = 0
	_killed = 0
	if not keep_weak_keys:
		_weak_keys.clear()


func get_life() -> int:
	return _life


func get_max_life() -> int:
	return _max_life


func is_dead() -> bool:
	return _life <= 0


func take_damage(damage: int):
	_life = max(0, _life - damage)
	reset_combo()
	GlobalEvents.player_take_damage.emit(damage)
	GlobalEvents.player_health_changed.emit(_life)
	if _life <= 0:
		GlobalEvents.player_gameover.emit()


func heal(value: int):
	_life = min(_max_life, _life + value)
	GlobalEvents.player_health_changed.emit(_life)


func get_score() -> int:
	return _score


func get_best_combo() -> int:
	return _best_combo


func get_killed() -> int:
	return _killed


func add_kill():
	_killed += 1


# chaque bonne touche rapporte des points, multipliés par le combo
func add_good_key():
	_combo += 1
	_best_combo = max(_best_combo, _combo)
	_score += 10 * get_multiplier()
	GlobalEvents.combo_changed.emit(_combo)
	GlobalEvents.score_changed.emit(_score)


func add_key_error(key: String):
	_weak_keys[key] = _weak_keys.get(key, 0) + WEAKNESS_ON_ERROR


func add_key_success(key: String):
	if not _weak_keys.has(key):
		return
	_weak_keys[key] -= WEAKNESS_ON_SUCCESS
	if _weak_keys[key] <= 0:
		_weak_keys.erase(key)


func get_weak_keys() -> Dictionary:
	return _weak_keys


func reset_combo():
	_combo = 0
	GlobalEvents.combo_changed.emit(_combo)


func get_combo() -> int:
	return _combo


func get_multiplier() -> int:
	return 1 + int(_combo / 10.0)
