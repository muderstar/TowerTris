extends Node
class_name TetrisClearLine

## 俄罗斯方块消行控制器
## 负责检测和消除完整行，并显示消行动画/文本

# 节点引用
@export var board_drawer: TetrisBoardDrawer  # 版面绘制器节点
@export var tetris_controller: TetrisController  # 方块控制器引用
@export var garbage_line_controller: TetrisGarbageLineController
@export var tower_controller: TowerController

# 消行配置
@export var clear_animation_duration: float = 0.3  # 消行动画持续时间（秒）
@export var clear_text_display_duration: float = 2.0  # 消行文本显示持续时间（秒）

# 消行文本配置
@export var clear_text_color: Color = Color.WHITE  # 消行文本颜色
@export var clear_text_outline_color: Color = Color.BLACK  # 消行文本描边颜色
@export var clear_text_offset_y_cells: float = 2  # 消行文本相对于Hold框底部的偏移（格子数）

# Spin类型判定配置
@export var spin_detection_enabled: bool = true  # 是否启用Spin检测
@export var spin_text_color: Color = Color.YELLOW  # Spin文本颜色
@export var spin_text_outline_color: Color = Color.BLACK  # Spin文本描边颜色
@export var spin_text_offset_y_cells: float = 1  # Spin文本相对于消行文本的偏移（格子数，负值向上）

# 连击配置
@export var combo_text_color: Color = Color.CYAN  # 连击文本颜色
@export var combo_text_outline_color: Color = Color.BLACK  # 连击文本描边颜色
@export var combo_text_offset_y_cells: float = 1  # 连击文本相对于消行文本的偏移（格子数，正值向下）

# BTB配置
@export var btb_text_color: Color = Color.MAGENTA  # BTB文本颜色
@export var btb_text_outline_color: Color = Color.BLACK  # BTB文本描边颜色
@export var btb_text_offset_y_cells: float = 4.5  # BTB文本相对于Hold框底部的偏移（格子数，正值向下）

# PC（Perfect Clear）配置
@export var pc_text_color: Color = Color.GOLD  # PC文本颜色
@export var pc_text_outline_color: Color = Color.BLACK  # PC文本描边颜色
@export var pc_text_offset_y_cells: float = 3.5  # PC文本相对于Hold框底部的偏移（格子数，正值向下）
@export var pc_damage: int = 10  # PC附加伤害值

# 伤害显示配置
@export var damage_text_color: Color = Color.ORANGE  # 伤害文本颜色
@export var damage_text_outline_color: Color = Color.BLACK  # 伤害文本描边颜色
@export var damage_text_offset_y_cells: float = 5.5  # 伤害文本相对于Hold框底部的偏移（格子数，正值向下）
@export var damage_display_duration: float = 1.5  # 伤害显示持续时间（秒）

# 消行文本映射
var clear_texts: Dictionary = {
	1: "SINGLE",
	2: "DOUBLE",
	3: "TRIPLE",
	4: "QUAD"
}

# 基础伤害表（按消行数）
var base_damage_table: Dictionary = {
	0: 0,
	1: 0,
	2: 1,
	3: 2,
	4: 4
}

# Spin伤害表（优先于基础伤害表）
var spin_damage_table: Dictionary = {
	"T-Spin": {
		1: 2,
		2: 4,
		3: 6
	},
	"Mini T-Spin": {
		1: 1
	}
}

# 连击表
var combo_damage_list: Array = [
	0,  #无连击
	0,  # 1连击
	0,  # 2连击
	1,  # 3连击
	1,  # 4连击
	1,  # 5连击
	2,  # 6连击
	2,  # 7连击
	3,  # 8连击
	3,  # 9连击
	4,  # 10连击
	4   # 11连击及以上
]

# Spin伤害加成
var spin_damage_multiplier: Dictionary = {
	"t_spin": 2,
	"mini_t_spin": 1,
	"other_spin": 1
}

# 状态变量
var lines_to_clear: Array = []
var is_animating: bool = false
var clear_text_timer: Timer
var current_clear_text: String = ""
var current_spin_text: String = ""
var current_combo_text: String = ""
var current_btb_text: String = ""
var current_damage_text: String = ""
var clear_text_position: Vector2 = Vector2.ZERO
var spin_text_position: Vector2 = Vector2.ZERO
var combo_text_position: Vector2 = Vector2.ZERO
var btb_text_position: Vector2 = Vector2.ZERO
var damage_text_position: Vector2 = Vector2.ZERO

