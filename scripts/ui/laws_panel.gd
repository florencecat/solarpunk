extends FloatingWindow

var _laws_mgr: LawsManager
var _btn_map:  Dictionary = {}   # law_id → {enact: Button, repeal: Button}

func _get_title() -> String:
	return "⚖  Законы"

func _build_content(_vbox: VBoxContainer) -> void:
	pass  # заполняется в setup()

## Вызывается из main.gd после добавления узла в дерево
func setup(mgr: LawsManager) -> void:
	_laws_mgr = mgr
	for law_id: int in LawsManager.ALL_LAWS:
		_content_vbox.add_child(_law_entry(law_id))
	EventBus.law_enacted.connect(_refresh_buttons)
	EventBus.law_repealed.connect(_refresh_buttons)

func _law_entry(law_id: int) -> Control:
	var meta: Dictionary = LawsManager.LAW_META[law_id]
	var entry = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)

	var name_lbl = Label.new()
	name_lbl.text = meta.name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	entry.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = meta.description
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.56, 0.56, 0.56))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(desc_lbl)

	for fx: String in meta.effects:
		var fl = Label.new()
		fl.text = "• " + fx
		fl.add_theme_font_size_override("font_size", 10)
		fl.add_theme_color_override("font_color", Color(0.52, 0.90, 0.52))
		entry.add_child(fl)

	var btns = HBoxContainer.new()
	entry.add_child(btns)

	var enact = Button.new()
	enact.text = "Принять"
	enact.pressed.connect(func(): _laws_mgr.enact_law(law_id))
	btns.add_child(enact)

	var repeal = Button.new()
	repeal.text = "Отменить"
	repeal.disabled = true
	repeal.pressed.connect(func(): _laws_mgr.repeal_law(law_id))
	btns.add_child(repeal)

	_btn_map[law_id] = {"enact": enact, "repeal": repeal}

	entry.add_child(HSeparator.new())
	return entry

func _refresh_buttons(_law_id: int) -> void:
	for lid: int in _btn_map:
		var active = _laws_mgr.is_active(lid)
		_btn_map[lid].enact.disabled  = active
		_btn_map[lid].repeal.disabled = not active
