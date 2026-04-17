class_name PopulationManager
extends Node

const THIRST_GAIN:   float = 8.0    # за ход при нехватке воды
const THIRST_LOSS:   float = 10.0   # за ход при достаточном запасе
const DISCORD_RATE:  float = 0.12   # множитель жажды → недовольство
const DISCORD_COOL:  float = 2.5    # снижение недовольства/ход при комфорте
const RIOT_THRESH:   float = 80.0   # порог бунта
const RIOT_DURATION: int   = 3      # дней

func process_turn() -> void:
	_update_thirst()
	_update_discontent()
	_check_riot()
	GameState.happiness = clampf(100.0 - GameState.discontent, 0.0, 100.0)
	EventBus.happiness_changed.emit(
		GameState.happiness, GameState.thirst, GameState.discontent)

# ─────────────────────────────────────────────────────────────────────────────

func _update_thirst() -> void:
	if GameState.water <= 0.0 or GameState.water_net < 0.0:
		# Нехватка воды — жажда растёт
		var sev = 0.55 if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false) else 1.0
		GameState.thirst = minf(100.0, GameState.thirst + THIRST_GAIN * sev)
	else:
		# Воды достаточно
		GameState.thirst = maxf(0.0, GameState.thirst - THIRST_LOSS)

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
		GameState.discontent = maxf(0.0, GameState.discontent - DISCORD_COOL)

	# Штрафы законов
	if GameState.active_laws.get(LawsManager.LAW_WATER_RATIONING, false):
		GameState.discontent = minf(100.0, GameState.discontent + 1.0)
	if GameState.active_laws.get(LawsManager.LAW_WATER_CASTES, false):
		GameState.discontent = minf(100.0, GameState.discontent + 1.5)

func _check_riot() -> void:
	if GameState.is_rioting or GameState.discontent < RIOT_THRESH:
		return
	GameState.is_rioting        = true
	GameState.riot_turns_remaining = RIOT_DURATION

	if GameState.active_laws.get(LawsManager.LAW_HARSH_REGIME, false):
		GameState.riot_turns_remaining = 1
		GameState.discontent = minf(100.0, GameState.discontent + 10.0)
		_log("Бунт подавлен силой!",
			"Жёсткий режим заглушил волнения, но злоба зреет.", 2)
	else:
		_log("⚠  Б У Н Т !",
			"Население взбунтовалось! Жажда и лишения довели людей до предела.", 3)

	EventBus.riot_started.emit()

func _log(title: String, desc: String, sev: int) -> void:
	EventBus.game_event.emit({
		"turn": GameState.current_turn, "title": title,
		"description": desc, "severity": sev,
	})
