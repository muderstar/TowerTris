extends Node
class_name BuffChoseArea

## Buff选择区域控制器
## 负责Back返回主菜单和Start开始游戏的功能
## 管理 ToggleBox 列表，支持批量读取切换状态
## 支持 buff/debuff 倍率累加（additive stacking）：勾选后自动计算并显示实际数值变化
## 多个选框影响同一 key 时，倍率按累加方式叠加：1.0 + (m₁-1.0) + (m₂-1.0) + ...


# ========== 节点引用 ==========

@export var back_button: Button
@export var start_button: Button

# 滚动容器
@export var top_scroll_container: ScrollContainer
@export var middle_scroll_container: ScrollContainer

# 中部 buff 列表容器
@export var buff_list: VBoxContainer

# Buff配置数据文件路径（读取互斥组/显示文本/倍率配置）
const BUFF_DATA_PATH: String = "res://GameSaveData/BuffChoseData.json"

# 已勾选框对应的 Label 字典（box_id -> Label）
var _label_by_id: Dictionary = {}

# 合并效果汇总 Label（显示所有唯一 key 的累加倍率，去重合并）
var _summary_label: Label = null

## 互斥选框组配置：同一组内的选框互斥，选中一个则其他自动取消
## 组名 -> [box_id1, box_id2, ...]
var _mutually_exclusive_groups: Dictionary = {}

# box_id 到显示文本的映射
var _display_text_map: Dictionary = {}

# 挑战组合配置（从BuffChoseData.json的BuffCombination读取）
# 组合名 -> {"Info": 显示文本, "Group": [组名列表], "Color": [r,g,b](可选)}
var _combination_map: Dictionary = {}

# 组合分组（从BuffChoseData.json的BuffGroup读取）：组名 -> [box_id, ...]
var _buff_group_map: Dictionary = {}

# 挑战组合 Label（显示在buff列表末尾）
var _combination_label: Label = null

# ========== Buff/Debuff 倍率配置 ==========

## TowerController 初始数据字典（可在编辑器中修改，点击 START 时自动存入 GlobalData）
@export var tower_init_data: Dictionary = {
	# ---- APM / Stage ----
	total_apm = 70.0,
	stage_percent_apm = [0.01,0.02,0.05,0.1,0.25,0.4,0.55,0.7,0.8,0.9,1.0],
	extra_percent_apm = 0.0,
	
	# ---- Garbage ----
	stage_garbage_time = [10,8,7,7,6,6,5,5,4,3,2,2,2,1,1,1,0.5],
	garbage_collect_percent_array = [0.4,0.3,0.2,0.1,0.1,0.2,0.2,0.3,0.3,0.4],
	garbage_divide_percent_array = [0.8,0.6,0.4,0.2,0.2,0.1,0.1,0,0.1,0.2,0.3],
	pressure_mult_array = [1,1,1,1,1,1,1,1,1,1,1.25,1.5,2,2.5,3,4,5,6,7],
	garbage_hole_change_percent_array = [0.1,0.1,0.1,0.2,0.4,0.5,0.6,0.7,0.8,0.9],
	send_mult_attack = 1.0,
	
	# Gravity
	gravity_drop_time_array = [5],
	
	# ---- Tower Climb ----
	tower_lowest_speed = 0.1,
	tower_dropped_speed = 0.01,
	tower_dropped_mult = [1,1,1,1,1,1.1,1.2,1.3,1.4,1.5,1.7,1.9,2],
	attack_to_meter_mult = 0.2,
	attack_to_speed_mult = 0.1,
	
	# ---- Big Attack / Warning ----
	warning_count = 4,
	segment_line = 4,
	big_attack_delay = 4.0,
	
	# ---- Kill Reward ----
	killer_spike = 10,
	kill_possible_percent = 0.15,
	kill_reward = [10, 4],
	
	#额外数据
	extra_data_dict = {}
}

## Buff/Debuff 配置（直接赋值倍率，不再引用 tower_init_data）
## 值直接写倍率/原始值，float 类型的值会与 tower_init_data 对应键相乘累加
## 键不在 tower_init_data 中时，整个值键对会存入 extra_data_dict
var _buff_config_map: Dictionary = {}

# ToggleBox 节点引用（可在编辑器中拖入或由代码动态添加）
@export var toggle_boxes: Array[ToggleBox] = []


# ========== 场景路径 ==========

@export var main_menu_scene_path: String = "res://Tscns/main_menu.tscn"
@export var game_scene_path: String = "res://Tscns/mino.tscn"

# ========== UI 风格（原始 / 卡片） ==========

## 设置键：当前选择风格（"original" 或 "cards"），默认 original
const UI_STYLE_SETTING_KEY: String = "buff_ui_style"

## 卡片素材前缀（TETR.IO zenith-mod 卡片，从 tetrio_offline 拷贝）
const CARD_ASSET_PREFIX: String = "res://Assets/zenith_mods/"

