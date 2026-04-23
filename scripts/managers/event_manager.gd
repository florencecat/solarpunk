class_name EventManager
extends Node

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sandstorm_turns: int = 0

const CHANCE_SANDSTORM  = 0.07
const CHANCE_SOURCE_DRY = 0.04
const CHANCE_CARAVAN    = 0.11
const CHANCE_MARAUDER   = 0.05
const CHANCE_SURVIVORS  = 0.13
const CHANCE_DISEASE    = 0.05
const CHANCE_RICH_TRADE = 0.08
const GRACE_PERIOD      = 3    # первые N ходов без случайных событий

# Типы отложенных событий-выборов
const CHOICE_NONE        = -1
const CHOICE_DISEASE     = 0
const CHOICE_RICH_TRADE  = 1

var _pending_choice_type: int = CHOICE_NONE

func _ready() -> void:
	_rng.randomize()
	EventBus.choice_resolved.connect(_on_choice_resolved)

func process_turn() -> void:
	_tick_sandstorm()
	if GameState.current_turn <= GRACE_PERIOD:
		return
	_roll_sandstorm()
	_roll_source_dry()
	_roll_caravan()
	_roll_marauder()
	_roll_survivors()
	# Кризисные события с выбором — только если ничего не ждёт
	if not GameState.pending_choice:
		_roll_disease()
		_roll_rich_trade()

# ─────────────────────────────────────────────────────────────────────────────

func _tick_sandstorm() -> void:
	if _sandstorm_turns <= 0:
		return
	_sandstorm_turns -= 1
	if _sandstorm_turns == 0:
		GameState.sandstorm_active = false
		_log("Буря утихла", "Небо прояснилось. Производство воды восстановлено.", 1)

func _roll_sandstorm() -> void:
	if _sandstorm_turns > 0 or _rng.randf() >= CHANCE_SANDSTORM:
		return
	_sandstorm_turns = _rng.randi_range(2, 5)
	GameState.sandstorm_active = true
	var penalty = _rng.randf_range(0.35, 0.60)
	# Штраф к уже вычисленному производству этого хода
	GameState.water_production *= (1.0 - penalty)
	GameState.water_net = GameState.water_production - GameState.water_consumption
	GameState.water = maxf(0.0, GameState.water + GameState.water_net)
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	# Буря повреждает все здания
	_damage_buildings_from_storm()
	_log("Песчаная буря!",
		"Буря накрыла оазис! Производство снижено на %d%% на %d дней. Здания повреждены!" % [
			int(penalty * 100.0), _sandstorm_turns], 2)

func _damage_buildings_from_storm() -> void:
	for coords: Vector2i in GameState.hex_tiles:
		var tile: HexTile = GameState.hex_tiles[coords]
		if tile.building < 0:
			continue
		if not GameState.building_durability.has(coords):
			GameState.building_durability[coords] = 100.0
		var dmg: float = _rng.randf_range(5.0, 15.0)
		GameState.building_durability[coords] = maxf(
			10.0, GameState.building_durability[coords] - dmg)

func _roll_source_dry() -> void:
	if _rng.randf() >= CHANCE_SOURCE_DRY:
		return
	var sources: Array = []
	for coords: Vector2i in GameState.hex_tiles:
		if GameState.hex_tiles[coords].tile_type == HexTile.TILE_WATER_SOURCE:
			sources.append(coords)
	if sources.is_empty():
		return
	var target: Vector2i = sources[_rng.randi() % sources.size()]
	GameState.hex_tiles[target].set_tile_type(HexTile.TILE_DRY_SOURCE)
	_log("Источник иссяк!",
		"Подземный пласт воды истощился. Насосы в этом районе потеряли мощность.", 2)

func _roll_caravan() -> void:
	if not _has_caravan_station() or _rng.randf() >= CHANCE_CARAVAN:
		return
	var gain = float(_rng.randi_range(30, 90))
	GameState.water += gain
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("Торговый караван!",
		"Торговцы доставили %.0f единиц воды в обмен на припасы." % gain, 0)

