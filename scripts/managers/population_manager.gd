class_name PopulationManager
extends Node

const THIRST_GAIN:   float = 8.0    # за ход при нехватке воды
const THIRST_LOSS:   float = 10.0   # за ход при достаточном запасе
const DISCORD_RATE:  float = 0.12   # множитель жажды → недовольство
const DISCORD_COOL:  float = 2.5    # снижение недовольства/ход при комфорте
const RIOT_THRESH:   float = 80.0   # порог бунта
const RIOT_DURATION: int   = 3

const GROWTH_INTERVAL:   int   = 5     # проверка прироста каждые N ходов
const GROWTH_HAPPI_MIN:  float = 60.0  # минимальная мораль для прироста
const GROWTH_WATER_MIN:  float = 50.0  # минимальный запас воды для прироста
const DEATH_THIRST_MIN:  float = 65.0  # жажда выше этого → начинают умирать

func process_turn() -> void:
	_update_thirst()
	_check_thirst_deaths()
	_update_discontent()
	_check_riot()
	_check_growth()
	_check_open_borders_growth()
	_check_game_over()
	GameState.happiness = clampf(100.0 - GameState.discontent, 0.0, 100.0)
	EventBus.happiness_changed.emit(
		GameState.happiness, GameState.thirst, GameState.discontent)

# ─────────────────────────────────────────────────────────────────────────────

func _update_thirst() -> void:
	if GameState.water <= 0.0 or GameState.water_net < 0.0:
		var sev = 0.55 if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false) else 1.0
		GameState.thirst = minf(100.0, GameState.thirst + THIRST_GAIN * sev)
	else:
		GameState.thirst = maxf(0.0, GameState.thirst - THIRST_LOSS)

func _check_thirst_deaths() -> void:
	if GameState.thirst < DEATH_THIRST_MIN:
		return
	# Чем сильнее жажда, тем больше смертей: 1–4% от населения
	var death_rate = (GameState.thirst - DEATH_THIRST_MIN) / (100.0 - DEATH_THIRST_MIN) * 0.04
	var deaths     = maxi(1, int(float(GameState.population) * death_rate))
	GameState.population = maxi(0, GameState.population - deaths)
	EventBus.population_changed.emit(GameState.population)
	_log("Гибель от жажды",
		"%d жителей погибли от обезвоживания. Немедленно обеспечьте воду!" % deaths, 3)

func _update_discontent() -> void:
	# Тик бунта
	if GameState.is_rioting:
		GameState.riot_turns_remaining -= 1
		if GameState.riot_turns_remaining <= 0:
			GameState.is_rioting = false
			EventBus.riot_ended.emit()
			_log("Бунт подавлен", "Порядок восстановлен в поселении.", 1)

	# Жажда → недовольство
	if GameState.thirst > 20.0:
		var gain = (GameState.thirst - 20.0) * DISCORD_RATE * 0.1
		GameState.discontent = minf(100.0, GameState.discontent + gain)
	else:
		# Восстановление — замедлено при Водных кастах
		var cool = DISCORD_COOL
		if GameState.active_laws.get(LawsManager.LAW_WATER_CASTES, false):
			cool *= 0.5
		GameState.discontent = maxf(0.0, GameState.discontent - cool)

	# Штрафы законов
	if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false):
		GameState.discontent = minf(100.0, GameState.discontent + 1.0)
	if GameState.active_laws.get(LawsManager.LAW_HARSH_REGIME, false):
		GameState.discontent = minf(100.0, GameState.discontent + 3.0)
	if GameState.active_laws.get(LawsManager.LAW_WATER_CASTES, false):
		GameState.discontent = minf(100.0, GameState.discontent + 2.0)

func _check_riot() -> void:
	if GameState.is_rioting or GameState.discontent < RIOT_THRESH:
		return
	GameState.is_rioting          = true
	GameState.riot_turns_remaining = RIOT_DURATION

	if GameState.active_laws.get(LawsManager.LAW_HARSH_REGIME, false):
		GameState.riot_turns_remaining = 1
		GameState.discontent = minf(100.0, GameState.discontent + 10.0)
		_log("Бунт подавлен силой!",
			"Жёсткий режим заглушил волнения, но злоба зреет.", 2)
		# Бунт также уничтожает часть рабочих (дезертиры)
		var deserters = maxi(1, GameState.get_assigned_workers() / 5)
		GameState.population = maxi(0, GameState.population - deserters)
		EventBus.population_changed.emit(GameState.population)
	else:
		# Бунт: часть рабочих покидает посты
		for coords in GameState.tile_workers.keys():
			GameState.tile_workers[coords] = 0
			if GameState.hex_tiles.has(coords):
				GameState.hex_tiles[coords].update_workers(0)
		EventBus.workers_changed.emit(Vector2i.ZERO, 0)
		_log("БУНТ!",
			"Население взбунтовалось! Рабочие покинули посты. Восстановите порядок.", 3)

	EventBus.riot_started.emit()

func _check_growth() -> void:
	GameState.growth_timer += 1
	if GameState.growth_timer < GROWTH_INTERVAL:
		return
	GameState.growth_timer = 0
	if GameState.happiness < GROWTH_HAPPI_MIN or GameState.water < GROWTH_WATER_MIN:
		return
	var newcomers = maxi(1, int(float(GameState.population) * 0.025))
	GameState.population += newcomers
	EventBus.population_changed.emit(GameState.population)
	_log("Прирост населения",
		"Жизнь в оазисе привлекает людей. Прибыло %d новых жителей." % newcomers, 0)

func _check_open_borders_growth() -> void:
	if not GameState.active_laws.get(LawsManager.LAW_OPEN_BORDERS, false):
		return
	if GameState.happiness < 50.0:
		return
	# +1 житель каждые 2 хода
	if GameState.current_turn % 2 == 0:
		GameState.population += 1
		EventBus.population_changed.emit(GameState.population)

func _check_game_over() -> void:
	if GameState.is_game_over or GameState.population > 0:
		return
	GameState.is_game_over = true
	EventBus.game_over.emit("Все жители погибли.", GameState.get_score())

func _log(title: String, desc: String, sev: int) -> void:
	EventBus.game_event.emit({
		"turn": GameState.current_turn, "title": title,
		"description": desc, "severity": sev,
	})