## 卡片模式只展示已在游戏内实现的 mod（box_id 需存在于 BuffChoseData / ToggleGrid）。
## 卡片 → 勾选框映射：点卡片即切换对应 ToggleBox。
## 交互仿 TETR.IO zenith 卡片选择：选中时卡片快速 360° 翻两下（前→后→前，约0.25s）
## 并停留在正面，叠加选择描边（outline.png，呼吸发光）。背面/红色 throb 仅用于
## TETR.IO 的 reversed 模式，本游戏不需要。
const CARD_MODS: Array = [
	{"box_id": "Allspin_1", "name": "全旋", "icon": "allspin", "back": "allspin-back", "tone": "card_tone_allspin"},
	{"box_id": "rAS_1", "name": "逆位全旋", "icon": "allspin", "back": "allspin-back", "tone": "card_tone_allspin_reverse", "reversed": true},
	{"box_id": "Invisible_1", "name": "隐形", "icon": "invisible", "back": "invisible-back", "tone": "card_tone_invisible"},
	{"box_id": "NoHold_1", "name": "无暂存", "icon": "nohold", "back": "nohold-back", "tone": "card_tone_nohold"},
	{"box_id": "Volatile", "name": "力量", "icon": "volatile", "back": "volatile-back", "tone": "card_tone_volatile"},
	{"box_id": "Doublehole_1", "name": "双洞", "icon": "doublehole", "back": "doublehole-back", "tone": "card_tone_doublehole"},
	{"box_id": "Messy_1", "name": "混乱", "icon": "messy", "back": "messy-back", "tone": "card_tone_messy"},
]

var _style_is_cards: bool = false
var _style_button: Button = null
var _card_panel: Control = null
var _card_map: Dictionary = {}  # box_id -> 卡片引用字典 {card, front, back, outline, btn}
var _card_tweens: Dictionary = {}  # box_id -> 翻转 tween
var _card_visual_state: Dictionary = {}  # box_id -> 上次已应用的选中状态（避免未变化的卡片也翻）
# 【rAS】卡片反向状态：box_id -> bool（true=逆位/反向激活）。仅 "reversed" 标记的卡片可用。
var _card_reversed_state: Dictionary = {}
# 卡片长按计时：box_id -> {timer: float, holding: bool, press_pos: Vector2}
var _card_hold_state: Dictionary = {}
const CARD_REVERSE_HOLD_TIME: float = 3.0  # 长按3秒 → 卡片反向（逆位模式）


# ========== UI 缩放相关 ==========

# Panel 引用（CanvasLayer 下全屏面板，用于居中缩放）
var _panel: Panel = null


# ========== 数据加载 ==========

