class_name WorkerManager
extends Node

var _rng := RandomNumberGenerator.new()

# ─────────────────────────────────────────────────────────────────────────────

func process_turn() -> void:
	_mine_resources()

# ─────────────────────────────────────────────────────────────────────────────

func _mine_resources() -> void:
	var resources_changed := false

	for coords: Vector2i in GameState.tile_workers:
		var count: int = GameState.tile_workers[coords]
		if count <= 0:
			continue
		var tile: HexTile = GameState.hex_tiles.get(coords)
		if not tile:
			continue

		if _is_mine(tile):
			_process_mine(coords, tile, count)
			resources_changed = true
		elif tile.building < 0:
			# Открытая добыча песчаника — безопасно
			var gain := 0.0
			for _i in range(count):
				gain += _rng.randf_range(1.0, 4.0)
			GameState.sand += gain
			resources_changed = true

	if resources_changed:
		EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)

# ─────────────────────────────────────────────────────────────────────────────

func _is_mine(tile: HexTile) -> bool:
	return tile.tile_type == HexTile.TILE_MINE or tile.building == GameState.BUILDING_MINE

func _process_mine(coords: Vector2i, tile: HexTile, count: int) -> void:
	var deaths := 0

	for _i in range(count):
		# Базовая добыча: металлолом + немного песчаника
		GameState.scrap += _rng.randf_range(1.0, 4.0)
		GameState.sand  += _rng.randf_range(0.5, 2.0)

		# Шанс гибели при обычной добыче (1%)
		if _rng.randf() < 0.01:
			deaths += 1
			continue

		# Редкий алмаз (5% шанс)
		if _rng.randf() < 0.05:
			GameState.diamonds += 1.0
			# При находке — повышенный риск (3%)
			if _rng.randf() < 0.03:
				deaths += 1

	if deaths > 0:
		var actual := mini(deaths, GameState.tile_workers.get(coords, 0))
		GameState.population  = maxi(0, GameState.population - actual)
		var remaining: int    = maxi(0, GameState.tile_workers.get(coords, 0) - actual)
		GameState.tile_workers[coords] = remaining
		if tile:
			tile.update_workers(remaining)
		EventBus.population_changed.emit(GameState.population)
		EventBus.workers_changed.emit(coords, remaining)
		EventBus.game_event.emit({
			"turn":        GameState.current_turn,
			"title":       "Шахтёры погибли",
			"description": "%d рабочих погибли в шахте (%s)." % [actual, str(coords)],
			"severity":    (2 if actual >= 2 else 1),
		})
