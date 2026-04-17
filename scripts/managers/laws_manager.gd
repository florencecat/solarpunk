class_name LawsManager
extends Node

# ─── ID законов ───────────────────────────────────────────────────────────────
const LAW_WATER_RATIONING = 0
const LAW_HARSH_REGIME    = 1
const LAW_WATER_CASTES    = 2

const ALL_LAWS = [LAW_WATER_RATIONING, LAW_HARSH_REGIME, LAW_WATER_CASTES]

## Метаданные законов (только примитивы — строки, массивы строк)
const LAW_META = {
	0: {
		"name":        "Нормирование воды",
		"description": "Суточное потребление воды снижается на 30%, но растёт недовольство.",
		"effects":     ["−30% потребление воды", "+1 недовольство/день"],
	},
	1: {
		"name":        "Жёсткий режим",
		"description": "Бунты подавляются за 1 день силовыми методами, но ценой доверия.",
		"effects":     ["Бунт длится 1 день", "+10 недовольства при подавлении"],
	},
	2: {
		"name":        "Водные касты",
		"description": "Элита (20%) получает двойную норму. Остальные — меньше.",
		"effects":     ["Элита: ×2 вода", "Народ: ×0.75 вода", "+1.5 недовольства/день"],
	},
}

# ─── API ──────────────────────────────────────────────────────────────────────

func enact_law(law_id: int) -> void:
	if GameState.active_laws.get(law_id, false):
		return
	GameState.active_laws[law_id] = true
	EventBus.law_enacted.emit(law_id)
	var meta: Dictionary = LAW_META[law_id]
	EventBus.game_event.emit({
		"turn":        GameState.current_turn,
		"title":       "Принят закон: " + meta.name,
		"description": meta.description,
		"severity":    1,
	})

func repeal_law(law_id: int) -> void:
	if not GameState.active_laws.get(law_id, false):
		return
	GameState.active_laws.erase(law_id)
	EventBus.law_repealed.emit(law_id)
	EventBus.game_event.emit({
		"turn":        GameState.current_turn,
		"title":       "Отменён закон: " + LAW_META[law_id].name,
		"description": "Закон больше не действует.",
		"severity":    0,
	})

func is_active(law_id: int) -> bool:
	return GameState.active_laws.get(law_id, false)
