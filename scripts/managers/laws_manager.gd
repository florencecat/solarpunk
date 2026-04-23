class_name LawsManager
extends Node

# ─── ID законов ───────────────────────────────────────────────────────────────
const LAW_WATER_RATIONING = 0
const LAW_HARSH_REGIME    = 1
const LAW_WATER_CASTES    = 2
const LAW_OPEN_BORDERS    = 3

const ALL_LAWS = [LAW_WATER_RATIONING, LAW_HARSH_REGIME, LAW_WATER_CASTES, LAW_OPEN_BORDERS]

## Метаданные законов (только примитивы — строки, массивы строк)
const LAW_META = {
	0: {
		"name":        "Нормирование воды",
		"description": "Суточное потребление снижается, но рабочие работают хуже и растёт недовольство.",
		"effects":     ["−30% потребление воды", "−15% выработка рабочих", "+1 недовол./день"],
	},
	1: {
		"name":        "Жёсткий режим",
		"description": "Принудительный труд даёт больше продукции, но сильно бьёт по лояльности.",
		"effects":     ["Бунт длится 1 день", "+25% выработка рабочих", "+3 недовол./день"],
	},
	2: {
		"name":        "Водные касты",
		"description": "Элита рационирует воду, снижая потребление, но это разозлит народ.",
		"effects":     ["−15% потребление воды", "+2 недовол./день", "×0.5 восстановление морали"],
	},
	3: {
		"name":        "Открытые границы",
		"description": "Беженцы охотнее вступают в поселение, но требуют больше воды.",
		"effects":     ["+1 житель каждые 2 хода (если мораль > 50)", "+20% потребление воды"],
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
