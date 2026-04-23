class_name ResourceManager
extends Node

const BASE_CONSUME_PER_PERSON: float = 0.5   # воды/день/чел

func process_turn() -> void:
	_decay_durability()
	_calc_production()
	_calc_consumption()
	_apply_net()
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	EventBus.dirty_water_changed.emit(GameState.dirty_water)

# ─────────────────────────────────────────────────────────────────────────────

func _decay_durability() -> void:
	for coords: Vector2i in GameState.hex_tiles:
		var tile: HexTile = GameState.hex_tiles[coords]
		if tile.building < 0:
			continue
		# Инициализируем, если здание новое
		if not GameState.building_durability.has(coords):
			GameState.building_durability[coords] = 100.0
		var decay: float = 4.0 if GameState.sandstorm_active else 1.5
		GameState.building_durability[coords] = maxf(
			10.0, GameState.building_durability[coords] - decay)

func _calc_production() -> void:
	var gain: float = 0.0

	for coords: Vector2i in GameState.hex_tiles:
		var tile: HexTile = GameState.hex_tiles[coords]
		if tile.building < 0:
			continue
		# Постройка работает только при наличии рабочих
		if GameState.tile_workers.get(coords, 0) == 0:
			continue

		# Эффективность = прочность / 100
		var dur: float = GameState.building_durability.get(coords, 100.0)
		var eff: float = dur / 100.0

		match tile.building:
			GameState.BUILDING_PUMP:
				var bonus: float = 1.0
				match tile.tile_type:
					HexTile.TILE_OASIS:        bonus = 3.0
					HexTile.TILE_WATER_SOURCE: bonus = 2.5
					HexTile.TILE_DRY_SOURCE:   bonus = 0.3
				var pump_gain: float = 5.0 * bonus * eff
				# Водные источники ограничены подземными запасами
				if tile.tile_type == HexTile.TILE_WATER_SOURCE:
					if GameState.tile_water_reserves.has(coords):
						var reserves: float = GameState.tile_water_reserves[coords]
						pump_gain = minf(pump_gain, reserves)
						GameState.tile_water_reserves[coords] = maxf(0.0, reserves - pump_gain)
						if GameState.tile_water_reserves[coords] <= 0.0:
							tile.set_tile_type(HexTile.TILE_DRY_SOURCE)
							GameState.tile_water_reserves.erase(coords)
							EventBus.game_event.emit({
								"turn":        GameState.current_turn,
								"title":       "Источник иссяк",
								"description": "Подземные запасы воды истощились. Насос работает на минимуме.",
								"severity":    2,
							})
				gain += pump_gain

			GameState.BUILDING_PURIFIER:
				var to_purify = minf(GameState.dirty_water, 12.0 * eff)
				GameState.dirty_water -= to_purify
				gain += to_purify * 0.80

			GameState.BUILDING_CONDENSER:
				gain += 2.0 * eff

			# CARAVAN_STATION не производит воду напрямую

	# Штраф от песчаной бури применяется в event_manager,
	# здесь мы только суммируем чистую добычу
	GameState.water_production = gain

func _calc_consumption() -> void:
	var base: float = float(GameState.population) * BASE_CONSUME_PER_PERSON
	if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false):
		base *= 0.70
	if GameState.active_laws.get(LawsManager.LAW_WATER_CASTES, false):
		base *= 0.85
	if GameState.active_laws.get(LawsManager.LAW_OPEN_BORDERS, false):
		base *= 1.20
	GameState.water_consumption = base

func _apply_net() -> void:
	# Испарение: 4% запаса воды за ход
	var evap: float = GameState.water * GameState.WATER_EVAP_RATE
	GameState.water_evaporation = evap
	var net: float = GameState.water_production - GameState.water_consumption
	GameState.water_net = net
	GameState.water = maxf(0.0, GameState.water + net - evap)
