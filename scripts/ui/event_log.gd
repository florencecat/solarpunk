extends FloatingWindow

const MAX_ENTRIES = 25

var _list:   VBoxContainer
var _scroll: ScrollContainer

func _get_title() -> String:
	return "📋  Журнал событий"

func _ready() -> void:
	super._ready()
	EventBus.game_event.connect(_on_event)

func _build_content(vbox: VBoxContainer) -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical        = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode     = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	_scroll.add_child(_list)

func _on_event(event: Dictionary) -> void:
	var sev: int = clampi(event.get("severity", 0), 0, 3)
	var color: Color = [
		Color(0.72, 0.72, 0.72),
		Color(0.95, 0.82, 0.28),
		Color(0.95, 0.42, 0.12),
		Color(1.00, 0.18, 0.18),
	][sev]

	var entry = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 1)

	var day_lbl = Label.new()
	day_lbl.text = "День %d" % event.get("turn", 0)
	day_lbl.add_theme_font_size_override("font_size", 10)
	day_lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.42))
	entry.add_child(day_lbl)

	var title_lbl = Label.new()
	title_lbl.text = event.get("title", "")
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", color)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(title_lbl)

	var desc: String = event.get("description", "")
	if not desc.is_empty():
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(desc_lbl)

	entry.add_child(HSeparator.new())

	_list.add_child(entry)
	_list.move_child(entry, 0)

	while _list.get_child_count() > MAX_ENTRIES:
		_list.get_child(_list.get_child_count() - 1).queue_free()

	await get_tree().process_frame
	_scroll.scroll_vertical = 0