# 连击和BTB状态
var combo_count: int = 0
var btb_count: int = 0
var is_btb_active: bool = false

# PC状态
var current_pc_text: String = ""
var pc_text_position: Vector2 = Vector2.ZERO

# 伤害累积系统
var accumulated_damage: int = 0          # 累积的伤害值
var damage_timer: Timer                  # 伤害计时器
var damage_pending: bool = false         # 是否有待显示的伤害

# 旋转记录
var last_rotation_occurred: bool = false
var last_rotation_piece_type: String = ""
var last_rotation_piece_shape: Array = []
var last_rotation_position: Vector2i = Vector2i.ZERO

# Spin颜色系统
var display_spin_color: Color = Color.YELLOW
var pending_spin_color: Color = Color.WHITE
var spin_color_ready: bool = false

# 当前消行的伤害值
var current_damage: int = 0
var has_cleared_lines: bool = false

func _ready():
	if not board_drawer:
		board_drawer = get_node_or_null("../TetrisBoardDrawer")
		if not board_drawer:
			push_error("TetrisClearLine: 未找到TetrisBoardDrawer节点！")
			return
	
	if not tetris_controller:
		tetris_controller = get_node_or_null("../TetrisController")
		if not tetris_controller:
			push_error("TetrisClearLine: 未找到TetrisController节点！")
	
	# 自动查找tower_controller（如果未设置）
	if not tower_controller:
		tower_controller = get_node_or_null("../../TowerController")
		if not tetris_controller:
			push_error("TowerController: 未找到TowerController节点！")
	
	clear_text_timer = Timer.new()
	clear_text_timer.wait_time = clear_text_display_duration
	clear_text_timer.one_shot = true
	clear_text_timer.timeout.connect(_on_clear_text_timeout)
	add_child(clear_text_timer)
	
	# 创建伤害计时器
	damage_timer = Timer.new()
	damage_timer.wait_time = damage_display_duration
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

## 记录旋转事件
func record_rotation(piece_type: String, shape: Array, position: Vector2i, piece_color: Color = Color.WHITE):
	last_rotation_occurred = true
	last_rotation_piece_type = piece_type
	last_rotation_piece_shape = shape
	last_rotation_position = position
	
	if piece_color != Color.WHITE:
		pending_spin_color = piece_color
		spin_color_ready = true

## 重置旋转记录
func reset_rotation_record():
	last_rotation_occurred = false
	last_rotation_piece_type = ""
	last_rotation_piece_shape = []
	last_rotation_position = Vector2i.ZERO

## 清除Spin颜色
func clear_spin_color():
	pending_spin_color = Color.WHITE
	spin_color_ready = false
	display_spin_color = Color.YELLOW

## 清除所有文本（BTB除外）
func clear_texts_except_btb():
	current_clear_text = ""
	current_spin_text = ""
	current_combo_text = ""
	clear_text_timer.stop()
	board_drawer.queue_redraw()

## 伤害计时器超时
func _on_damage_timer_timeout():
	# 计时归零，清除伤害显示
	tower_controller.try_give_kill_reward(accumulated_damage)
	current_damage_text = ""
	accumulated_damage = 0
	damage_pending = false
	board_drawer.queue_redraw()

## 添加伤害到累积显示
func _add_damage_to_display(damage: int):
	if damage <= 0:
		return
	
	# 累加伤害
	accumulated_damage += damage
	damage_pending = true
	
	# 更新显示文本
	current_damage_text = "%d Attack" % accumulated_damage
	
	# 计算显示位置（在BTB下方）
	var hold_pos = board_drawer._get_hold_position()
	var hold_height = board_drawer.hold_display_height * board_drawer.cell_size
	var garbage_slot_left_x = hold_pos.x + board_drawer.hold_display_width * board_drawer.cell_size
	var bottom_y = hold_pos.y + hold_height
	var offset_y = damage_text_offset_y_cells * board_drawer.cell_size
	damage_text_position = Vector2(garbage_slot_left_x, bottom_y + offset_y)
	
	# 重置计时器（如果正在运行则停止并重新开始）
	if damage_timer.is_stopped():
		damage_timer.start()
	else:
		damage_timer.stop()
		damage_timer.start()
	
	board_drawer.queue_redraw()