## 从BuffChoseData.json读取互斥组/显示文本/倍率配置，覆盖默认值
## 文件不存在或解析失败时保留代码中的默认配置
func _load_buff_data_from_json() -> void:
	if not FileAccess.file_exists(BUFF_DATA_PATH):
		# 已注释（调试噪音）：print("BuffChoseData.json 不存在，使用默认配置: ", BUFF_DATA_PATH)
		return
	
	var file = FileAccess.open(BUFF_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("无法打开 BuffChoseData.json: ", BUFF_DATA_PATH)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("解析 BuffChoseData.json 失败: ", json.get_error_message())
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("BuffChoseData.json 格式错误")
		return
	
	# BuffConflick → 互斥选框组
	if data.has("BuffConflick") and typeof(data["BuffConflick"]) == TYPE_DICTIONARY:
		_mutually_exclusive_groups = data["BuffConflick"]
	
	# BuffInfo → 显示文本
	if data.has("BuffInfo") and typeof(data["BuffInfo"]) == TYPE_DICTIONARY:
		_display_text_map = data["BuffInfo"]
	
	# BuffChange → 倍率配置
	if data.has("BuffChange") and typeof(data["BuffChange"]) == TYPE_DICTIONARY:
		_buff_config_map = data["BuffChange"]
	
	# BuffCombination → 挑战组合配置
	if data.has("BuffCombination") and typeof(data["BuffCombination"]) == TYPE_DICTIONARY:
		_combination_map = data["BuffCombination"]
	
	# BuffGroup → 组合分组（组名 -> box_id列表）
	if data.has("BuffGroup") and typeof(data["BuffGroup"]) == TYPE_DICTIONARY:
		_buff_group_map = data["BuffGroup"]


## 内置兜底配置：某些buff不依赖JSON配置，代码内置默认值
## Talentless（无才能）：勾选后传递 NoSpin=true，禁用整个Spin判定
func _apply_builtin_fallbacks() -> void:
	if not _display_text_map.has("Talentless"):
		_display_text_map["Talentless"] = "无才能：禁用Spin判定"
	if not _buff_config_map.has("Talentless"):
		_buff_config_map["Talentless"] = {"NoSpin": true}


# ========== 生命周期 ==========

func _ready():
	# 先读取BuffChoseData.json覆盖默认配置
	_load_buff_data_from_json()
	# 内置兜底配置（Talentless无才能，不依赖JSON）
	_apply_builtin_fallbacks()
	
	_panel = get_node_or_null("../Panel") as Panel
	# 若未在编辑器中配置toggle_boxes，则自动发现场景中的ToggleBox节点
	_discover_toggle_boxes()
	_connect_signals()
	_connect_toggle_boxes()
	
	# 应用 UI 缩放（UIScaler 已移除，固定 scale=1.0）
	_apply_ui_scale()
	
	# 初始化 UI 风格（默认原始，可在设置中持久化）
	_setup_ui_style()
	
	# 更新已有标签显示（如 default_checked 为 true 的选框）
	_update_all_labels()
	_update_summary_label()
	_update_combination_label()
	
	# Demo: 打印初始状态
	#print("ToggleBox 数量: ", toggle_boxes.size())
	for tb in toggle_boxes:
		pass
		#print("  [%s] checked=%s value=%s" % [tb.box_id, tb.is_checked_state(), tb.value])


## 应用 UI 缩放：Panel 居中缩放，子区域内容自适应
func _apply_ui_scale(_new_scale: float = -1.0) -> void:
	var s: float = 1.0
	
	# 缩放 Panel 并居中（3 个 ColorRect 作为子节点自动继承缩放）
	if _panel:
		_panel.scale = Vector2(s, s)
		_panel.pivot_offset = _panel.size / 2.0
		var vp: Vector2 = get_tree().root.size
		_panel.position = (vp - _panel.size * s) / 2.0
	
	# 调整 BackButton 和 StartButton 的位置和字体（不 scale——那会导致重叠）
	if back_button:
		back_button.add_theme_font_size_override("font_size", max(12, int(16 * s)))
		# BottomRightArea 内相对位置按比例调整
		back_button.offset_left = 40 * s
		back_button.offset_top = 80 * s
		back_button.offset_right = 40 * s + 140 * s
		back_button.offset_bottom = 80 * s + 50 * s
	if start_button:
		start_button.add_theme_font_size_override("font_size", max(12, int(16 * s)))
		start_button.offset_left = 40 * s
		start_button.offset_top = 150 * s
		start_button.offset_right = 40 * s + 140 * s
		start_button.offset_bottom = 150 * s + 50 * s
	
	# 调整 ToggleBox 的大小
	for tb in toggle_boxes:
		if tb:
			tb.box_size = max(16, int(32 * s))
			tb.custom_minimum_size = Vector2(tb.box_size, tb.box_size)
			tb.size = Vector2(tb.box_size, tb.box_size)
			tb.queue_redraw()
	
	# 调整标签字体大小
	for _box_id: String in _label_by_id:
		var label: Label = _label_by_id[_box_id] as Label
		if label:
			label.add_theme_font_size_override("font_size", max(12, int(20 * s)))
	
	# 调整汇总标签字体
	if _summary_label:
		_summary_label.add_theme_font_size_override("font_size", max(12, int(18 * s)))
	
	# 调整挑战组合标签字体
	if _combination_label:
		_combination_label.add_theme_font_size_override("font_size", max(12, int(20 * s)))


# ========== UI 风格（原始 / 卡片） ==========

## 构建风格切换按钮 + 卡片面板（默认原始风格，选择会持久化到 user_setting）
func _setup_ui_style() -> void:
	var canvas: CanvasLayer = get_parent() as CanvasLayer
	if canvas == null:
		return
	# 风格切换按钮（置于右上角，两种风格下都可见）
	_style_button = Button.new()
	_style_button.toggle_mode = true
	_style_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_style_button.offset_left = -170.0
	_style_button.offset_top = 8.0
	_style_button.offset_right = -8.0
	_style_button.offset_bottom = 40.0
	_style_button.toggled.connect(func(_on: bool) -> void:
		var want_cards: bool = _style_button.button_pressed
		_set_ui_style(want_cards)
		var settings := UserSetting.load_settings()
		settings[UI_STYLE_SETTING_KEY] = "cards" if want_cards else "original"
		UserSetting.save_settings(settings)
	)
	canvas.add_child.call_deferred(_style_button)
	# 卡片面板（覆盖原 TopArea 区域）
	_card_panel = Control.new()
	_card_panel.anchor_left = 0.0
	_card_panel.anchor_top = 0.0
	_card_panel.anchor_right = 1.0
	_card_panel.anchor_bottom = 0.6
	_card_panel.offset_left = 0.0
	_card_panel.offset_top = 0.0
	_card_panel.offset_right = 0.0
	_card_panel.offset_bottom = 0.0
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child.call_deferred(_card_panel)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	hbox.anchor_left = 0.0
	hbox.anchor_right = 1.0
	hbox.anchor_top = 0.5
	hbox.anchor_bottom = 0.5
	hbox.offset_left = 0.0
	hbox.offset_top = -84.0
	hbox.offset_right = 0.0
	hbox.offset_bottom = 84.0
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_panel.add_child(hbox)
	for mod: Dictionary in CARD_MODS:
		var refs: Dictionary = _build_card(mod)
		_card_map[mod["box_id"]] = refs
		hbox.add_child(refs["card"] as Control)
	# 应用持久化风格（默认 original）
	var saved: String = str(UserSetting.load_settings().get(UI_STYLE_SETTING_KEY, "original"))
	_set_ui_style(saved == "cards")
	_sync_card_states(false)

## 切换 UI 风格：cards → 显示卡片面板、隐藏原始勾选网格；original → 反之
func _set_ui_style(cards: bool) -> void:
	_style_is_cards = cards
	if _style_button:
		_style_button.text = "风格: 卡片" if cards else "风格: 原始"
		_style_button.button_pressed = cards
	if _card_panel:
		_card_panel.visible = cards
	# 原始勾选网格所在区域（CanvasLayer/TopArea）
	var top_area: Control = get_node_or_null("../TopArea") as Control
	if top_area:
		top_area.visible = not cards

## 构建单张 mod 卡片（仿 TETR.IO zenith 卡片选择）：
##   正面=mod 图标，背面=反向形态（仅翻转动画瞬间使用，最终停留正面）；
##   选中时叠加选择描边（outline.png，呼吸发光）。
## 点击由透明 Toggle 按钮驱动，联动对应 ToggleBox。
func _build_card(mod: Dictionary) -> Dictionary:
	var card := Control.new()
	card.custom_minimum_size = Vector2(120, 168)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var refs := {
		"card": card, "front": null, "back": null, "outline": null, "btn": null,
	}
	# 正面 / 背面 / 选择描边三层纹理（按顺序叠加）
	var front := _make_card_texture(card, str(mod["icon"]) + ".png")
	var back := _make_card_texture(card, str(mod["back"]) + ".png")
	var outline := _make_card_texture(card, "outline.png")
	back.visible = false
	outline.visible = false
	refs.front = front
	refs.back = back
	refs.outline = outline
	# 透明 Toggle 按钮（接收点击，视觉层在下方）
	var btn := Button.new()
	btn.toggle_mode = true
	btn.flat = true
	btn.text = ""
	btn.custom_minimum_size = Vector2(120, 168)
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	refs.btn = btn
	var box_id: String = str(mod["box_id"])
	var is_reversible: bool = bool(mod.get("reversed", false))
	# 【rAS】可反向卡片：长按3秒 → 反向激活；短按 → 正常选中
	if is_reversible:
		btn.button_down.connect(func() -> void:
			_card_hold_state[box_id] = {"timer": 0.0, "holding": true, "press_pos": get_viewport().get_mouse_position()}
			_reverse_hold_press(box_id)
		)
		btn.button_up.connect(func() -> void:
			_card_hold_state[box_id] = {"timer": 0.0, "holding": false}
		)
		btn.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and not event.pressed:
				# 松开：若尚未达到反向阈值 → 视为普通点击
				if _card_hold_state.has(box_id) and _card_hold_state[box_id]["holding"]:
					_card_hold_state[box_id]["holding"] = false
		)
	btn.toggled.connect(func(on: bool) -> void:
		# 反向状态下点击 → 取消（不触发 normal 选中）
		if is_reversible and _card_reversed_state.get(box_id, false):
			if on:
				btn.set_pressed_no_signal(false)
				_set_card_reversed(box_id, false)
			return
		# 长按反向后的按钮状态强制为选中（反向激活即视为勾选）
		if is_reversible and _card_reversed_state.get(box_id, false):
			btn.set_pressed_no_signal(true)
			set_toggle_checked(box_id, true)
			return
		set_toggle_checked(box_id, on)
	)
	card.add_child(btn)
	card.pivot_offset = Vector2(60, 84)
	return refs

