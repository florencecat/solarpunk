extends Node

signal turn_started(turn: int)
signal turn_ended(turn: int)

signal water_changed(amount: float, net: float)
signal dirty_water_changed(amount: float)

signal population_changed(count: int)
signal happiness_changed(happiness: float, thirst: float, discontent: float)
signal riot_started()
signal riot_ended()

signal game_event(event: Dictionary)      # {turn, title, description, severity 0–3}
signal survivor_arrived(count: int)

signal law_enacted(law_id: int)
signal law_repealed(law_id: int)

signal building_placed(building_type: int, coords: Vector2i)
signal building_type_selected(building_type: int)  # -1 = снять выбор
