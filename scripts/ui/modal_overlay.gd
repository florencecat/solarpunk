## Центрированное уведомление / модальное окно в стиле FloatingWindow.
## Поддерживает два режима:
##   • info   — только кнопка «Понятно» (notification_event)
##   • choice — кнопки A / B / C с callback (choice_event_pending)
## Пока окно видимо — GameState.pending_choice = true, ход заблокирован.
## Несколько событий за один ход ставятся в очередь и показываются по очереди.
extends Control

# ─── Переменные ───────────────────────────────────────────────────────────────

var _backdrop:     ColorRect
var _title_panel:  PanelContainer
var _title_sbox:   StyleBoxFlat
var _title_lbl:    Label
var _icon_lbl:     Label
var _desc_lbl:     Label
var _btn_row:      HBoxContainer
var _btn_a:        Button
var _btn_b:        Button
var _btn_c:        Button

var _callback: Callable = Callable()
var _queue:    Array    = []   # Array[Dictionary]

# ─── Цвета по severity (0=info, 1=warning, 2=danger, 3=critical) ──────────────
const SEV_BAR_COLORS: Array = [
	Color(0.08, 0.18, 0.10, 0.98),   # 0 зелёный
	Color(0.18, 0.14, 0.05, 0.98),   # 1 янтарный
	Color(0.22, 0.09, 0.04, 0.98),   # 2 оранжевый
	Color(0.26, 0.04, 0.04, 0.98),   # 3 красный
]
const SEV_TITLE_COLORS: Array = [
	Color(0.55, 0.95, 0.65),          # 0
	Color(0.98, 0.82, 0.35),          # 1
	Color(0.98, 0.55, 0.20),          # 2
	Color(1.00, 0.38, 0.32),          # 3
]

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()
	visible = false
	EventBus.choice_event_pending.connect(_on_choice_event)
	EventBus.notification_event.connect(_on_notification_event)
	EventBus.game_over.connect(_on_game_over)
	EventBus.victory.connect(_on_victory)
	EventBus.act_changed.connect(_on_act_changed)

# ─── Построение интерфейса ───────────────────────────────────────────────────

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Затемнение фона
	_backdrop             = ColorRect.new()
	_backdrop.color       = Color(0.0, 0.0, 0.0, 0.68)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Центрирование
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Внешний контейнер окна (заголовок + тело)
	var win_vbox = VBoxContainer.new()
	win_vbox.add_theme_constant_override("separation", 0)
	win_vbox.custom_minimum_size = Vector2(420, 0)
	center.add_child(win_vbox)

	# ── Полоса заголовка ──────────────────────────────────────────────────────
	_title_panel = PanelContainer.new()
	_title_sbox  = StyleBoxFlat.new()
	_title_sbox.bg_color                   = SEV_BAR_COLORS[1]
	_title_sbox.corner_radius_top_left     = 8
	_title_sbox.corner_radius_top_right    = 8
	_title_sbox.content_margin_left        = 16.0
	_title_sbox.content_margin_right       = 16.0
	_title_sbox.content_margin_top         = 9.0
	_title_sbox.content_margin_bottom      = 9.0
	_title_panel.add_theme_stylebox_override("panel", _title_sbox)
	win_vbox.add_child(_title_panel)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 16)
	_title_lbl.add_theme_color_override("font_color", SEV_TITLE_COLORS[1])
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(_title_lbl)

	# ── Область содержимого ───────────────────────────────────────────────────
	var content_panel = PanelContainer.new()
	var cs            = StyleBoxFlat.new()
	cs.bg_color                    = Color(0.07, 0.07, 0.12, 0.97)
	cs.corner_radius_bottom_left   = 8
	cs.corner_radius_bottom_right  = 8
	cs.content_margin_left         = 22.0
	cs.content_margin_right        = 22.0
	cs.content_margin_top          = 16.0
	cs.content_margin_bottom       = 16.0
	content_panel.add_theme_stylebox_override("panel", cs)
	win_vbox.add_child(content_panel)

	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	content_panel.add_child(cv)

	_icon_lbl = Label.new()
	_icon_lbl.add_theme_font_size_override("font_size", 36)
	_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_lbl.visible = false
	cv.add_child(_icon_lbl)

	_desc_lbl = Label.new()
	_desc_lbl.add_theme_font_size_override("font_size", 13)
	_desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	_desc_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(376, 0)
	cv.add_child(_desc_lbl)

	_btn_row           = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 10)
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(_btn_row)

	_btn_a = _make_btn("OK",  _on_btn_a)
	_btn_b = _make_btn("",    _on_btn_b)
	_btn_c = _make_btn("",    _on_btn_c)
	_btn_row.add_child(_btn_a)
	_btn_row.add_child(_btn_b)
	_btn_row.add_child(_btn_c)

# ─── Очередь ─────────────────────────────────────────────────────────────────

func _enqueue(item: Dictionary) -> void:
	_queue.append(item)
	GameState.pending_choice = true   # блокируем ход немедленно, не ждём следующего кадра
	if not visible:
		call_deferred("_show_next")   # меняем видимость UI вне текущей цепочки сигналов