## 创建一张铺满卡片的 TextureRect
func _make_card_texture(parent: Control, file_name: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(CARD_ASSET_PREFIX + file_name)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr

## 卡片选中视觉（仿 TETR.IO zenith 卡片选择）：
##   选中 → 快速 360° 翻两下（前→后→前，约0.24s）停留正面 + 选择描边呼吸发光；
##   取消 → 直接移除描边（不翻转，同 TETR.IO deselect）。
## animate=false 用于初始化时直接设置状态，不做动画。
func _card_set_selected(box_id: String, refs: Dictionary, selected: bool, animate: bool = true) -> void:
	var btn: Button = refs.btn as Button
	if btn.button_pressed != selected:
		btn.set_pressed_no_signal(selected)
	var card: Control = refs.card as Control
	var front: TextureRect = refs.front as TextureRect
	var back: TextureRect = refs.back as TextureRect
	var outline: TextureRect = refs.outline as TextureRect
	# 打断上一次翻转
	if _card_tweens.has(box_id) and _card_tweens[box_id]:
		(_card_tweens[box_id] as Tween).kill()
	# 选择描边显隐 + 呼吸发光
	outline.visible = selected
	if selected:
		_loop_pulse(outline, 0.45, 1.0, 1.4)
	else:
		_loop_pulse_stop(outline)
		outline.modulate.a = 1.0
	# 无动画时直接停在正面
	if not animate:
		front.visible = true
		back.visible = false
		card.scale.x = 1.0
		return
	# 取消选中：不翻转，直接停正面
	if not selected:
		front.visible = true
		back.visible = false
		return
	# 选中：快速翻两下（前→后→前），最终停在正面（仿 TETR.IO ZenithCardRot 360°）
	var tween := create_tween()
	_card_tweens[box_id] = tween
	front.visible = true
	back.visible = false
	tween.tween_property(card, "scale:x", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		front.visible = false
		back.visible = true
	)
	tween.tween_property(card, "scale:x", 1.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		back.visible = false
		front.visible = true
	)
	tween.tween_property(card, "scale:x", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		front.visible = false
		back.visible = true
	)
	tween.tween_property(card, "scale:x", 1.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		back.visible = false
		front.visible = true
	)
	tween.tween_callback(func():
		if _card_tweens.has(box_id) and _card_tweens[box_id] == tween:
			_card_tweens[box_id] = null
	)

## 让层做无限呼吸脉动（透明度）
func _loop_pulse(tr: TextureRect, min_a: float, max_a: float, period: float) -> void:
	_loop_pulse_stop(tr)
	tr.set_meta("pulse_tween", create_tween().set_loops())
	var tw: Tween = tr.get_meta("pulse_tween")
	tw.tween_property(tr, "modulate:a", max_a, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tr, "modulate:a", min_a, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _loop_pulse_stop(tr: TextureRect) -> void:
	if tr.has_meta("pulse_tween"):
		var tw: Tween = tr.get_meta("pulse_tween") as Tween
		if tw and tw.is_valid():
			tw.kill()
		tr.remove_meta("pulse_tween")

## 查询某个卡片 box_id 对应的专属音调名（无则返回空串）
func _card_tone_name(box_id: String) -> String:
	for mod: Dictionary in CARD_MODS:
		if str(mod["box_id"]) == box_id:
			return str(mod.get("tone", ""))
	return ""

## 每帧推进卡片长按计时：达到 CARD_REVERSE_HOLD_TIME 秒 → 触发反向激活
func _process(delta: float) -> void:
	for box_id: String in _card_hold_state:
		var st: Dictionary = _card_hold_state[box_id]
		if not bool(st.get("holding", false)):
			continue
		st["timer"] = float(st["timer"]) + delta
		if float(st["timer"]) >= CARD_REVERSE_HOLD_TIME:
			st["holding"] = false
			_set_card_reversed(box_id, true)

## 长按开始时：记录按下位置，若发生位移则取消长按（视为点击）
func _reverse_hold_press(box_id: String) -> void:
	pass

## 【rAS】设置卡片反向状态（true=逆位激活，卡片翻转180°显示）
func _set_card_reversed(box_id: String, reversed: bool) -> void:
	var was: bool = _card_reversed_state.get(box_id, false)
	_card_reversed_state[box_id] = reversed
	if not _card_map.has(box_id):
		return
	var refs: Dictionary = _card_map[box_id]
	var card: Control = refs.card as Control
	var front: TextureRect = refs.front as TextureRect
	var back: TextureRect = refs.back as TextureRect
	var outline: TextureRect = refs.outline as TextureRect
	if reversed:
		# 反向：显示背面纹理并翻转180°（逆位）
		front.visible = false
		back.visible = true
		outline.visible = true
		card.rotation_degrees = 180.0
		# 反向视为已勾选（进入 rAS 模式）
		(refs.btn as Button).set_pressed_no_signal(true)
		set_toggle_checked(box_id, true)
		_sync_card_states(false)
		if AudioManager:
			AudioManager.play("card_tone_allspin_reverse")
	else:
		front.visible = true
		back.visible = false
		card.rotation_degrees = 0.0
		outline.visible = false
		(refs.btn as Button).set_pressed_no_signal(false)
		set_toggle_checked(box_id, false)
		_sync_card_states(false)
		if was and AudioManager:
			AudioManager.play("card_slide_1")

## 某卡片当前是否处于反向（逆位）状态
func is_card_reversed(box_id: String) -> bool:
	return _card_reversed_state.get(box_id, false)

## 卡片视觉同步：按对应 ToggleBox 状态翻转/置灰。
## 仅当卡片状态相对上一次实际变化时才播放翻转动画（否则所有已选中卡片会在
## 任意 toggle 变化时都翻一次）；未变化的卡片只做即时状态修正。
## 【rAS】反向（逆位）卡片视为已勾选，且保持 180° 显示，不被普通同步翻转。
func _sync_card_states(animate: bool = true) -> void:
	for box_id: String in _card_map:
		var refs: Dictionary = _card_map[box_id]
		# 反向（逆位）状态优先：卡片保持180°翻转，视为选中
		if _card_reversed_state.get(box_id, false):
			var front: TextureRect = refs.front as TextureRect
			var back: TextureRect = refs.back as TextureRect
			front.visible = false
			back.visible = true
			(refs.card as Control).rotation_degrees = 180.0
			(refs.outline as TextureRect).visible = true
			(refs.card as Control).modulate = Color.WHITE
			(refs.btn as Button).set_pressed_no_signal(true)
			_card_visual_state[box_id] = true
			continue
		var checked: bool = false
		for tb in toggle_boxes:
			if tb and tb.box_id == box_id and tb.is_checked_state():
				checked = true
				break
		var was: bool = _card_visual_state.get(box_id, false)
		_card_visual_state[box_id] = checked
		if was == checked:
			_card_set_selected(box_id, refs, checked, false)
		else:
			# 状态真正变化时才播放音效（同 TETR.IO：选中=card_select+card_tone，取消=card_slide）
			if animate and AudioManager:
				if checked:
					AudioManager.play("card_select")
					var tone: String = _card_tone_name(box_id)
					if not tone.is_empty():
						AudioManager.play(tone)
				else:
					AudioManager.play("card_slide_1")
			_card_set_selected(box_id, refs, checked, animate)
		(refs.card as Control).modulate = Color.WHITE if checked else Color(0.45, 0.45, 0.45, 0.7)


# ========== 信号连接 ==========

func _connect_signals():
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)


## 自动发现场景中的ToggleBox节点（当toggle_boxes未在编辑器中配置时）
## 递归遍历本节点的父级（CanvasLayer）下所有子节点，按树顺序收集
func _discover_toggle_boxes() -> void:
	if not toggle_boxes.is_empty():
		return
	var found: Array[ToggleBox] = []
	var root_node: Node = get_parent()
	if root_node:
		_find_toggle_boxes_recursive(root_node, found)
	if not found.is_empty():
		toggle_boxes = found
		# 已注释（调试噪音）：print("自动发现 ToggleBox 节点: ", toggle_boxes.size())

func _find_toggle_boxes_recursive(node: Node, found: Array[ToggleBox]) -> void:
	if node is ToggleBox:
		found.append(node)
	for child in node.get_children():
		_find_toggle_boxes_recursive(child, found)


## 连接所有 ToggleBox 的状态切换信号
func _connect_toggle_boxes():
	for tb in toggle_boxes:
		if tb and not tb.toggled.is_connected(_on_toggle_box_toggled):
			tb.toggled.connect(_on_toggle_box_toggled)


# ========== Buff/Debuff 计算核心 ==========

## 计算所有已勾选框的 APM 总倍率累加
## 只关注 total_apm_buff_mult 键（累加 stacking: 1.0 + (m₁-1.0) + (m₂-1.0) + ...）
## 其他键由 get_buffed_tower_data 直接放入 extra_data_dict
func _calculate_accumulated_multipliers() -> Dictionary:
	var multipliers: Dictionary = {}
	for tb in toggle_boxes:
		if tb and tb.is_checked_state() and _buff_config_map.has(tb.box_id):
			var config: Dictionary = _buff_config_map[tb.box_id]
			if config.has("total_apm_buff_mult"):
				var mult: float = config["total_apm_buff_mult"] as float
				if multipliers.has("total_apm_buff_mult"):
					multipliers["total_apm_buff_mult"] = multipliers["total_apm_buff_mult"] + (mult - 1.0)
				else:
					multipliers["total_apm_buff_mult"] = mult
	return multipliers


## 获取应用了所有已勾选框倍率（累加叠加）后的完整数据字典
## total_apm_buff_mult 倍率应用于 total_apm
## 不在 tower_init_data 中的键值对整个添加入 extra_data_dict（排除 total_apm_buff_mult）
func get_buffed_tower_data() -> Dictionary:
	var result: Dictionary = tower_init_data.duplicate(true)
	var multipliers: Dictionary = _calculate_accumulated_multipliers()
	
	# Step 1: 将 total_apm_buff_mult 倍率应用于 total_apm
	if multipliers.has("total_apm_buff_mult"):
		result["total_apm"] = result["total_apm"] * multipliers["total_apm_buff_mult"]
	
	# Step 2: 应用各 buff/debuff 配置键
	#   - 键在 tower_init_data 中 → 覆盖初始值（如 StrengthA 的 send_mult_attack=2.0）
	#   - 键不在 tower_init_data 中 → 整个值键对加入 extra_data_dict
	for tb in toggle_boxes:
		if tb and tb.is_checked_state() and _buff_config_map.has(tb.box_id):
			var config: Dictionary = _buff_config_map[tb.box_id]
			for key: String in config:
				if key == "total_apm_buff_mult":
					continue  # 倍率键，不存入数据
				if result.has(key):
					result[key] = config[key]
				else:
					result["extra_data_dict"][key] = config[key]
	
	# 启用 Bot 时，注入 Bot PPS（来自 BotPpsSpin 输入框，near 启用bot 按钮）
	for tb in toggle_boxes:
		if tb and tb.box_id == "BotPlay" and tb.is_checked_state():
			var spin = _find_bot_pps_spin()
			if spin:
				result["extra_data_dict"]["bot_target_pps"] = spin.value
				result["extra_data_dict"]["BotMode"] = true
	
	# 【rAS】逆位全旋：卡片反向（长按3秒）激活 → 注入 rAS 标志，并强制关闭普通 allspin
	for mod: Dictionary in CARD_MODS:
		var rbox_id: String = str(mod["box_id"])
		if bool(mod.get("reversed", false)) and _card_reversed_state.get(rbox_id, false):
			result["extra_data_dict"]["rAS"] = 1
			result["extra_data_dict"]["allspin"] = 0
	
	return result

## 查找 Bot PPS SpinBox（跨场景层级，用唯一名递归搜索，避免相对路径错位）
func _find_bot_pps_spin() -> Node:
	var root_node: Node = get_tree().root
	return _find_node_by_name(root_node, "BotPpsSpin")

func _find_node_by_name(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var found: Node = _find_node_by_name(child, target)
		if found != null:
			return found
	return null


## 生成指定 box 的显示文本（仅描述，不含倍率数据——倍率数据由 _update_summary_label 合并显示）
func _get_enhanced_label_text(box_id: String) -> String:
	var text: String = _display_text_map.get(box_id, "")
	if text.is_empty():
		return "[%s]" % box_id
	return text


## 刷新所有已勾选框 Label 的显示文本
func _update_all_labels() -> void:
	for box_id: String in _label_by_id:
		var label: Label = _label_by_id[box_id] as Label
		if label:
			label.text = _get_enhanced_label_text(box_id)


## 更新合并效果汇总 Label（显示所有唯一 key 的累加倍率，去重合并）
## 多个选框影响同一 key 时只显示一行，避免重复
func _update_summary_label() -> void:
	var accumulated: Dictionary = _calculate_accumulated_multipliers()
	
	# 没有任何选框被勾选 → 隐藏汇总
	if accumulated.is_empty():
		if _summary_label:
			_summary_label.hide()
		return
	
	var parts: PackedStringArray = []
	for key: String in accumulated:
		var mult: float = accumulated[key]
		if key == "total_apm_buff_mult":
			# 显示 APM 总倍率：显示原始 total_apm 和 buffed 后的值
			var base_apm: float = tower_init_data.get("total_apm", 70.0)
			var buffed_apm: float = base_apm * mult
			var percent_change: float = (mult - 1.0) * 100.0
			var sign_str: String = "+" if percent_change >= 0.0 else ""
			parts.append("APM总量: %.1f → %.1f (%s%.0f%%)" % [base_apm, buffed_apm, sign_str, percent_change])
	
	# 仅当有重复 key 时才显示"合并效果"标题；只有一个 key 时直接显示
	var has_duplicate: bool = false
	if parts.size() > 1:
		# 检查是否有一个 key 被多个选框影响（即 accumulated 中有不同的来源）
		# 简单判断：如果 parts 数量 < 已选框数量，说明有重复
		var checked_count: int = 0
		for tb in toggle_boxes:
			if tb and tb.is_checked_state():
				checked_count += 1
		if checked_count > accumulated.size():
			has_duplicate = true
	
	if not _summary_label:
		_summary_label = Label.new()
		_summary_label.add_theme_font_size_override("font_size", max(12, int(18 * 1.0)))
		_summary_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1))
		buff_list.add_child(_summary_label)
	
	if has_duplicate:
		_summary_label.text = "━━ 合并效果 ━━\n" + "\n".join(parts)
	else:
		_summary_label.text = "\n".join(parts)
	_summary_label.show()