func _roll_marauder() -> void:
	if not _has_caravan_station() or _rng.randf() >= CHANCE_MARAUDER:
		return
	var stolen = minf(GameState.water * 0.20, 60.0)
	GameState.water = maxf(0.0, GameState.water - stolen)
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("Мародёры атакуют!",
		"Банда налётчиков захватила торговый пост и похитила %.0f ед. воды." % stolen, 2)

func _roll_survivors() -> void:
	if GameState.survivors_waiting > 0 or _rng.randf() >= CHANCE_SURVIVORS:
		return
	var count = _rng.randi_range(3, 18)
	GameState.survivors_waiting = count
	EventBus.survivor_arrived.emit(count)
	_log("Выжившие у ворот",
		"%d человек добрались до оазиса. Принять их в поселение?" % count, 1)

func _roll_disease() -> void:
	if _rng.randf() >= CHANCE_DISEASE:
		return
	if GameState.diamonds < 1.0:
		# Нет алмазов = нет выбора, эпидемия неизбежна
		var deaths: int = maxi(1, int(float(GameState.population) * 0.12))
		GameState.population = maxi(0, GameState.population - deaths)
		EventBus.population_changed.emit(GameState.population)
		_log("Эпидемия!",
			"Болезнь унесла %d жителей. Нехватка медикаментов." % deaths, 3)
		return
	# Есть алмазы — предлагаем выбор
	_pending_choice_type = CHOICE_DISEASE
	GameState.pending_choice = true
	EventBus.choice_event_pending.emit({
		"title":    "Вспышка болезни",
		"desc":     "В поселении вспыхнула эпидемия. Потратить 1 алмаз на лекарства или принять потери?",
		"choice_a": "Лекарства (−1 алмаз)",
		"choice_b": "Пережить (−12% населения)",
	})

func _roll_rich_trade() -> void:
	if _rng.randf() >= CHANCE_RICH_TRADE:
		return
	if GameState.scrap < 10.0:
		return
	_pending_choice_type = CHOICE_RICH_TRADE
	GameState.pending_choice = true
	var water_gain: int = _rng.randi_range(30, 60)
	# Сохраняем объём в переменную события через описание (разбираем при резолве)
	EventBus.choice_event_pending.emit({
		"title":    "Выгодная сделка",
		"desc":     "Торговцы предлагают %d ед. воды за 10 лома. Принять?" % water_gain,
		"choice_a": "Принять (−10 лома, +%d воды)" % water_gain,
		"choice_b": "Отказать",
		"_water_gain": water_gain,  # служебное поле для резолва
	})

func _on_choice_resolved(choice: int) -> void:
	if _pending_choice_type == CHOICE_NONE:
		return
	match _pending_choice_type:
		CHOICE_DISEASE:
			if choice == 0:
				# A: потратить алмаз
				GameState.diamonds = maxf(0.0, GameState.diamonds - 1.0)
				EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
				_log("Эпидемия остановлена",
					"Алмазы обменяны на лекарства. Вспышка подавлена.", 1)
			else:
				# B: принять потери
				var deaths: int = maxi(1, int(float(GameState.population) * 0.12))
				GameState.population = maxi(0, GameState.population - deaths)
				EventBus.population_changed.emit(GameState.population)
				_log("Жертвы эпидемии",
					"Болезнь унесла %d жителей." % deaths, 2)

		CHOICE_RICH_TRADE:
			if choice == 0:
				# A: принять сделку — ищем water_gain из события
				var water_gain: int = _rng.randi_range(30, 60)
				GameState.scrap = maxf(0.0, GameState.scrap - 10.0)
				GameState.water += float(water_gain)
				EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
				EventBus.water_changed.emit(GameState.water, GameState.water_net)
				_log("Сделка заключена",
					"Получено %.0f ед. воды за 10 лома." % float(water_gain), 0)
			else:
				_log("Сделка отклонена", "Торговцы ушли ни с чем.", 0)

	_pending_choice_type = CHOICE_NONE
	GameState.pending_choice = false

func _has_caravan_station() -> bool:
	for coords: Vector2i in GameState.hex_tiles:
		if GameState.hex_tiles[coords].building == GameState.BUILDING_CARAVAN_STATION:
			return true
	return false

func _log(title: String, desc: String, sev: int) -> void:
	EventBus.game_event.emit({
		"turn": GameState.current_turn, "title": title,
		"description": desc, "severity": sev,
	})