## 检查并消除完整的行
func check_and_clear_lines() -> int:
	if is_animating:
		return 0
	
	lines_to_clear = _find_complete_lines()
	
	if lines_to_clear.is_empty():
		combo_count = 0
		reset_rotation_record()
		current_damage = 0
		has_cleared_lines = false
		clear_texts_except_btb()
		return 0
	
	has_cleared_lines = true
	var clear_count = lines_to_clear.size()
	var spin_type = _detect_spin_type()
	
	_clear_lines(lines_to_clear)
	
	var is_spin = not spin_type.is_empty()
	# 单独判断is_quad
	var is_quad = false
	if clear_count >= 4:
		is_quad = true
	# 判断是否触发BTB
	var is_spin_or_quad = false
	if is_quad:
		is_spin_or_quad = true
	if is_spin:
		is_spin_or_quad = true
	
	var damage = _calculate_damage(clear_count, spin_type)
	
	# PC判定：消行后场上没有任何方块
	var is_perfect_clear = _check_perfect_clear()
	if is_perfect_clear:
		damage += pc_damage  # PC额外伤害叠加
		_show_pc_text()
	else:
		current_pc_text = ""
	
	current_damage = damage
	tower_controller.attack_increase_tower(damage)
	
	_update_btb(is_spin_or_quad)
	
	# 添加到伤害累积显示
	_add_damage_to_display(damage)
	
	if is_spin and spin_color_ready:
		display_spin_color = pending_spin_color
	else:
		display_spin_color = Color.YELLOW
	
	_show_clear_and_spin_text(clear_count, spin_type, damage)
	
	reset_rotation_record()
	combo_count += 1
	
	return clear_count

## 更新BTB状态
func _update_btb(is_spin_or_quad: bool):
	if is_spin_or_quad:
		if is_btb_active:
			# 第二次及之后连续四消/spin → BTB计数递增
			btb_count += 1
		else:
			# 第一次四消/spin → 开始计数（btb_count=1），但不显示BTB文本
			is_btb_active = true
			btb_count = 1
		_update_btb_text()
	else:
		btb_count = 0
		is_btb_active = false
		current_btb_text = ""

## 更新BTB文本
func _update_btb_text():
	var btb_text = _get_btb_text()
	if not btb_text.is_empty():
		var hold_pos = board_drawer._get_hold_position()
		var hold_height = board_drawer.hold_display_height * board_drawer.cell_size
		var garbage_slot_left_x = hold_pos.x + board_drawer.hold_display_width * board_drawer.cell_size
		var bottom_y = hold_pos.y + hold_height
		var btb_offset_y = btb_text_offset_y_cells * board_drawer.cell_size
		btb_text_position = Vector2(garbage_slot_left_x, bottom_y + btb_offset_y)
		current_btb_text = btb_text
	else:
		current_btb_text = ""

## 检查是否 Perfect Clear（场上没有任何方块）
func _check_perfect_clear() -> bool:
	for y in range(board_drawer.get_playable_height()):
		for x in range(board_drawer.grid_width):
			if board_drawer.get_cell_color(x, y) != null:
				return false
	return true

## 显示 PC 文本
func _show_pc_text():
	var hold_pos = board_drawer._get_hold_position()
	var hold_height = board_drawer.hold_display_height * board_drawer.cell_size
	var garbage_slot_left_x = hold_pos.x + board_drawer.hold_display_width * board_drawer.cell_size
	var bottom_y = hold_pos.y + hold_height
	var pc_offset_y = pc_text_offset_y_cells * board_drawer.cell_size
	pc_text_position = Vector2(garbage_slot_left_x, bottom_y + pc_offset_y)
	current_pc_text = "PERFECT CLEAR"

