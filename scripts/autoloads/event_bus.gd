extends Node

@warning_ignore("unused_signal")
signal turn_started(turn: int)
@warning_ignore("unused_signal")
signal turn_ended(turn: int)

@warning_ignore("unused_signal")
signal water_changed(amount: float, net: float)
@warning_ignore("unused_signal")
signal dirty_water_changed(amount: float)

@warning_ignore("unused_signal")
signal population_changed(count: int)
@warning_ignore("unused_signal")
signal happiness_changed(happiness: float, thirst: float, discontent: float)
@warning_ignore("unused_signal")
signal riot_started()
@warning_ignore("unused_signal")
signal riot_ended()

@warning_ignore("unused_signal")
signal game_event(event: Dictionary)      # {turn, title, description, severity 0–3}
@warning_ignore("unused_signal")
signal survivor_arrived(count: int)

@warning_ignore("unused_signal")
signal law_enacted(law_id: int)
@warning_ignore("unused_signal")
signal law_repealed(law_id: int)

@warning_ignore("unused_signal")
signal building_placed(building_type: int, coords: Vector2i)
@warning_ignore("unused_signal")
signal building_type_selected(building_type: int)  # -1 = снять выбор

@warning_ignore("unused_signal")
signal resources_changed(sand: float, scrap: float, diamonds: float)
@warning_ignore("unused_signal")
signal tile_selected(coords: Vector2i)              # Vector2i(-99,-99) = снять выбор
@warning_ignore("unused_signal")
signal workers_changed(coords: Vector2i, count: int)
@warning_ignore("unused_signal")
signal assign_workers_request(coords: Vector2i, target: int)

@warning_ignore("unused_signal")
signal game_over(reason: String, score: int)
@warning_ignore("unused_signal")
signal choice_event_pending(event: Dictionary)  # {title, desc, choice_a, choice_b}
@warning_ignore("unused_signal")
signal choice_resolved(choice: int)             # 0 = A (первый), 1 = B (второй)

@warning_ignore("unused_signal")
signal act_changed(act: int)                    # 1, 2, 3
@warning_ignore("unused_signal")
signal research_started(tech_id: int)
@warning_ignore("unused_signal")
signal tech_researched(tech_id: int)
@warning_ignore("unused_signal")
signal megaproject_started(project_id: int)
@warning_ignore("unused_signal")
signal megaproject_progress(turns_left: int, turns_total: int)
@warning_ignore("unused_signal")
signal victory(project_id: int, victory_text: String)