# ========== 挑战组合 ==========

## 根据组名获取对应的box_id列表（精确匹配优先，失败时尝试大小写不敏感匹配）
## 兼容JSON中组名大小写差异（如 "Nohold" vs "NoHold"）
func _get_group_box_ids(group_name: String) -> Array:
	if _buff_group_map.has(group_name):
		return _buff_group_map[group_name]
	var lower_name: String = group_name.to_lower()
	for key: String in _buff_group_map:
		if key.to_lower() == lower_name:
			return _buff_group_map[key]
	return []

## 解析颜色字段（支持 [r,g,b]/[r,g,b,a] 数组或 "#rrggbb" 字符串），失败返回 null
func _parse_color(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 3:
			var a: float = 1.0
			if arr.size() >= 4:
				a = float(arr[3])
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	elif typeof(value) == TYPE_STRING:
		var s: String = str(value)
		if Color.html_is_valid(s):
			return Color(s)
	return null

## 更新挑战组合显示：当已选框恰好（且仅）等于某组合Group内的全部box时，
## 在buff列表末尾显示 "挑战组合：XXXX"（XXXX为该组合的Info内容）
## Color字段为预留颜色读取字段，未读取到（或格式错误）时使用文本默认颜色
func _update_combination_label() -> void:
	if not buff_list:
		return
	
	# 当前已选框集合
	var selected: Array[String] = get_checked_toggle_ids()
	selected.sort()
	
	var matched_texts: Array[String] = []
	var matched_color: Color = Color.WHITE
	var has_color: bool = false
	
	for comb_name: String in _combination_map:
		var comb: Variant = _combination_map[comb_name]
		if typeof(comb) != TYPE_DICTIONARY or not comb.has("Group"):
			continue
		
		# 汇总该组合Group内所有组对应的box_id
		var expected: Array = []
		var group_valid: bool = true
		for group_name: Variant in comb["Group"]:
			var ids: Array = _get_group_box_ids(str(group_name))
			if ids.is_empty():
				group_valid = false
				push_warning("挑战组合 %s 引用的组不存在: %s" % [comb_name, group_name])
				break
			expected += ids
		if not group_valid:
			continue
		expected.sort()
		
		# 且仅满足：已选框集合与组合期望集合完全一致才显示
		if selected != expected:
			continue
		
		var info_text: String = str(comb.get("Info", ""))
		if info_text.is_empty():
			info_text = comb_name
		matched_texts.append(info_text)
		
		# 预留color读取字段：存在且可解析时使用，否则保持文本默认颜色
		if not has_color and comb.has("Color"):
			var c: Variant = _parse_color(comb["Color"])
			if c != null:
				matched_color = c
				has_color = true
	
	if matched_texts.is_empty():
		if _combination_label:
			_combination_label.hide()
		return
	
	if not _combination_label:
		_combination_label = Label.new()
		_combination_label.add_theme_font_size_override("font_size", max(12, int(20 * 1.0)))
		buff_list.add_child(_combination_label)
	
	_combination_label.text = "挑战组合：" + "\n".join(matched_texts)
	if has_color:
		_combination_label.add_theme_color_override("font_color", matched_color)
	else:
		_combination_label.remove_theme_color_override("font_color")
	_combination_label.show()
	# 确保显示在buff列表最后（位于汇总标签之后）
	buff_list.move_child(_combination_label, buff_list.get_child_count() - 1)


# ========== ToggleBox 回调 ==========

## 任意 ToggleBox 切换时触发
func _on_toggle_box_toggled(box_id: String, is_checked: bool, _value: Variant) -> void:
	
	if is_checked:
		_add_label_for_box(box_id)
		# 互斥逻辑：如果此选框属于某个互斥组，取消同组其他选框
		_uncheck_mutually_exclusive(box_id)
	else:
		_remove_label_for_box(box_id)
	
	# 添加/移除后重新排序，确保按 toggle_boxes 顺序从上到下排列
	_refresh_label_order()
	
	# 刷新所有标签显示（因为累积倍率可能变化）
	_update_all_labels()
	# 更新合并汇总（去重显示）
	_update_summary_label()
	# 更新挑战组合显示
	_update_combination_label()
	# 同步卡片高亮
	_sync_card_states()


## 互斥逻辑：取消同组内其他选框的选中状态
func _uncheck_mutually_exclusive(checked_box_id: String) -> void:
	for _group_name: String in _mutually_exclusive_groups:
		var group: Array = _mutually_exclusive_groups[_group_name]
		if not checked_box_id in group:
			continue
		# 此选框属于该组，取消同组内其他选框
		for other_id: String in group:
			if other_id == checked_box_id:
				continue
			# 查找对应的 ToggleBox 节点并取消选中
			for tb in toggle_boxes:
				if tb and tb.box_id == other_id and tb.is_checked_state():
					tb.set_checked(false)
					_remove_label_for_box(other_id)

## 为指定 box 添加 Label（如果尚未添加）
func _add_label_for_box(box_id: String) -> void:
	if not buff_list:
		return
	
	# 已存在则不重复添加
	if _label_by_id.has(box_id):
		return
	
	var label := Label.new()
	label.text = _get_enhanced_label_text(box_id)
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))   # 统一绿色调
	
	label.add_theme_font_size_override("font_size", max(12, int(20 * 1.0)))
	
	_label_by_id[box_id] = label
	buff_list.add_child(label)