## 计算攻击伤害
func _calculate_damage(clear_count: int, spin_type: String) -> int:
	var base_damage = 0
	var spin_damage = 0
	var surge_break = 0
	
	if not spin_type.is_empty():
		var spin_key = _get_spin_key(spin_type)
		
		# Mini Spin：使用基础伤害表，无额外 Spin 伤害加成（消行相当于正常消行）
		if spin_type.find("Mini") != -1:
			spin_damage = base_damage_table.get(clear_count, 0)
		elif spin_damage_table.has(spin_key):
			var spin_damage_by_count = spin_damage_table[spin_key]
			if spin_damage_by_count.has(clear_count):
				spin_damage = spin_damage_by_count[clear_count]
			else:
				spin_damage = base_damage_table.get(clear_count, 0)
		else:
			spin_damage = base_damage_table.get(clear_count, 0)
		
		base_damage = 0
	else:
		base_damage = base_damage_table.get(clear_count, 0)
	
	# BTB 加成（从第二次连续BTB开始）- 适用于 spin 和 quad
	if btb_count > 1:
		if not spin_type.is_empty():
			spin_damage += 1
		elif clear_count >= 4:
			base_damage += 1
	
	if btb_count >= 4 and spin_type.is_empty() and clear_count < 4:
		surge_break = btb_count
	else:
		surge_break = 0
	
	var combo_damage = 0
	if combo_count > 0:
		# 判断消行类型以决定连击加成方式
		var is_mini: bool = spin_type.find("Mini") != -1
		var is_quad: bool = clear_count >= 4
		
		if not is_mini and is_quad:
			# 非mini spin且quad：伤害 +combo_count（x）
			combo_damage = combo_count
		elif is_mini:
			# mini spin：伤害 +floor(ln((x²/2)+1))
			combo_damage = floori(log(combo_count * combo_count / 3.0 + 1.0))
		else:
			# 其他情况：使用连击表
			var index = combo_count
			if index < combo_damage_list.size():
				combo_damage = combo_damage_list[index]
			else:
				var extra = (combo_count - combo_damage_list.size()) / 2.0
				combo_damage = min(5, combo_damage_list[-1] + extra)
	
	return base_damage + spin_damage + combo_damage + surge_break

## 获取Spin的键名
func _get_spin_key(spin_type: String) -> String:
	if spin_type.find("T-Spin") != -1:
		if spin_type.find("Mini") != -1:
			return "Mini T-Spin"
		return "T-Spin"
	return spin_type

## 获取当前消行的伤害值
func get_current_damage() -> int:
	return current_damage

## 获取连击文本
func _get_combo_text() -> String:
	if combo_count > 0:
		return "%d Combo" % combo_count
	return ""

## 获取BTB文本
func _get_btb_text() -> String:
	if is_btb_active and btb_count > 1:
		return "%d x BTB" % (btb_count - 1)
	return ""

# ========== 查找完整行 ==========

func _find_complete_lines() -> Array:
	var complete_lines = []
	
	for y in range(board_drawer.get_playable_height()):
		if garbage_line_controller and garbage_line_controller.is_solid_garbage_row(y):
			continue
		
		var is_complete = true
		for x in range(board_drawer.grid_width):
			if board_drawer.get_cell_color(x, y) == null:
				is_complete = false
				break
		
		if is_complete:
			complete_lines.append(y)
	
	return complete_lines

func _clear_lines(lines: Array):
	if lines.is_empty():
		return
	
	lines.sort()
	
	for y in lines:
		_clear_single_line(y)
	
	board_drawer.queue_redraw()

func _clear_single_line(line_y: int):
	for y in range(line_y, 0, -1):
		for x in range(board_drawer.grid_width):
			var color = board_drawer.get_cell_color(x, y - 1)
			board_drawer.set_cell_color(x, y, color)
	
	for x in range(board_drawer.grid_width):
		board_drawer.set_cell_color(x, 0, null)

# ========== Spin检测系统 ==========

func _detect_spin_type() -> String:
	if not spin_detection_enabled:
		return ""
	
	if not last_rotation_occurred:
		return ""
	
	if not _is_piece_stuck(last_rotation_piece_shape, last_rotation_position):
		# T块专属：正常 T-Spin 判定不成立时，额外检测 T-Spin Mini
		if last_rotation_piece_type == "T":
			return _detect_t_spin_mini()
		return ""
	
	return last_rotation_piece_type + "-Spin"

func _is_piece_stuck(shape: Array, piece_position: Vector2i) -> bool:
	if not tetris_controller:
		return false
	
	var directions = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	
	for dir in directions:
		var new_pos = Vector2i(piece_position.x + dir.x, piece_position.y + dir.y)
		if not tetris_controller._check_collision(new_pos, shape):
			return false
	
	return true


## 检测T块专属的 Mini T-Spin
## 条件：左下和右下都被方块或墙占据，且左上或右上有一个被方块或墙占据
## 返回 "Mini T-Spin" 或 ""
func _detect_t_spin_mini() -> String:
	if last_rotation_piece_type != "T":
		return ""
	
	var pos_x: int = last_rotation_position.x
	var pos_y: int = last_rotation_position.y
	
	# T块 3x3 包围盒的四个角
	var bl_blocked: bool = _is_corner_blocked(pos_x, pos_y + 2)       # 左下
	var br_blocked: bool = _is_corner_blocked(pos_x + 2, pos_y + 2)   # 右下
	var tl_blocked: bool = _is_corner_blocked(pos_x, pos_y)           # 左上
	var tr_blocked: bool = _is_corner_blocked(pos_x + 2, pos_y)       # 右上
	
	# 左下和右下都要被封堵
	if not (bl_blocked and br_blocked):
		return ""
	
	# 左上或右上至少有一个被封堵
	if not (tl_blocked or tr_blocked):
		return ""
	
	return "Mini T-Spin"


