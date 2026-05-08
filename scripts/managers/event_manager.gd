class_name EventManager
extends Node

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sandstorm_turns: int = 0

const CHANCE_SANDSTORM   = 0.07
const CHANCE_SOURCE_DRY  = 0.04
const CHANCE_CARAVAN     = 0.11
const CHANCE_MARAUDER    = 0.05
const CHANCE_SURVIVORS   = 0.13
const CHANCE_DISEASE     = 0.05
const CHANCE_RICH_TRADE  = 0.08
const CHANCE_RAIDERS     = 0.06   # шанс каждый ход после льготного периода
const GRACE_PERIOD       = 3      # первые N ходов без случайных событий

const RAIDER_WARN_TURNS  = 6      # ходов предупреждения
const RAIDER_WARN_BONUS  = 3      # доп. ходы за каждую сторожевую башню

func _ready() -> void:
	_rng.randomize()

func process_turn() -> void:
	_tick_sandstorm()
	_tick_raider_threat()
	if GameState.current_turn <= GRACE_PERIOD:
		return
	_roll_sandstorm()
	_roll_source_dry()
	_roll_caravan()
	_roll_marauder()
	_roll_survivors()
	_roll_raider_threat()
	_roll_disease()
	_roll_rich_trade()

# ─── Буря ────────────────────────────────────────────────────────────────────
# Буря НЕ показывает центральное уведомление — только полоску в HUD и лог.

func _tick_sandstorm() -> void:
	if _sandstorm_turns <= 0:
		return
	_sandstorm_turns -= 1
	if _sandstorm_turns == 0:
		GameState.sandstorm_active = false
		_log("Буря утихла", "Небо прояснилось. Производство воды восстановлено.", 0)

