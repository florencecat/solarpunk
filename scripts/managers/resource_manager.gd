class_name ResourceManager
extends Node

const BASE_CONSUME_PER_PERSON: float = 0.5   # воды/день/чел

func process_turn() -> void:
	_calc_production()
	_calc_consumption()
	_apply_net()
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	EventBus.dirty_water_changed.emit(GameState.dirty_water)

# ─────────────────────────────────────────────────────────────────────────────

func _calc_production() -> void:
	var gain: float = 0.0

	for coords: Vector2i in GameState.hex_tiles:
		var tile: HexTile = GameState.hex_tiles[coords]
		if tile.building < 0:
			continue
		# Постройка работает только при наличии рабочих
		if GameState.tile_workers.get(coords, 0) == 0:
			continue

		match tile.building:
			GameState.BUILDING_PUMP:
				var bonus: float = 1.0
				match tile.tile_type:
					HexTile.TILE_OASIS:        bonus = 3.0
					HexTile.TILE_WATER_SOURCE: bonus = 2.5
					HexTile.TILE_DRY_SOURCE:   bonus = 0.3
				gain += 5.0 * bonus

			GameState.BUILDING_PURIFIER:
				var to_purify = minf(GameState.dirty_water, 12.0)
				GameState.dirty_water -= to_purify
				gain += to_purify * 0.80

			GameState.BUILDING_CONDENSER:
				gain += 2.0

			# CARAVAN_STATION не производит воду напрямую

	# Штраф от песчаной бури применяется в event_manager,
	# здесь мы только суммируем чистую добычу
	GameState.water_production = gain

func _calc_consumption() -> void:
	var base = float(GameState.population) * BASE_CONSUME_PER_PERSON
	if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false):
		base *= 0.70
	GameState.water_consumption = base

func _apply_net() -> void:
	var net = GameState.water_production - GameState.water_consumption
	GameState.water_net = net
	GameState.water = maxf(0.0, GameState.water + net)