## 移除指定 box 的 Label
func _remove_label_for_box(box_id: String) -> void:
	if not buff_list:
		return
	
	var label: Label = _label_by_id.get(box_id)
	if not label:
		return
	
	buff_list.remove_child(label)
	label.queue_free()
	_label_by_id.erase(box_id)


## 将所有 Label 按 toggle_boxes 顺序重新排列（从上到下 = box_id 顺序）
func _refresh_label_order() -> void:
	if not buff_list:
		return
	
	# 按照 toggle_boxes 的顺序，收集所有已勾选的 box_id
	var checked_order: Array[String] = []
	for tb in toggle_boxes:
		if tb and _label_by_id.has(tb.box_id):
			checked_order.append(tb.box_id)
	
	# 将 buff_list 的子节点按 checked_order 重排
	for i in checked_order.size():
		var label: Label = _label_by_id[checked_order[i]]
		# 如果该 Label 不在正确的位置，则移到最后再插入到正确位置
		if buff_list.get_child(i) != label:
			buff_list.move_child(label, i)


# ========== 公开方法 ==========

## 获取所有 ToggleBox 的状态列表（供外部批量读取）
func get_all_toggle_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tb in toggle_boxes:
		if tb:
			result.append(tb.get_state())
	return result


## 根据 id 获取指定 ToggleBox 的状态
func get_toggle_state_by_id(box_id: String) -> Dictionary:
	for tb in toggle_boxes:
		if tb and tb.box_id == box_id:
			return tb.get_state()
	return {}


