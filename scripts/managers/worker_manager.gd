class_name WorkerManager
extends Node

var _rng := RandomNumberGenerator.new()

# ─────────────────────────────────────────────────────────────────────────────

func process_turn() -> void:
	_mine_resources()

# ─────────────────────────────────────────────────────────────────────────────

func _mine_resources() -> void:
	var resources_changed := false

	# Множитель выработки от законов и технологий
	var output_mult: float = 1.0
	if GameState.active_laws.get(LawsManager.LAW_HARSH_REGIME, false):
		output_mult *= 1.25
	if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false):
		output_mult *= 0.85
	# Технология «Горнодобыча» (+20% для шахт)
	var mine_mult: float = output_mult * (1.0 + GameState.get_meta("research_bonuses", {}).get("mine_mult", 0.0))

	for coords: Vector2i in GameState.tile_workers:
		var count: int = GameState.tile_workers[coords]
		if count <= 0:
			continue
		var tile: HexTile = GameState.hex_tiles.get(coords)
		if not tile:
			continue

		if _is_mine(tile):
			_process_mine(coords, tile, count, mine_mult)   # шахты получают tech-бонус
			resources_changed = true
		elif tile.building < 0:
			# Открытая добыча песчаника — безопасно
			var gain := 0.0
			for _i in range(count):
				gain += _rng.randf_range(1.0, 4.0)
			GameState.sand += gain * output_mult
			resources_changed = true

	if resources_changed:
		EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)

# ─────────────────────────────────────────────────────────────────────────────

func _is_mine(tile: HexTile) -> bool:
	return tile.tile_type == HexTile.TILE_MINE or tile.building == GameState.BUILDING_MINE

func _process_mine(coords: Vector2i, tile: HexTile, count: int, output_mult: float = 1.0) -> void:
	var deaths := 0

	for _i in range(count):
		# Базовая добыча: металлолом + немного песчаника
		GameState.scrap += _rng.randf_range(1.0, 4.0) * output_mult
		GameState.sand  += _rng.randf_range(0.5, 2.0) * output_mult

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
