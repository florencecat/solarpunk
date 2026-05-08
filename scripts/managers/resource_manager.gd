class_name ResourceManager
extends Node

const BASE_CONSUME_PER_PERSON: float = 0.5   # воды/день/чел
const FOOD_CONSUME_PER_PERSON: float = 0.4   # еды/день/чел
const FARM_WATER_COST: float         = 0.8   # воды потребляет ферма на рабочего
const SOLAR_ENERGY_PER_WORKER: float = 8.0   # энергии/день/рабочий
const BATTERY_CAPACITY: float        = 50.0  # ёмкость одного аккумулятора
# Минимальный КПД зданий без питания (manual/wood power)
const NO_ENERGY_EFF_MULT: float      = 0.65

func process_turn() -> void:
	_decay_durability()
	_update_night_cycle()
	_calc_energy()
	_calc_production()
	_calc_consumption()
	_apply_net()
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	EventBus.dirty_water_changed.emit(GameState.dirty_water)
	EventBus.food_changed.emit(GameState.food, GameState.food_net)
	EventBus.energy_changed.emit(GameState.energy_stored,
		GameState.energy_stored - _prev_energy_stored, GameState.energy_ratio)

var _prev_energy_stored: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────

func _update_night_cycle() -> void:
	var was_night: bool = GameState.is_night
	GameState.is_night = (GameState.current_turn % 8 >= 6)
	if GameState.is_night != was_night:
		EventBus.night_changed.emit(GameState.is_night)

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

# ─── Энергия ─────────────────────────────────────────────────────────────────

func _calc_energy() -> void:
	_prev_energy_stored   = GameState.energy_stored
	var production: float = 0.0
	var capacity:   float = 0.0
	var consumption: float = 0.0

	var global_mult: float = 1.0 + _rb("global_mult")

	for coords: Vector2i in GameState.hex_tiles:
		var tile: HexTile = GameState.hex_tiles[coords]
		if tile.building < 0:
			continue

		var workers: int   = GameState.tile_workers.get(coords, 0)
		var dur: float     = GameState.building_durability.get(coords, 100.0)
		var eff: float     = dur / 100.0 * global_mult

		match tile.building:
			GameState.BUILDING_SOLAR_PANEL:
				if workers > 0 and not GameState.is_night and not GameState.sandstorm_active:
					production += SOLAR_ENERGY_PER_WORKER * float(workers) * eff
			GameState.BUILDING_BATTERY:
				capacity += BATTERY_CAPACITY  # passive, no workers needed

		# Energy consumption of powered buildings
		match tile.building:
			GameState.BUILDING_PURIFIER:
				if workers > 0:
					consumption += 3.0 * float(workers)
			GameState.BUILDING_CONDENSER:
				if workers > 0:
					consumption += 2.0 * float(workers)
			GameState.BUILDING_FARM:
				if workers > 0:
					consumption += 1.0 * float(workers)

	GameState.energy_capacity = capacity
	# Draw from storage then production to meet demand
	var available: float = production + GameState.energy_stored
	GameState.energy_ratio = minf(1.0, available / maxf(1.0, consumption))
	# Consume from storage to cover deficit
	var net: float = production - consumption
	GameState.energy_stored = clampf(
		GameState.energy_stored + net, 0.0, capacity)

# ─── Производство воды и еды ──────────────────────────────────────────────────

func _calc_production() -> void:
	var water_gain: float = 0.0
	var food_gain:  float = 0.0

	# Глобальный бонус от техники «Солнечная энергетика»
	var global_mult: float = 1.0 + _rb("global_mult")
	# Инженеры дают +5% на рабочего к выработке добывающих зданий
	var eng_bonus: float = 1.0 + float(GameState.engineers) * 0.05

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
				water_gain += pump_gain

			GameState.BUILDING_PURIFIER:
				# Бонус технологии «Водоочистка»
				var purifier_mult: float = 1.0 + _rb("purifier_mult")
				var energy_eff: float   = _energy_eff()
				var to_purify := minf(GameState.dirty_water,
					12.0 * eff * adj * purifier_mult * energy_eff * eng_bonus)
				GameState.dirty_water -= to_purify
				water_gain += to_purify * 0.80

			GameState.BUILDING_CONDENSER:
				# Бонус технологии «Атмосферная конденсация»
				var condenser_mult: float = 1.0 + _rb("condenser_mult")
				var energy_eff: float     = _energy_eff()
				water_gain += 2.0 * eff * adj * condenser_mult * energy_eff

			GameState.BUILDING_FARM:
				# Ферма: потребляет воду, производит еду; нужна энергия для ламп
				var workers: int    = GameState.tile_workers.get(coords, 0)
				var energy_eff: float = _energy_eff()
				var farm_food: float = 3.5 * float(workers) * eff * adj * energy_eff * eng_bonus
				# Ферма потребляет воду (стоимость орошения)
				var water_cost: float = FARM_WATER_COST * float(workers)
				if GameState.water >= water_cost:
					GameState.water -= water_cost
					food_gain += farm_food
				else:
					# Не хватает воды — ферма работает на минимуме
					food_gain += farm_food * 0.25

	GameState.water_production = water_gain
	GameState.food_net         = food_gain - float(GameState.population) * FOOD_CONSUME_PER_PERSON

func _calc_consumption() -> void:
	var base: float = float(GameState.population) * BASE_CONSUME_PER_PERSON
	if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false):
		base *= 0.70
	if GameState.active_laws.get(LawsManager.LAW_WATER_CASTES, false):
		base *= 0.85
	if GameState.active_laws.get(LawsManager.LAW_OPEN_BORDERS, false):
		base *= 1.20
	# Охрана потребляет дополнительно
	base += float(GameState.guards) * 0.3
	GameState.water_consumption = base

func _apply_net() -> void:
	var evap: float = GameState.water * GameState.WATER_EVAP_RATE
	GameState.water_evaporation = evap
	var net: float  = GameState.water_production - GameState.water_consumption
	GameState.water_net = net
	GameState.water = maxf(0.0, GameState.water + net - evap)
	# Еда
	GameState.food = maxf(0.0, GameState.food + GameState.food_net)

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
			GameState.BUILDING_FARM:
				# Рядом с источником воды — ферма работает лучше
				if nb.tile_type == HexTile.TILE_WATER_SOURCE or nb.tile_type == HexTile.TILE_OASIS:
					mult += 0.25
	return maxf(0.10, mult)

# ─── Хелперы ──────────────────────────────────────────────────────────────────

## КПД от энергообеспечения (1.0 если достаточно, иначе между NO_ENERGY_EFF_MULT и 1.0)
func _energy_eff() -> float:
	return lerpf(NO_ENERGY_EFF_MULT, 1.0, GameState.energy_ratio)

func _rb(key: String) -> float:
	return GameState.get_meta("research_bonuses", {}).get(key, 0.0)
