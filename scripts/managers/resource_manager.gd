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
		if not GameState.building_durability.has(coords):
			GameState.building_durability[coords] = 100.0
		var decay: float = 4.0 if GameState.sandstorm_active else 1.5
		GameState.building_durability[coords] = maxf(
			10.0, GameState.building_durability[coords] - decay)

func _calc_production() -> void:
	var gain: float = 0.0

	# Глобальный бонус от техники «Солнечная энергетика»
	var global_mult: float = 1.0 + _rb("global_mult")

	for coords: Vector2i in GameState.hex_tiles:
		var tile: HexTile = GameState.hex_tiles[coords]
		if tile.building < 0:
			continue
		if GameState.tile_workers.get(coords, 0) == 0:
			continue

		# Прочность → КПД
		var dur: float = GameState.building_durability.get(coords, 100.0)
		var eff: float = dur / 100.0 * global_mult

		# Смежностный множитель
		var adj: float = _adjacency_mult(coords, tile.building)

		match tile.building:
			GameState.BUILDING_PUMP:
				var bonus: float = 1.0
				match tile.tile_type:
					HexTile.TILE_OASIS:        bonus = 3.0
					HexTile.TILE_WATER_SOURCE: bonus = 2.5
					HexTile.TILE_DRY_SOURCE:   bonus = 0.3
				var pump_gain: float = 5.0 * bonus * eff * adj
				# Истощение подземных запасов
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
				# Бонус технологии «Водоочистка»
				var purifier_mult: float = 1.0 + _rb("purifier_mult")
				var to_purify := minf(GameState.dirty_water, 12.0 * eff * adj * purifier_mult)
				GameState.dirty_water -= to_purify
				gain += to_purify * 0.80

			GameState.BUILDING_CONDENSER:
				# Бонус технологии «Атмосферная конденсация»
				var condenser_mult: float = 1.0 + _rb("condenser_mult")
				gain += 2.0 * eff * adj * condenser_mult

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
	var evap: float = GameState.water * GameState.WATER_EVAP_RATE
	GameState.water_evaporation = evap
	var net: float  = GameState.water_production - GameState.water_consumption
	GameState.water_net = net
	GameState.water = maxf(0.0, GameState.water + net - evap)

# ─── Смежностные бонусы ───────────────────────────────────────────────────────

func _adjacency_mult(coords: Vector2i, building: int) -> float:
	var mult: float = 1.0
	for nb_coords: Vector2i in HexGrid.get_neighbors(coords):
		var nb: HexTile = GameState.hex_tiles.get(nb_coords)
		if not nb:
			continue
		match building:
			GameState.BUILDING_PUMP:
				# Рядом с оазисом или источником — бонус к добыче
				if nb.tile_type == HexTile.TILE_OASIS:
					mult += 0.30
				elif nb.tile_type == HexTile.TILE_WATER_SOURCE:
					mult += 0.15
			GameState.BUILDING_PURIFIER:
				# Рядом с насосом — быстрее получает сырьё
				if nb.building == GameState.BUILDING_PUMP:
					mult += 0.20
			GameState.BUILDING_CONDENSER:
				# Конкуренция за влагу с соседним конденсатором
				if nb.building == GameState.BUILDING_CONDENSER:
					mult -= 0.15
	return maxf(0.10, mult)

# ─── Хелпер: research bonus ───────────────────────────────────────────────────

func _rb(key: String) -> float:
	return GameState.get_meta("research_bonuses", {}).get(key, 0.0)
