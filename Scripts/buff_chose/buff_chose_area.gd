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

# 已勾选框对应的 Label 字典（box_id -> Label）
var _label_by_id: Dictionary = {}

# 合并效果汇总 Label（显示所有唯一 key 的累加倍率，去重合并）
var _summary_label: Label = null

## 互斥选框组配置：同一组内的选框互斥，选中一个则其他自动取消
## 组名 -> [box_id1, box_id2, ...]
var _mutually_exclusive_groups: Dictionary = {
	"Pressure": ["Pressure1", "Pressure2", "Pressure3"],
	"Suddenly_Death": ["SuddenlyDeath_1","SuddenlyDeath_2","SuddenlyDeath_3","SuddenlyDeath_4","SuddenlyDeath_5","SuddenlyDeath_6","SuddenlyDeath_7","SuddenlyDeath_8","SuddenlyDeath_9","SuddenlyDeath_10"],
}

# box_id 到显示文本的映射
var _display_text_map: Dictionary = {
	"Pressure1": "高压I：apm总量增加20%",
	"Pressure2": "高压II：apm总量增加30%",
	"Pressure3": "高压III：apm总量增加50%",
	"StrengthA": "力量（受击）：受到双倍攻击",
	"StrengthB": "力量（攻击）：双倍抵消受到的攻击",
	"GravityA": "重力：方块出现后将会立刻落地",
	"SuddenlyDeath_1": "突然死亡I：垃圾行上涨速度略微增加",
	"SuddenlyDeath_2": "突然死亡II：垃圾行上涨速度增加，并且上涨上限略微增加",
	"SuddenlyDeath_3": "突然死亡III：垃圾行上涨速度大幅度增加，并且上涨上限增加",
	"SuddenlyDeath_4": "突然死亡IV：垃圾行会一次性全部上涨",
	"SuddenlyDeath_5": "突然死亡V：垃圾行会一次性全部上涨，并且上涨上限增加",
	"SuddenlyDeath_6": "突然死亡VI：垃圾行会一次性全部上涨，并且上涨上限增加，缓冲时间大幅度缩短",
	"SuddenlyDeath_7": "突然死亡VII：垃圾行会一次性全部上涨，并且上涨上限大幅度增加，几乎没有缓冲时间",
	"SuddenlyDeath_8": "突然死亡VIII：垃圾行在缓冲结束后就会一次性全部上涨",
	"SuddenlyDeath_9": "突然死亡IV：垃圾行在缓冲结束后就会一次性全部上涨，缓冲时间大幅度缩短",
	"SuddenlyDeath_10": "突然死亡X：垃圾行在缓冲结束后就会一次性全部上涨，缓冲时间极大幅度缩短",
	"Invisible_1":"隐形I：开启隐形",
	"Allspin_1":"全旋I：启用Allspin，当消行类型与行数都与上次完全一致时立刻上涨一行垃圾行",
}


# ========== Buff/Debuff 倍率配置 ==========

## TowerController 初始数据字典（可在编辑器中修改，点击 START 时自动存入 GlobalData）
@export var tower_init_data: Dictionary = {
	# ---- APM / Stage ----
	total_apm = 70.0,
	stage_percent_apm = [0.01,0.02,0.05,0.1,0.25,0.4,0.55,0.7,0.8,0.9,1.0],
	extra_percent_apm = 0.0,
	
	# ---- Garbage ----
	stage_garbage_time = [10,8,7,7,6,6,5,5,4,4,3],
	garbage_collect_percent_array = [0.4,0.3,0.2,0.1,0.1,0.2,0.2,0.3,0.3,0.4],
	garbage_divide_percent_array = [0.8,0.6,0.4,0.2,0.2,0.1,0.1,0,0.1,0.2,0.3],
	pressure_mult_array = [1,1,1,1,1,1,1,1,1,1,1.25,1.5,2,2.5,3,4,5,7,10],
	send_mult_attack = 1.0,
	
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
var _buff_config_map: Dictionary = {
	"Pressure1": {"total_apm_buff_mult": 1.2},
	"Pressure2": {"total_apm_buff_mult": 1.3},
	"Pressure3": {"total_apm_buff_mult": 1.5},
	"StrengthA": {"send_mult_attack": 2.0},
	"StrengthB": {"mult_defend": 2.0},
	"GravityA": {"gravity_drop_time": 0},
	"SuddenlyDeath_1": {"garbage_rise_time_delay": 0.4},
	"SuddenlyDeath_2": {"garbage_rise_time_delay": 0.3,"garbage_cap":5},
	"SuddenlyDeath_3": {"garbage_rise_time_delay": 0.1,"garbage_cap":8},
	"SuddenlyDeath_4": {"suddenly_death_mode": true},
	"SuddenlyDeath_5": {"suddenly_death_mode": true,"garbage_cap":8},
	"SuddenlyDeath_6": {"suddenly_death_mode": true,"garbage_cap":8,"buffer_duration":1},
	"SuddenlyDeath_7": {"suddenly_death_mode": true,"garbage_cap":12,"buffer_duration":0.1},
	"SuddenlyDeath_8": {"suddenly_death_mode": true,"drop_limit_cancel":true},
	"SuddenlyDeath_9": {"suddenly_death_mode": true,"drop_limit_cancel":true,"buffer_duration":1},
	"SuddenlyDeath_10": {"suddenly_death_mode": true,"drop_limit_cancel":true,"buffer_duration":0.5},
	"Invisible_1": {"tetris_invisible": 1},
	"Allspin_1": {"tetris_allspin": 1},
}

# ToggleBox 节点引用（可在编辑器中拖入或由代码动态添加）
@export var toggle_boxes: Array[ToggleBox] = []


# ========== 场景路径 ==========

@export var main_menu_scene_path: String = "res://Tscns/main_menu.tscn"
@export var game_scene_path: String = "res://Tscns/tetris.tscn"


# ========== UI 缩放相关 ==========

# Panel 引用（CanvasLayer 下全屏面板，用于居中缩放）
var _panel: Panel = null


# ========== 生命周期 ==========

func _ready():
	_panel = get_node_or_null("../Panel") as Panel
	_connect_signals()
	_connect_toggle_boxes()
	
	# 应用 UI 缩放（UIScaler 已移除，固定 scale=1.0）
	_apply_ui_scale()
	
	# 更新已有标签显示（如 default_checked 为 true 的选框）
	_update_all_labels()
	_update_summary_label()
	
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


# ========== 信号连接 ==========

func _connect_signals():
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)


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
	
	# Step 2: 处理不在 tower_init_data 中的键 → 直接存入 extra_data_dict
	for tb in toggle_boxes:
		if tb and tb.is_checked_state() and _buff_config_map.has(tb.box_id):
			var config: Dictionary = _buff_config_map[tb.box_id]
			for key: String in config:
				if key == "total_apm_buff_mult":
					continue  # 倍率键，不存入数据
				if not result.has(key):
					# 键不在 tower_init_data 中 → 整个值键对加入 extra_data_dict
					result["extra_data_dict"][key] = config[key]
	
	return result


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
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_start_button_pressed():
	#print("开始游戏 - 进入俄罗斯方块")
	
	# 将应用了所有 buff/debuff 倍率的数据存入 GlobalData
	var buffed_data: Dictionary = get_buffed_tower_data()
	GlobalData.tower_init_data = buffed_data
	#print("TowerController 数据（含 buff/debuff 倍率累加）已存入 GlobalData: ", GlobalData.tower_init_data)
	
	GlobalData.reset_stats()
	get_tree().change_scene_to_file(game_scene_path)