## 根据 id 设置指定 ToggleBox 的选中状态
func set_toggle_checked(box_id: String, checked: bool) -> bool:
	for tb in toggle_boxes:
		if tb and tb.box_id == box_id:
			tb.set_checked(checked)
			return true
	return false


## 动态添加 ToggleBox
func add_toggle_box(tb: ToggleBox) -> void:
	if tb and not tb in toggle_boxes:
		toggle_boxes.append(tb)
		if not tb.toggled.is_connected(_on_toggle_box_toggled):
			tb.toggled.connect(_on_toggle_box_toggled)


## 获取所有 ToggleBox 中处于选中（✓）状态的列表
func get_checked_toggle_ids() -> Array[String]:
	var ids: Array[String] = []
	for tb in toggle_boxes:
		if tb and tb.is_checked_state():
			ids.append(tb.box_id)
	return ids


# ========== 按钮回调 ==========

func _on_back_button_pressed():
	#print("返回主菜单")
	if AudioManager:
		AudioManager.play("menuback")
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_start_button_pressed():
	#print("开始游戏 - 进入俄罗斯方块")
	if AudioManager:
		AudioManager.play("menuconfirm")
	
	# 将应用了所有 buff/debuff 倍率的数据存入 GlobalData
	var buffed_data: Dictionary = get_buffed_tower_data()
	GlobalData.tower_init_data = buffed_data
	#print("TowerController 数据（含 buff/debuff 倍率累加）已存入 GlobalData: ", GlobalData.tower_init_data)
	
	GlobalData.reset_stats()
	get_tree().change_scene_to_file(game_scene_path)
