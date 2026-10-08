extends Node

signal player_health_changed(new_value)

signal player_take_damage(damage)

signal player_gameover

signal score_changed(new_value)

signal combo_changed(new_value)

signal enemy_spawned(enemy)

signal enemy_hit(enemy, key)

signal enemy_die(enemy)

signal enemy_attack_player(enemy)

signal wrong_key(expected, typed)

signal level_changed(level, new_keys)