func _roll_sandstorm() -> void:
	if _sandstorm_turns > 0 or _rng.randf() >= CHANCE_SANDSTORM:
		return
	_sandstorm_turns = _rng.randi_range(2, 5)
	GameState.sandstorm_active = true
	var penalty = _rng.randf_range(0.35, 0.60)
	GameState.water_production *= (1.0 - penalty)
	GameState.water_net = GameState.water_production - GameState.water_consumption
	GameState.water = maxf(0.0, GameState.water + GameState.water_net)
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_damage_buildings_from_storm()
	# Буря — только лог (HUD показывает полоску ⛈), центральное окно не нужно
	_log("⛈ Песчаная буря!",
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

# ─── Иссякание источника ─────────────────────────────────────────────────────

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
	_log("Источник иссяк!", "Подземный пласт воды истощился. Насосы в этом районе потеряли мощность.", 2)
	EventBus.notification_event.emit({
		"title":    "💧 Источник иссяк",
		"desc":     "Подземный пласт воды истощился. Насосы на этом тайле потеряли мощность — переключи их на новое место.",
		"severity": 2,
	})

# ─── Торговый кар-ван ─────────────────────────────────────────────────────────

func _roll_caravan() -> void:
	var caravan_chance: float = CHANCE_CARAVAN + GameState.get_meta("research_bonuses", {}).get("caravan_bonus", 0.0)
	if not _has_caravan_station() or _rng.randf() >= caravan_chance:
		return
	var gain: float = float(_rng.randi_range(30, 90))
	GameState.water += gain
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("Торговый кар-ван!", "Торговцы доставили %.0f единиц воды в обмен на припасы." % gain, 0)
	EventBus.notification_event.emit({
		"title":    "🐪 Торговый кар-ван прибыл!",
		"desc":     "Торговцы обменяли припасы на %.0f единиц воды. Запасы пополнены." % gain,
		"severity": 0,
	})

# ─── Мародёры ────────────────────────────────────────────────────────────────

func _roll_marauder() -> void:
	if not _has_caravan_station() or _rng.randf() >= CHANCE_MARAUDER:
		return
	var stolen: float = minf(GameState.water * 0.20, 60.0)
	GameState.water = maxf(0.0, GameState.water - stolen)
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("Мародёры атакуют!", "Банда налётчиков захватила торговый пост и похитила %.0f ед. воды." % stolen, 2)
	EventBus.notification_event.emit({
		"title":    "🗡 Мародёры напали!",
		"desc":     "Банда налётчиков захватила торговый пост и похитила %.0f единиц воды.\n\nРассмотри постройку Стен и обучение Охраны." % stolen,
		"severity": 2,
	})

# ─── Выжившие ────────────────────────────────────────────────────────────────

func _roll_survivors() -> void:
	if GameState.survivors_waiting > 0 or _rng.randf() >= CHANCE_SURVIVORS:
		return
	var count: int = _rng.randi_range(3, 18)
	GameState.survivors_waiting = count
	EventBus.choice_event_pending.emit({
		"title":    "🚶 Выжившие у ворот",
		"desc":     ("%d человек добрались до твоего оазиса.\n\n" +
					 "Принять: население вырастет, но потребуется больше воды и еды.\n" +
					 "Отказать: +5 к недовольству жителей.") % count,
		"severity": 1,
		"choice_a": "Принять  (+%d чел.)" % count,
		"choice_b": "Отказать  (+5 недовол.)",
		"callback": _resolve_survivors,
	})

func _resolve_survivors(choice: int) -> void:
	if choice == 0:
		GameState.population += GameState.survivors_waiting
		EventBus.population_changed.emit(GameState.population)
		_log("Выжившие приняты",
			"%d человек вступили в поселение." % GameState.survivors_waiting, 0)
	else:
		GameState.discontent = minf(100.0, GameState.discontent + 5.0)
		_log("Ворота закрыты",
			"Вы отвергли выживших. Моральный дух поселенцев пошатнулся.", 1)
	GameState.survivors_waiting = 0

# ─── Эпидемия ────────────────────────────────────────────────────────────────

func _roll_disease() -> void:
	if _rng.randf() >= CHANCE_DISEASE:
		return
	if GameState.diamonds < 1.0:
		var deaths: int = maxi(1, int(float(GameState.population) * 0.12))
		GameState.population = maxi(0, GameState.population - deaths)
		EventBus.population_changed.emit(GameState.population)
		_log("Эпидемия!", "Болезнь унесла %d жителей. Нехватка медикаментов." % deaths, 3)
		EventBus.notification_event.emit({
			"title":    "🦠 Эпидемия!",
			"desc":     "Болезнь прокатилась по поселению — погибло %d жителей.\n\nМедикаментов нет (нужен хотя бы 1 алмаз). Добудь алмазы в шахтах." % deaths,
			"severity": 3,
		})
		return
	EventBus.choice_event_pending.emit({
		"title":    "🦠 Вспышка болезни",
		"desc":     "В поселении вспыхнула эпидемия.\n\nПотратить 1 алмаз на лекарства — или принять потери?",
		"severity": 3,
		"choice_a": "Лекарства  (−1 алмаз)",
		"choice_b": "Пережить  (−12% населения)",
		"callback": _resolve_disease,
	})

func _resolve_disease(choice: int) -> void:
	if choice == 0:
		GameState.diamonds = maxf(0.0, GameState.diamonds - 1.0)
		EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
		_log("Эпидемия остановлена",
			"Алмазы обменяны на лекарства. Вспышка подавлена.", 1)
	else:
		var deaths: int = maxi(1, int(float(GameState.population) * 0.12))
		GameState.population = maxi(0, GameState.population - deaths)
		EventBus.population_changed.emit(GameState.population)
		_log("Жертвы эпидемии", "Болезнь унесла %d жителей." % deaths, 2)

# ─── Выгодная сделка ─────────────────────────────────────────────────────────

func _roll_rich_trade() -> void:
	if _rng.randf() >= CHANCE_RICH_TRADE:
		return
	if GameState.scrap < 10.0:
		return
	var gain: int = _rng.randi_range(30, 60)
	EventBus.choice_event_pending.emit({
		"title":    "💰 Выгодная сделка",
		"desc":     "Торговцы предлагают %d ед. воды за 10 единиц металлолома.\n\nСоглашаться?" % gain,
		"severity": 1,
		"choice_a": "Принять  (−10 мет, +%d воды)" % gain,
		"choice_b": "Отказать",
		"callback": _resolve_rich_trade.bind(gain),
	})

func _resolve_rich_trade(choice: int, gain: int) -> void:
	if choice == 0:
		GameState.scrap = maxf(0.0, GameState.scrap - 10.0)
		GameState.water += float(gain)
		EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
		EventBus.water_changed.emit(GameState.water, GameState.water_net)
		_log("Сделка заключена", "Получено %d ед. воды за 10 лома." % gain, 0)
	else:
		_log("Сделка отклонена", "Торговцы ушли ни с чем.", 0)

# ─── Рейдеры ─────────────────────────────────────────────────────────────────

func _roll_raider_threat() -> void:
	if GameState.raider_threat_turns > 0:
		return
	if _rng.randf() >= CHANCE_RAIDERS:
		return
	var towers: int     = _count_building(GameState.BUILDING_WATCHTOWER)
	var warn_turns: int = RAIDER_WARN_TURNS + towers * RAIDER_WARN_BONUS
	GameState.raider_threat_turns = warn_turns
	EventBus.raider_threat_changed.emit(warn_turns)
	_log("Рейдеры на горизонте!",
		"Разведка обнаружила вооружённый отряд. Нападение ожидается через %d ходов." % warn_turns, 2)
	EventBus.notification_event.emit({
		"title":    "⚔ Рейдеры на горизонте!",
		"desc":     ("Разведчики заметили вооружённый отряд.\n\n" +
					 "До нападения: %d ходов.\n\n" +
					 "Подготовься: Стены (+3 обороны), Охрана (+1 обороны), Торговый пост (переговоры).") % warn_turns,
		"severity": 2,
	})

func _tick_raider_threat() -> void:
	if GameState.raider_threat_turns <= 0:
		return
	GameState.raider_threat_turns -= 1
	EventBus.raider_threat_changed.emit(GameState.raider_threat_turns)
	if GameState.raider_threat_turns == 0:
		_trigger_raid()

func _trigger_raid() -> void:
	# Если уже ждём другого выбора — отложить рейд на 2 хода
	if GameState.pending_choice:
		GameState.raider_threat_turns = 2
		EventBus.raider_threat_changed.emit(2)
		return
	var tribute: int      = maxi(50, int(GameState.water * 0.25))
	var walls: int        = _count_building(GameState.BUILDING_WALL)
	var has_caravan: bool = _has_caravan_station()

	EventBus.choice_event_pending.emit({
		"title":    "⚔ Нападение рейдеров!",
		"desc":     ("Вооружённый отряд у стен оазиса.\n\n" +
					 "Стены: %d   Охрана: %d\n" +
					 "Сила обороны: %d (нужно ≥ 10 для победы без потерь)") % [
					 	walls, GameState.guards, walls * 3 + GameState.guards],
		"severity": 3,
		"choice_a": "Откупиться  (−%d воды)" % tribute,
		"choice_b": "Дать бой  [сила: %d]" % (walls * 3 + GameState.guards),
		"choice_c": "Переговоры  (−30 мет)" if (has_caravan and GameState.scrap >= 30.0) else "",
		"callback": _resolve_raid_choice.bind(tribute),
	})

func _resolve_raid_choice(choice: int, tribute: int) -> void:
	match choice:
		0: _resolve_raid_pay(tribute)
		1: _resolve_raid_fight()
		2: _resolve_raid_negotiate()

func _resolve_raid_pay(tribute: int) -> void:
	GameState.water = maxf(0.0, GameState.water - float(tribute))
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("Дань уплачена",
		"Рейдеры взяли %.0f ед. воды и ушли. Поселение уцелело." % float(tribute), 1)

func _resolve_raid_fight() -> void:
	var walls:    int = _count_building(GameState.BUILDING_WALL)
	var strength: int = walls * 3 + GameState.guards
	if strength >= 10:
		var losses: int = maxi(0, _rng.randi_range(0, GameState.guards / 2))
		GameState.guards = maxi(0, GameState.guards - losses)
		if losses > 0:
			EventBus.specialists_changed.emit(GameState.engineers, GameState.guards)
		_log("Рейдеры отбиты!",
			"Охрана и стены удержали атаку. Потери: %d охранников." % losses, 1)
	else:
		var pop_loss:   int   = maxi(2, int(float(GameState.population) * 0.10))
		var water_loss: float = minf(GameState.water * 0.30, 80.0)
		GameState.population = maxi(0, GameState.population - pop_loss)
		GameState.water      = maxf(0.0, GameState.water - water_loss)
		EventBus.population_changed.emit(GameState.population)
		EventBus.water_changed.emit(GameState.water, GameState.water_net)
		_damage_one_building()
		_log("Поражение в битве!",
			"Рейдеры прорвались! Погибло %d жителей, украдено %.0f воды." % [pop_loss, water_loss], 3)

func _resolve_raid_negotiate() -> void:
	GameState.scrap = maxf(0.0, GameState.scrap - 30.0)
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	if _rng.randf() < 0.65:
		_log("Переговоры успешны",
			"30 лома хватило убедить рейдеров. Они ушли мирно.", 0)
	else:
		var water_loss: float = minf(GameState.water * 0.15, 40.0)
		GameState.water = maxf(0.0, GameState.water - water_loss)
		EventBus.water_changed.emit(GameState.water, GameState.water_net)
		_log("Переговоры сорвались",
			"Рейдеры взяли лом и всё равно украли %.0f воды." % water_loss, 2)

func _damage_one_building() -> void:
	var bld_tiles: Array = []
	for coords: Vector2i in GameState.hex_tiles:
		if GameState.hex_tiles[coords].building >= 0:
			bld_tiles.append(coords)
	if bld_tiles.is_empty():
		return
	var target: Vector2i = bld_tiles[_rng.randi() % bld_tiles.size()]
	GameState.building_durability[target] = maxf(
		10.0, GameState.building_durability.get(target, 100.0) - _rng.randf_range(20.0, 40.0))

# ─── Обработка выборов ───────────────────────────────────────────────────────
# Каждое событие с выбором несёт собственный callback в словаре —
# _on_choice_resolved больше не нужен. Вся логика разрешения описана выше.

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _has_caravan_station() -> bool:
	for coords: Vector2i in GameState.hex_tiles:
		if GameState.hex_tiles[coords].building == GameState.BUILDING_CARAVAN_STATION:
			return true
	return false

func _count_building(b_type: int) -> int:
	var count: int = 0
	for coords: Vector2i in GameState.hex_tiles:
		if GameState.hex_tiles[coords].building == b_type:
			count += 1
	return count

func _log(title: String, desc: String, sev: int) -> void:
	EventBus.game_event.emit({
		"turn": GameState.current_turn, "title": title,
		"description": desc, "severity": sev,
	})
