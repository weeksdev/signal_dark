class_name ArcadeSeedRng
extends RefCounted

var _rng: RandomNumberGenerator


func _init(seed_val: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val


func randi() -> int:
	return _rng.randi()


func randf() -> float:
	return _rng.randf()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