func _show_next() -> void:
	if _queue.is_empty():
		visible               = false
		GameState.pending_choice = false
		return
	_apply_item(_queue.pop_front())
	visible                  = true
	GameState.pending_choice = true

func _apply_item(item: Dictionary) -> void:
	var sev: int = clampi(item.get("severity", 1), 0, 3)

	_title_sbox.bg_color = SEV_BAR_COLORS[sev]
	_title_panel.add_theme_stylebox_override("panel", _title_sbox)
	_title_lbl.text = item.get("title", "")
	_title_lbl.add_theme_color_override("font_color", SEV_TITLE_COLORS[sev])

	var icon: String = item.get("icon", "")
	_icon_lbl.text    = icon
	_icon_lbl.visible = icon != ""

	_desc_lbl.text = item.get("desc", "")

	var ta: String = item.get("btn_a", "Понятно")
	var tb: String = item.get("btn_b", "")
	var tc: String = item.get("btn_c", "")
	_btn_a.text    = ta;  _btn_a.visible = ta != ""
	_btn_b.text    = tb;  _btn_b.visible = tb != ""
	_btn_c.text    = tc;  _btn_c.visible = tc != ""

	_callback = item.get("callback", Callable())

# ─── Публичное API (используется в коде, не в сигналах) ──────────────────────

## Информационное уведомление (не требует выбора).
func show_notification(title: String, desc: String,
					   severity: int = 1, icon: String = "") -> void:
	_enqueue({"title": title, "desc": desc, "severity": severity, "icon": icon,
			  "btn_a": "Понятно"})

## Уведомление с выбором.
func show_modal(title: String, desc: String,
				btn_a_text: String = "OK", btn_b_text: String = "",
				callback: Callable = Callable(), btn_c_text: String = "",
				severity: int = 1) -> void:
	_enqueue({"title": title, "desc": desc, "severity": severity,
			  "btn_a": btn_a_text, "btn_b": btn_b_text, "btn_c": btn_c_text,
			  "callback": callback})

# ─── Обработчики сигналов ────────────────────────────────────────────────────

func _on_choice_event(event: Dictionary) -> void:
	# Используем callback из события (если есть), иначе — сигнал choice_resolved
	var cb: Callable = event.get("callback", Callable())
	if not cb.is_valid():
		cb = func(c): EventBus.choice_resolved.emit(c)
	_enqueue({
		"title":    event.get("title", ""),
		"desc":     event.get("desc", ""),
		"severity": event.get("severity", 1),
		"icon":     event.get("icon", ""),
		"btn_a":    event.get("choice_a", "Подтвердить"),
		"btn_b":    event.get("choice_b", "Отказать"),
		"btn_c":    event.get("choice_c", ""),
		"callback": cb,
	})

func _on_notification_event(event: Dictionary) -> void:
	_enqueue({
		"title":    event.get("title", ""),
		"desc":     event.get("desc", ""),
		"severity": event.get("severity", 1),
		"icon":     event.get("icon", ""),
		"btn_a":    "Понятно",
	})

func _on_game_over(reason: String, score: int) -> void:
	_enqueue({
		"title":    "КОНЕЦ ИГРЫ",
		"desc":     "%s\n\nИтоговые очки: %d" % [reason, score],
		"severity": 3, "icon": "💀",
		"btn_a":    "Закрыть",
	})

func _on_victory(project_id: int, victory_text: String) -> void:
	var mp_names = ["Древо Жизни", "Солнечный Шпиль", "Великий Исход"]
	var mp_name  = mp_names[project_id] if project_id < mp_names.size() else "Мегапроект"
	_enqueue({
		"title":    "✨ ПОБЕДА!  «%s»" % mp_name,
		"desc":     victory_text + "\n\nОчки: %d" % GameState.get_score(),
		"severity": 0, "icon": "🌟",
		"btn_a":    "Закрыть",
	})

func _on_act_changed(act: int) -> void:
	var titles = {
		2: "Акт II: Расширение",
		3: "Акт III: Финал",
	}
	var descs = {
		2: "Поселение выстояло. Открыты технологии второго акта — исследуйте их, пока давление не выросло.",
		3: "Время завершить историю. Выберите Мегапроект в панели 🏛 и начните строительство.",
	}
	var icons  = { 2: "📈", 3: "🏆" }
	if titles.has(act):
		_enqueue({
			"title":    titles[act], "desc": descs[act],
			"severity": 1,           "icon": icons[act],
			"btn_a":    "Понятно",
		})

# ─── Кнопки ──────────────────────────────────────────────────────────────────

func _on_btn_a() -> void:
	if _callback.is_valid(): _callback.call(0)
	_show_next()

func _on_btn_b() -> void:
	if _callback.is_valid(): _callback.call(1)
	_show_next()

func _on_btn_c() -> void:
	if _callback.is_valid(): _callback.call(2)
	_show_next()

func _make_btn(label: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(140, 36)
	b.pressed.connect(cb)
	return b