## 检查一个角落位置是否被封堵（超出边界 或 该位置有方块）
func _is_corner_blocked(x: int, y: int) -> bool:
	# 左右超出边界 → 被墙壁封堵
	if x < 0 or x >= board_drawer.grid_width:
		return true
	# 底部超出边界 → 被地板封堵
	if y >= board_drawer.get_playable_height():
		return true
	# 上方超出边界 → 不算封堵（可在出块区域之上）
	if y < 0:
		return false
	# 检查该位置是否有方块
	if board_drawer.get_cell_color(x, y) != null:
		return true
	return false


# ========== 显示系统 ==========

func _get_clear_text(count: int) -> String:
	if clear_texts.has(count):
		return clear_texts[count]
	return ""

func _show_clear_and_spin_text(clear_count: int, spin_type: String, _damage: int):
	if clear_count <= 0:
		return
	
	var clear_text = _get_clear_text(clear_count)
	if clear_text.is_empty():
		return
	
	var hold_pos = board_drawer._get_hold_position()
	var hold_height = board_drawer.hold_display_height * board_drawer.cell_size
	var garbage_slot_left_x = hold_pos.x + board_drawer.hold_display_width * board_drawer.cell_size
	var bottom_y = hold_pos.y + hold_height
	
	var offset_y = clear_text_offset_y_cells * board_drawer.cell_size
	clear_text_position = Vector2(garbage_slot_left_x, bottom_y + offset_y)
	current_clear_text = clear_text
	
	if not spin_type.is_empty():
		var spin_offset_y = (clear_text_offset_y_cells - spin_text_offset_y_cells) * board_drawer.cell_size
		spin_text_position = Vector2(garbage_slot_left_x, bottom_y + spin_offset_y)
		current_spin_text = spin_type
	else:
		current_spin_text = ""
	
	var combo_text = _get_combo_text()
	if not combo_text.is_empty():
		var combo_offset_y = (clear_text_offset_y_cells + combo_text_offset_y_cells) * board_drawer.cell_size
		combo_text_position = Vector2(garbage_slot_left_x, bottom_y + combo_offset_y)
		current_combo_text = combo_text
	else:
		current_combo_text = ""
	
	var btb_text = _get_btb_text()
	if not btb_text.is_empty():
		var btb_offset_y = btb_text_offset_y_cells * board_drawer.cell_size
		btb_text_position = Vector2(garbage_slot_left_x, bottom_y + btb_offset_y)
		current_btb_text = btb_text
	else:
		current_btb_text = ""
	
	clear_text_timer.start()
	
	##print("消行: ", clear_count, "，Spin: ", spin_type, "，伤害: ", damage, "，Spin颜色: ", display_spin_color)
	board_drawer.queue_redraw()

func _on_clear_text_timeout():
	current_clear_text = ""
	current_spin_text = ""
	current_combo_text = ""
	current_pc_text = ""
	
	if btb_count == 0:
		current_btb_text = ""
	
	clear_spin_color()
	board_drawer.queue_redraw()

## 获取当前显示的Spin文本颜色
func get_spin_trigger_color() -> Color:
	return display_spin_color

## 检查是否有消行文本正在显示
func is_text_displaying() -> bool:
	return not current_clear_text.is_empty()

## 重置消行状态
func reset():
	lines_to_clear.clear()
	is_animating = false
	current_clear_text = ""
	current_spin_text = ""
	current_combo_text = ""
	current_pc_text = ""
	current_damage_text = ""
	clear_text_timer.stop()
	damage_timer.stop()
	reset_rotation_record()
	combo_count = 0
	btb_count = 0
	is_btb_active = false
	current_damage = 0
	accumulated_damage = 0
	damage_pending = false
	clear_spin_color()
	has_cleared_lines = false

## 获取当前连击数
func get_combo_count() -> int:
	return combo_count

## 获取当前BTB数
func get_btb_count() -> int:
	return btb_count

## 手动设置连击（用于调试）
func set_combo(count: int):
	combo_count = count

## 手动设置BTB（用于调试）
func set_btb(count: int):
	btb_count = count
	is_btb_active = count > 0
