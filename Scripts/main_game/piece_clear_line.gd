extends Node
class_name PieceClearLine

## 俄罗斯方块消行控制器
## 负责检测和消除完整行，并显示消行动画/文本

# 节点引用
@export var board_drawer: MinoBoardDrawer  # 版面绘制器节点
@export var piece_controller: PieceController  # 方块控制器引用
@export var garbage_line_controller: MinoGarbageLineController
@export var tower_controller: TowerController
@export var text_printer: TextPrinter  # 文本打印器节点（用于显示消行/Spin/连击/BTB文本）
@export var effect_manager: Node  # 特效管理器（碎片/圆环/数字弹出）

# 消行配置
@export var clear_animation_duration: float = 0.3  # 消行动画持续时间（秒）
@export var clear_text_display_duration: float = 2.0  # 消行文本显示持续时间（秒）

# 文本打印器配置（非BTB文本：半透明、向左漂移、自然淡出消失）
@export var text_base_opacity: float = 0.8          # 文本显示时的透明度（半透明，0-1）
@export var text_fade_duration: float = 1.0         # 文本淡出时长（秒）
@export var text_drift_cells_per_sec: float = 1.5   # 文本向左漂移速度（格子/秒）
@export var text_gap_cells: float = 1.8             # 文本与版面左边框的间距（格子数）

# 消行/Spin 文本的漂移与淡出倍率（相对默认值的修正：移动略快、淡出更快）
@export var clear_spin_drift_scale: float = 3.0     # 消行/Spin 漂移速度倍率（>1 为更快）
@export var clear_spin_fade_scale: float = 0.2      # 消行/Spin 淡出时长倍率（<1 为淡出更快/更短）
@export var clear_spin_hold_scale: float = 0.15     # 消行/Spin 淡出触发前的保持时间倍率（越小淡出越早、与移动并行）

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

# BTB蓄力（Charge）配置（仿 TETR.IO b2bcharging）
@export var btb_charge_at: int = 4       # 达到该BTB计数后进入"蓄满"状态
@export var btb_charge_color: Color = Color.GOLD   # 蓄满时文本/特效颜色
@export var btb_charge_release_mult: int = 0       # 释放时额外伤害加成（0=不额外加伤害，仅特效）

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
# 双色伤害数字：基础部分浅蓝，加成/电荷部分用蓄力色（默认黄，蓄满后随蓄力档位渐变成蓄力色）
@export var damage_base_text_color: Color = Color(0.35, 0.68, 1.0)  # 基础伤害数字颜色（浅蓝）
@export var damage_bonus_default_color: Color = Color.GOLD  # 加成/电荷数字默认颜色（未蓄满时）

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

# All-Spin 伤害表（独立表，默认 [0,4,6,8]：消1权重保持4不变，消2/消3权重降低，可由 buff 界面调整）
# 下标=消行数 1..3（下标0为0）。allspin_1 规则（allspin==1）下使用。
var allspin_damage_table: Dictionary = {
	1: 4,
	2: 6,
	3: 8
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

# 连击计算方式：0=旧连击表（combo_damage_list），1=新公式（默认）：
#   combo_damage = floor(max(ln(1+1.25*combo), ((is_btb_active?1:0)+attack)*(1+0.25*combo)))
#   其中 attack = 本次消行的 base+spin（不含BTB加成）
var combo_formula: int = 1

# Spin伤害加成
var spin_damage_multiplier: Dictionary = {
	"t_spin": 2,
	"mini_t_spin": 1,
	"other_spin": 1
}

# 状态变量
var lines_to_clear: Array = []
var is_animating: bool = false
var clear_text_position: Vector2 = Vector2.ZERO
var spin_text_position: Vector2 = Vector2.ZERO
var combo_text_position: Vector2 = Vector2.ZERO
var btb_text_position: Vector2 = Vector2.ZERO
var damage_text_position: Vector2 = Vector2.ZERO

# 连击和BTB状态
var combo_count: int = 0
var btb_count: int = 0
var is_btb_active: bool = false
var spin0_btb_enabled: bool = false  # Spin0是否触发BTB（由buff控制）
var allspin: int = 0          # 0=关闭, 1=启用Allspin
var rAS: bool = false         # 逆位全旋（邪术师 The Warlock）：Void/更严惩罚/20行/B2B强化

# ---- bot 评估权重（可由 buff 界面调整，经 bridge 的 S 命令下发到 ColdClear）----
# 维持 BTB 的评估权重（越大 bot 越倾向于维持 back-to-back）
var bot_b2b_clear: int = 200
# 放块后的堆叠最高点权重（bot 评估：height × 最高点，负值=压高）
var bot_height: int = -39
# 四消（Quad）的评估权重（越小 bot 越不倾向做四消）
var bot_clear4: int = 260
# allspin_1 重复惩罚的评估扣分（负值=降低选取值，可 buff 调整）
var bot_allspin_repeat_penalty: int = -120
# 各类型消行/旋转的评估权重（默认=bridge 导出值，可由 buff 传参覆盖，经 bridge 下发）
var bot_eval_mult: int = 100
var bot_attack_efficiency_weight: int = 100
var bot_clear1: int = -163
var bot_clear2: int = -130
var bot_clear3: int = -78
var bot_tspin1: int = 221
var bot_tspin2: int = 410
var bot_tspin3: int = 202
var bot_mini_tspin1: int = -158
var bot_mini_tspin2: int = -393
var bot_allspin1: int = 221
var bot_allspin2: int = 410
var bot_allspin3: int = 202
var bot_allspin3plus: int = 202
var bot_perfect_clear: int = 199
var bot_combo_garbage: int = 170
var bot_wasted_t: int = -102
var bot_move_time: int = -3
# bot 并行搜索线程数（buff 可调；0 = 由 bridge 自动决定）
var bot_threads: int = 0
var no_spin: bool = false            # Talentless：为true时跳过整个Spin判定
# 记录 buff 显式传参的权重键（仅这些键会被 bridge 采用，覆盖 bridge 默认权重）
# 由 tower_controller._extra_data_deal 填入；get_damage_tables 只返回这些键的权重。
var bot_weight_override_keys: Dictionary = {}

# Allspin：记录上次消行类型和行数（用于下一次消行时比对）
var _last_clear_type: String = ""    # 上次消行类型（如"T-Spin"、"Mini T-Spin"、"I-Spin"、""等）
var _last_clear_count: int = 0       # 上次消行行数

# PC状态
var pc_text_position: Vector2 = Vector2.ZERO

# 伤害累积系统
var accumulated_damage: int = 0          # 累积的伤害值（用于击杀奖励结算）
var last_surge_break: int = 0            # 最近一次消行的 surge_break（蓄力断开伤害），供伤害数字染色
var _last_clear_base: int = 0            # 最近一次消行的基础伤害（不含 B2B 加成/surge），供数字拆分为 base+bonus
var _last_clear_bonus: int = 0           # 最近一次消行的加成伤害（B2B boost 或 surge_break）
var _last_clear_ras_b2b_plus_two: bool = false
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
		board_drawer = get_node_or_null("../MinoBoardDrawer")
		if not board_drawer:
			push_error("PieceClearLine: 未找到MinoBoardDrawer节点！")
			return
	
	if not piece_controller:
		piece_controller = get_node_or_null("../PieceController")
		if not piece_controller:
			push_error("PieceClearLine: 未找到PieceController节点！")
	
	# 自动查找tower_controller（如果未设置）
	if not tower_controller:
		tower_controller = get_node_or_null("../../TowerController")
		if not piece_controller:
			push_error("TowerController: 未找到TowerController节点！")
	
	# 自动查找text_printer（如果未设置）
	if not text_printer:
		text_printer = get_node_or_null("../TextPrinter")
	
	# 自动查找effect_manager（如果未设置）
	if not effect_manager:
		effect_manager = get_node_or_null("../EffectManager")
	
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

## 伤害计时器超时
func _on_damage_timer_timeout():
	# 计时归零，清除伤害显示
	tower_controller.try_give_kill_reward(accumulated_damage)
	accumulated_damage = 0
	damage_pending = false
	if text_printer:
		text_printer.remove_text("damage")

## 添加伤害到累积显示
func _add_damage_to_display(damage: int):
	if damage <= 0:
		return
	
	# 累加伤害
	accumulated_damage += damage
	damage_pending = true
	
	# ---- 伤害数字随机出现在版面四周 ----
	# 以版面左上角为基准，在版面外侧区域随机取点（左侧/右侧/上方随机一侧）
	var rng = RandomManager.get_random("MISC")
	var cell: float = board_drawer.cell_size
	var board_w: float = board_drawer.grid_width * cell
	var board_h: float = board_drawer.grid_height * cell
	var anchor_x: float = board_drawer.offset_x
	var anchor_y: float = board_drawer.offset_y
	var side: int = rng.randi_range(0, 2)  # 0=左 1=右 2=上
	var gap: float = text_gap_cells * cell
	var pos: Vector2
	match side:
		0:  # 版面左侧
			pos = Vector2(anchor_x - gap - rng.randf_range(0, cell * 2.0),
				anchor_y + rng.randf_range(board_h * 0.15, board_h * 0.85))
		1:  # 版面右侧
			pos = Vector2(anchor_x + board_w + gap + rng.randf_range(0, cell * 2.0),
				anchor_y + rng.randf_range(board_h * 0.15, board_h * 0.85))
		_:  # 版面上方
			pos = Vector2(anchor_x + rng.randf_range(board_w * 0.15, board_w * 0.85),
				anchor_y - gap - rng.randf_range(0, cell * 2.0))
	damage_text_position = pos
	
	# 防止弹字跑到屏幕外（顶部/底部/边缘），钳制到可视区域内
	# 注意：本脚本 extends Node，不能用 CanvasItem 的 get_viewport_rect()，
	# 需经 get_viewport().get_visible_rect() 获取可视区域
	var vp := get_viewport().get_visible_rect()
	var margin_x: float = cell * 0.5
	var margin_y: float = cell * 0.5
	damage_text_position.x = clampf(damage_text_position.x, vp.position.x + margin_x, vp.end.x - margin_x)
	damage_text_position.y = clampf(damage_text_position.y, vp.position.y + margin_y, vp.end.y - margin_y)
	
	# ---- 颜色：断开蓄力（surge break）时使用 B2B 蓄满颜色 ----
	var display_color: Color = damage_text_color
	if last_surge_break > 0:
		display_color = btb_charge_color
	
	# ---- 数值：只显示本次消行的伤害（base+bonus），不含累积 spike ----
	#   - 四消 + B2B      → 4+1  （base=4, B2B加成=1）
	#   - 双消 + 10 B2B 断开蓄力 → 1+10 （base=1, surge_break=10）
	#   - 普通消行        → N    （无加成时只显示基础值）
	# 双色：基础部分浅蓝，加成/电荷部分用蓄力色（默认黄，蓄满后随蓄力档位渐变）
	var popup: Dictionary = _get_damage_popup_parts(
		_last_clear_base, _last_clear_bonus, _last_clear_ras_b2b_plus_two)
	var show_text: String = popup["text"]
	var segments: Array = popup["segments"]
	
	if text_printer:
		# 【rAS】蓄满（btb>=4）时伤害弹字用 DS Crystal 字体；其余模式用默认字体
		var dmg_font: Font = _get_ras_font() if _last_clear_ras_b2b_plus_two else null
		# 攻击数字：弹出放大，向上/向左飘移，几秒后淡出消失
		text_printer.show_text("damage", show_text, damage_text_position,
			display_color, damage_text_outline_color, cell * 0.9,
			false, 1.0, damage_display_duration, 1.4,
			Vector2(-cell * 0.4, -cell * 0.5),
			HORIZONTAL_ALIGNMENT_RIGHT, true, 0.3, false, segments, dmg_font)
	
	# 攻击冲击波圆环特效（颜色随伤害数字）
	if effect_manager:
		effect_manager.spawn_ring(damage_text_position, display_color, cell * 3.5, 0.45)
	
	# 重置计时器（如果正在运行则停止并重新开始）
	if damage_timer.is_stopped():
		damage_timer.start()
	else:
		damage_timer.stop()
		damage_timer.start()
	
	board_drawer.queue_redraw()

func _get_damage_popup_parts(base_part: int, bonus_part: int, ras_b2b_plus_two: bool) -> Dictionary:
	var total_damage: int = base_part + bonus_part
	if rAS and not ras_b2b_plus_two and last_surge_break == 0:
		return {
			"text": str(total_damage),
			"segments": [[str(total_damage), damage_base_text_color]],
		}
	var segments: Array = [[str(base_part), damage_base_text_color]]
	if bonus_part > 0:
		segments.append(["+%d" % bonus_part, _get_damage_bonus_color()])
	return {
		"text": "%d+%d" % [base_part, bonus_part] if bonus_part > 0 else str(base_part),
		"segments": segments,
	}

## 检查并消除完整的行
func check_and_clear_lines() -> int:
	if is_animating:
		return 0
	
	lines_to_clear = _find_complete_lines()
	# Talentless（无才能）：直接跳过整个Spin判定函数
	var spin_type: String = "" if no_spin else _detect_spin_type()
	var clear_count = lines_to_clear.size()
	var has_ras_action: bool = clear_count > 0 or not spin_type.is_empty()
	var is_ras_dupe: bool = false
	if rAS and has_ras_action:
		is_ras_dupe = _ras_dupe_action(spin_type, clear_count)
	_log_ras_action(spin_type, clear_count, is_ras_dupe)
	
	if clear_count == 0:
		if not spin_type.is_empty():
			if AudioManager:
				AudioManager.play("spin")
			# Spin0：显示spin文本，不显示消行文本
			_show_spin_text_only(spin_type)
			
			# 【AS】全旋：Spin0 也可触发惩罚（与上次文本完全一致时）
			if allspin == 1 and spin_type == _last_clear_type and _last_clear_count == 0:
				if garbage_line_controller:
					garbage_line_controller.spawn_countdown_row(_current_stage() + 5)
			# 【rAS】逆位全旋：Spin0 也记录动作（含0行），连续两个相同动作罚20行
			if is_ras_dupe:
				_ras_apply_penalty()
			
			if spin0_btb_enabled or rAS:
				# 特殊情况：spin0触发BTB（rAS：不消行的Spin也视为一次Spin消除）
				_update_btb(true)
			# 正常情况下spin0不触发BTB也不断开BTB
			
			reset_rotation_record()
			# 记录Spin0消行信息
			_last_clear_type = spin_type
			_last_clear_count = 0
			# 【rAS】记录 Spin0 动作（含0行，用于连续相同判定）
			if rAS:
				_ras_record_action(spin_type, 0)
		else:
			# 连击断开音效（仅当连击数 > 5 时才播放）
			if combo_count > 5 and AudioManager:
				AudioManager.play("combobreak")
			# 不去重置其他消行/Spin/连击文本，让它们自然淡出消失
			combo_count = 0
			reset_rotation_record()
			current_damage = 0
			has_cleared_lines = false
		return 0
	
	# Allspin判定：落块时判定此消行是否与上次完全一致
	var is_allspin_repeat: bool = (allspin == 1 and clear_count > 0
		and clear_count == _last_clear_count and spin_type == _last_clear_type)
	has_cleared_lines = true
	var is_spin = not spin_type.is_empty()
	var is_ras_void = rAS and not is_spin
	# 单独判断is_quad
	var is_quad = false
	if clear_count >= 4:
		is_quad = true
	# 判断是否触发BTB
	var is_spin_or_quad = false
	if is_quad and not is_ras_void:
		is_spin_or_quad = true
	if is_spin:
		is_spin_or_quad = true
	
	# 播放消行音效
	if AudioManager:
		if is_quad:
			AudioManager.play("clearquad")
		elif is_spin:
			AudioManager.play("clearspin")
		else:
			AudioManager.play("clearline")
	
	_clear_lines(lines_to_clear)
	
	var damage = _calculate_damage(clear_count, spin_type)
	
	# PC判定：消行后场上没有任何方块
	var is_perfect_clear = _check_perfect_clear()
	if is_perfect_clear:
		damage += pc_damage  # PC额外伤害叠加
		_last_clear_base += pc_damage  # PC 归入本次基础伤害显示
		_show_pc_text()
		# 播放全消音效
		if AudioManager:
			AudioManager.play("allclear")
	elif text_printer:
		text_printer.remove_text("pc")
	
	current_damage = damage
	tower_controller.attack_increase_tower(damage)
	
	_update_btb(is_spin_or_quad)
	
	# 连击/BTB音效
	if AudioManager:
		var combo_played = false
		if combo_count > 0:
			# combo_count 为本次消行前的连击数（下方才+1）
			var combo_index = combo_count
			if combo_index >= 16:
				AudioManager.play("combo_16")
				combo_played = true
			elif combo_index >= 8:
				AudioManager.play("combo_8")
				combo_played = true
			elif combo_index >= 6:
				AudioManager.play("combo_6")
				combo_played = true
			elif combo_index >= 4:
				AudioManager.play("combo_4")
				combo_played = true
			elif combo_index >= 2:
				AudioManager.play("combo_2")
				combo_played = true
			elif combo_index >= 1:
				AudioManager.play("combo_1")
				combo_played = true
		if not combo_played and is_btb_active and btb_count >= 2:
			# BTB 链音效按蓄力档位：b2bcharge_1..4（仿 TETR.IO：+4/+8/+20 档）
			if btb_count >= btb_charge_at + 20:
				AudioManager.play("b2bcharge_4")
			elif btb_count >= btb_charge_at + 8:
				AudioManager.play("b2bcharge_3")
			elif btb_count >= btb_charge_at + 4:
				AudioManager.play("b2bcharge_2")
			else:
				AudioManager.play("b2bcharge_1")
	
	# 添加到伤害累积显示
	_add_damage_to_display(damage)
	
	if is_spin and spin_color_ready:
		display_spin_color = pending_spin_color
	else:
		display_spin_color = Color.YELLOW
	
	_show_clear_and_spin_text(clear_count, spin_type, damage)
	
	reset_rotation_record()
	combo_count += 1
	
	# 【AS】全旋惩罚：重复同一种消除 → 出现带七段数码倒计时的实心垃圾行（数字=当前层数+5，数字不减只加行）
	if is_allspin_repeat and garbage_line_controller:
		garbage_line_controller.spawn_countdown_row(_current_stage() + 5)
	elif is_ras_dupe:
		# 【rAS】逆位全旋惩罚：连续两个相同动作 → 直接罚 20 行（瞬间死亡级）
		_ras_apply_penalty()
	else:
		# 未被惩罚的消除（不同消除，无上涨行）→ 所有倒计时 -1（归零转普通单洞垃圾行）
		if garbage_line_controller:
			garbage_line_controller.decrement_countdowns()
	
	# 记录本次消行信息（供下次Allspin比对；rAS 记录 Void/Spin 动作）
	_last_clear_type = spin_type
	_last_clear_count = clear_count
	if rAS:
		_ras_record_action(spin_type, clear_count)
	
	return clear_count

## 更新BTB状态
func _update_btb(is_spin_or_quad: bool):
	if is_spin_or_quad:
		var prev_btb: int = btb_count
		if is_btb_active:
			# 第二次及之后连续四消/spin → BTB计数递增
			btb_count += 1
		else:
			# 第一次四消/spin → 开始计数（btb_count=1），但不显示BTB文本
			is_btb_active = true
			# BTB 计数正常累计 1→2→3→4（rAS 也是；蓄力在 btb_count>=charge_at 时以 4 开始）
			btb_count = 1
		_update_btb_text()
		# B2B 蓄力音效：首次达到蓄满阈值 → b2bcharge_start；之后按档位 →
		# b2bcharge_1（>阈值）、b2bcharge_2（+4）、b2bcharge_3（+8）、b2bcharge_4（+20）
		if AudioManager:
			if prev_btb < btb_charge_at and btb_count >= btb_charge_at:
				AudioManager.play("b2bcharge_start")
			elif btb_count >= btb_charge_at + 20:
				AudioManager.play("b2bcharge_4")
			elif btb_count >= btb_charge_at + 8:
				AudioManager.play("b2bcharge_3")
			elif btb_count >= btb_charge_at + 4:
				AudioManager.play("b2bcharge_2")
			elif btb_count > btb_charge_at:
				AudioManager.play("b2bcharge_1")
	else:
		var visible_btb_count: int = _get_visible_btb_count()
		var was_charged: bool = visible_btb_count >= btb_charge_at if rAS else btb_count >= btb_charge_at
		var released_amount: int = visible_btb_count if rAS else btb_count
		btb_count = 0
		is_btb_active = false
		if text_printer:
			text_printer.remove_text("btb")
		# 蓄满后断开 → 徽章爆炸动画（TETR.IO down_send）；否则直接移除徽章
		if effect_manager:
			if was_charged and _tetrio_skin():
				effect_manager.break_b2b_badge(released_amount)
			else:
				effect_manager.clear_b2b_badge()
		# 蓄满后断开 → 电荷释放特效（碎片+冲击波+文字，仅 TETR.IO 皮肤）
		if was_charged and _tetrio_skin():
			_btb_charge_release(released_amount)
		board_drawer.queue_redraw()

## BTB蓄力指示：随BTB计数填充圆点，蓄满后显示 CHARGED
## 仅 TETR.IO 皮肤显示（b2bcharging 特效）；其他皮肤保持原有 N x BTB 文本
func _update_btb_charge_text():
	if not is_btb_active:
		return
	if not _tetrio_skin():
		return
	var cell: float = board_drawer.cell_size
	if not effect_manager:
		return
	# 【rAS】通知特效管理器：rAS 时蓄力数字用 DS Crystal 字体 + 红渐变
	effect_manager.set_ras_mode(rAS)
	var badge_count: int = _get_visible_btb_count() if rAS else btb_count
	if badge_count >= btb_charge_at:
		# 六边形徽章 + 蓄力数字（徽章位于 BTB 文本左侧，同 TETR.IO）
		# badge_pos.x 作为徽章右边缘锚点：徽章向左生长，绝不遮挡右侧 "B2B X" 文本
		var anchor_x: float = _get_text_anchor_x()
		var text_width: float = 0.0
		var font := ThemeDB.fallback_font
		var txt := text_printer.get_text("btb") if text_printer else ""
		if not txt.is_empty():
			text_width = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(cell)).x
		var badge_pos: Vector2 = Vector2(anchor_x - text_width - cell * 0.8, _get_text_base_y() + (btb_text_offset_y_cells + 0.9) * cell)
		effect_manager.set_b2b_badge(badge_pos, badge_count, btb_charge_at, cell)
	else:
		effect_manager.clear_b2b_badge()

## 当前是否使用 TETR.IO 皮肤（决定是否启用 b2b 蓄力特效）
func _tetrio_skin() -> bool:
	return SkinManager != null and SkinManager.current_skin_id == "tetrio"

## 懒加载 DS Crystal 字体（rAS 蓄满时伤害弹字用；缺失时回退 fallback）
const SEG_FONT_PATH: String = "res://Assets/allspin/cristal.ttf"
var _ras_font: FontFile = null
var _ras_font_load_failed: bool = false

func _get_ras_font() -> FontFile:
	if _ras_font != null or _ras_font_load_failed:
		return _ras_font
	if ResourceLoader.exists(SEG_FONT_PATH):
		var imported: Resource = load(SEG_FONT_PATH)
		if imported is FontFile:
			_ras_font = imported
			return _ras_font
	_ras_font = FontFile.new()
	if _ras_font.load_dynamic_font(SEG_FONT_PATH) != OK:
		push_warning("cristal.ttf 加载失败，rAS 伤害数字回退 fallback: ", SEG_FONT_PATH)
		_ras_font = null
		_ras_font_load_failed = true
	return _ras_font

## 特效管理器是否可用（脚本成功挂载的 EffectManager 节点才返回 true）
func _has_effects() -> bool:
	return effect_manager != null

## 当前楼层号（0 起）：全旋惩罚倒计时 = 当前层数 + 5（与 TETR.IO 一致：5 + floor）
func _current_stage() -> int:
	if tower_controller:
		return int(tower_controller.current_stage)
	return 0

# ====== 【rAS】逆位全旋 动作记录 / 惩罚 ======

## rAS 动作记录：{"action": "spin"/"void", "count": 行数（Void 固定为 0）}
## 规则（TETR.IO AS-R）：只记录 Spin 不同行数（含0）或 Void 的动作；
## 只要连续两个动作相同 → 罚 20 行直接死亡。
var _ras_last_action: Dictionary = {}
var _ras_has_last: bool = false

func _ras_action_debug_label(spin_type: String, clear_count: int) -> String:
	if spin_type.is_empty():
		return "VOID" if clear_count > 0 else "NO_CLEAR"
	return "SPIN(%d)" % clear_count

func _ras_previous_action_debug_label() -> String:
	if not _ras_has_last:
		return "NONE"
	if _ras_last_action.get("action", "") == "void":
		return "VOID"
	if _ras_last_action.get("action", "") == "spin":
		return "SPIN(%d)" % int(_ras_last_action.get("count", 0))
	return "NONE"

func _log_ras_action(spin_type: String, clear_count: int, is_ras_dupe: bool) -> void:
	if piece_controller == null or not piece_controller.bot_debug_log:
		return
	print(
		"[rASAction] piece=", piece_controller.current_piece_type,
		" piece_serial=", piece_controller._bot_piece_serial,
		" ras_enabled=", rAS,
		" action=", _ras_action_debug_label(spin_type, clear_count),
		" spin_type=", spin_type if not spin_type.is_empty() else "NONE",
		" clears=", clear_count,
		" previous=", _ras_previous_action_debug_label(),
		" repeat=", is_ras_dupe
	)

## 判断本次动作是否与上次相同（连续重复 → true）
## @param spin_type: 本次Spin类型（空串 = Void 非Spin消除）
## @param clear_count: 本次消行数（Spin0 时为 0）
func _ras_dupe_action(spin_type: String, clear_count: int) -> bool:
	if not _ras_has_last:
		return false
	var cur_action: String = "spin" if not spin_type.is_empty() else "void"
	var prev_action: String = _ras_last_action.get("action", "")
	# 连续两个动作相同 → 惩罚；所有 Void 清行视为同一动作，Spin 比较行数。
	if cur_action != prev_action:
		return false
	if cur_action == "void":
		return true
	return int(_ras_last_action.get("count", -1)) == clear_count

## 记录本次 rAS 动作（在无惩罚的消行后调用）
func _ras_record_action(spin_type: String, clear_count: int) -> void:
	_ras_last_action = {
		"action": "spin" if not spin_type.is_empty() else "void",
		"count": clear_count if not spin_type.is_empty() else 0,
	}
	_ras_has_last = true

## 应用 rAS 惩罚：连续两个相同动作 → 罚 20 行（TETR.IO AS-R 同款：20 条实心倒计时行）
## 上涨实心行由 spawn_countdown_row → add_solid_garbage 处理；
## 版面顶满时 add_solid_garbage 内部会触发 _game_over → 直接死亡
func _ras_apply_penalty() -> void:
	if AudioManager:
		AudioManager.play("wound")
	if garbage_line_controller:
		for i in range(20):
			garbage_line_controller.spawn_countdown_row(_current_stage() + 5)

## BTB电荷释放：蓄满的BTB断开时，碎片爆发+冲击波
## （伤害数字由 _add_damage_to_display 统一显示一次：base + 电荷量，避免重复弹字）
func _btb_charge_release(amount: int):
	var cell: float = board_drawer.cell_size if board_drawer else 24.0
	var pos: Vector2 = _get_piece_clear_spot()
	if effect_manager:
		effect_manager.spawn_shards(pos, btb_charge_color, 26, 340.0)
		effect_manager.spawn_ring(pos, btb_charge_color, cell * 6.0, 0.6)
	if AudioManager:
		_play_charge_break_sound(amount)
		AudioManager.play("garbagesmash")
	board_drawer.queue_redraw()

## 蓄力断开音效按断开时的档位（仿 TETR.IO b2bcharge_blast_1..4，与 charge 档位同规则）：
##   < +4 → blast_1；≥ +4 → blast_2；≥ +8 → blast_3；≥ +20 → blast_4
func _play_charge_break_sound(amount: int) -> void:
	if amount >= btb_charge_at + 20:
		AudioManager.play("b2bcharge_blast_4")
	elif amount >= btb_charge_at + 8:
		AudioManager.play("b2bcharge_blast_3")
	elif amount >= btb_charge_at + 4:
		AudioManager.play("b2bcharge_blast_2")
	else:
		AudioManager.play("b2bcharge_blast_1")

## 指定电荷量的蓄力颜色：未达蓄满阈值返回默认黄，达阈值取蓄力渐变当前色
func _get_charge_color(charge: int) -> Color:
	if charge < btb_charge_at:
		return damage_bonus_default_color
	if effect_manager:
		return effect_manager.get_b2b_color(charge, btb_charge_at)
	return damage_bonus_default_color

## 本次加成/电荷伤害数字颜色（优先取刚断开的蓄力档位，其次当前 B2B 计数）
func _get_damage_bonus_color() -> Color:
	var charge: int = btb_count
	if last_surge_break > 0:
		charge = last_surge_break
	return _get_charge_color(charge)

## 本次消行位置的世界坐标中心（作为电荷释放特效锚点）
## 优先取已消除行的平均行位，兜底取当前方块位置
## 注意：行位是数据行索引（可见区域从 above_visible_rows 开始），
## 高处消行会得到屏幕外坐标，因此钳制到可见行范围内
func _get_piece_clear_spot() -> Vector2:
	var cell: float = board_drawer.cell_size if board_drawer else 24.0
	# 可见数据行范围：[above_visible_rows, above_visible_rows + grid_height - 1]
	var vis_start: int = board_drawer.above_visible_rows
	var vis_end: int = vis_start + board_drawer.grid_height - 1
	if not lines_to_clear.is_empty():
		var sum_y: int = 0
		for y: int in lines_to_clear:
			sum_y += y
		var avg_y: int = int(round(float(sum_y) / float(lines_to_clear.size())))
		avg_y = clampi(avg_y, vis_start, vis_end)
		var mid_x: int = board_drawer.grid_width / 2
		return board_drawer.cell_to_world(mid_x, avg_y) + Vector2(cell * 0.5, cell * 0.5)
	if piece_controller:
		var cur: Vector2i = piece_controller.current_position
		var cy: int = clampi(cur.y, vis_start, vis_end)
		return board_drawer.cell_to_world(cur.x, cy) + Vector2(cell * 0.5, cell * 0.5)
	return btb_text_position + Vector2(0, -cell * 0.5)

## 更新BTB文本（常驻显示，不随消行淡出）
func _update_btb_text():
	var btb_text = _get_btb_text()
	if not text_printer:
		return
	if not btb_text.is_empty():
		var hold_pos = board_drawer._get_hold_position()
		var hold_height = board_drawer.hold_display_height * board_drawer.cell_size
		var bottom_y = hold_pos.y + hold_height
		var btb_offset_y = btb_text_offset_y_cells * board_drawer.cell_size
		btb_text_position = Vector2(_get_text_anchor_x(), bottom_y + btb_offset_y)
		# BTB常驻显示（persistent=true），直到断开BTB时才移除
		text_printer.show_text("btb", btb_text, btb_text_position,
			btb_text_color, btb_text_outline_color, board_drawer.cell_size * 1.0,
			true, 1.0)
		_update_btb_charge_text()
	else:
		text_printer.remove_text("btb")
		if effect_manager:
			effect_manager.clear_b2b_badge()

## 检查是否 Perfect Clear（场上没有任何方块）
func _check_perfect_clear() -> bool:
	for y in range(board_drawer.get_playable_height()):
		for x in range(board_drawer.grid_width):
			if board_drawer.get_cell_color(x, y) != null:
				return false
	return true

## 显示 PC 文本
func _show_pc_text():
	if not text_printer:
		return
	var hold_pos = board_drawer._get_hold_position()
	var hold_height = board_drawer.hold_display_height * board_drawer.cell_size
	var bottom_y = hold_pos.y + hold_height
	var pc_offset_y = pc_text_offset_y_cells * board_drawer.cell_size
	pc_text_position = Vector2(_get_text_anchor_x(), bottom_y + pc_offset_y)
	text_printer.show_text("pc", "PERFECT CLEAR", pc_text_position,
		pc_text_color, pc_text_outline_color, board_drawer.cell_size * 1.2,
		_is_allspin_ui_mode(), text_base_opacity, clear_text_display_duration, text_fade_duration, _get_text_drift(),
		HORIZONTAL_ALIGNMENT_RIGHT, true, 0.4)

## 计算攻击伤害
func _calculate_damage(clear_count: int, spin_type: String) -> int:
	var base_damage = 0
	var spin_damage = 0
	var surge_break = 0
	var is_ras_void = rAS and spin_type.is_empty()
	var effective_clear_count = 1 if is_ras_void else clear_count
	_last_clear_ras_b2b_plus_two = false
	
	if not spin_type.is_empty():
		# 【rAS】逆位全旋：Spin 使用 All-Spin 伤害表（全旋加成，4/6/8）
		if rAS:
			spin_damage = allspin_damage_table.get(clear_count, base_damage_table.get(clear_count, 0))
		else:
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
				# 非Mini非T-Spin的全旋（如"I-Spin"、"L-Spin"等）→ 使用T-Spin伤害表作为通用全旋伤害
				var full_spin_data: Dictionary = spin_damage_table.get("T-Spin", {})
				spin_damage = full_spin_data.get(clear_count, base_damage_table.get(clear_count, 0))
		
		base_damage = 0
	else:
		base_damage = base_damage_table.get(clear_count, 0)
	
	# 记录本次消行的攻击值（base+spin，不含BTB加成），供连击公式使用
	var attack_value: int = base_damage + spin_damage
	
	# 【rAS】逆位全旋：所有非Spin消除称为 Void，无攻击
	if is_ras_void:
		base_damage = 0
		spin_damage = 0
		attack_value = 0
	
	# BTB 加成（从第二次连续BTB开始；btb>=4 时额外+1，即 +2）- 适用于 spin 和 quad
	# BTB 加成（从第二次连续BTB开始；固定 +1）- 适用于 spin 和 quad
	var btb_boost: int = 0
	if btb_count > 1:
		if not spin_type.is_empty():
			# rAS：B2B 加伤 +2 仅在 btb>=4（蓄满）时获得；不足 4 只 +1
			btb_boost = 2 if (rAS and btb_count >= btb_charge_at) else 1
			_last_clear_ras_b2b_plus_two = rAS and btb_boost == 2
			spin_damage += btb_boost
		elif not is_ras_void and clear_count >= 4:
			btb_boost = 1
			base_damage += btb_boost
	
	if is_ras_void and _get_visible_btb_count() >= 4:
		surge_break = _get_visible_btb_count()
	else:
		surge_break = 0
	last_surge_break = surge_break  # 记录本次是否断开蓄力（供伤害数字染色）
	
	var combo_damage = 0
	if combo_count > 0:
		if combo_formula == 1:
			# 新公式（默认）：
			#   combo_damage = floor(max(ln(1+1.25*combo), ((is_btb_active?1:0)+attack)*(1+0.25*combo)))
			#   其中 attack = base+spin（不含BTB加成）
			var b2b_flag: float = 1.0 if is_btb_active else 0.0
			var combined: float = (b2b_flag + float(attack_value)) * (1.0 + 0.25 * float(combo_count))
			var log_term: float = log(1.0 + 1.25 * float(combo_count))
			combo_damage = floori(max(log_term, combined))
		else:
			# 旧连击表（备选项）
			var is_mini: bool = spin_type.find("Mini") != -1
			var is_quad: bool = effective_clear_count >= 4
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
	
	var total_damage: int = base_damage + spin_damage + combo_damage + surge_break
	# 记录本次消行的 base+bonus 拆分（供伤害数字显示）：
	# bonus = B2B 加成 或 surge_break（两者互斥：spin/quad 走 btb_boost，普通小消走 surge）
	_last_clear_bonus = btb_boost + surge_break
	_last_clear_base = total_damage - _last_clear_bonus
	return total_damage

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

## 供 bot 读取当前 buff 调整后的并行搜索线程数（0 = 由 bridge 自动决定）。
func get_bot_threads() -> int:
	return bot_threads

## 供 bot 读取“实际游戏规则/伤害模型”的伤害表（lt→bot 桥接）。
## 返回当前生效的基础伤害表、T-Spin 伤害表、连击伤害表、BTB 加成、PC 伤害。
## 这些表可由 buff 界面（extra_data）调整后读取，bot 据此模拟真实伤害。
func get_damage_tables() -> Dictionary:
	var tbl := {}
	tbl["enabled"] = true
	# 基础伤害表（按下标=消行数 0..4）
	var base: Array = []
	for i in range(5):
		base.append(base_damage_table.get(i, 0))
	tbl["base_damage"] = base
	# T-Spin 伤害表（按下标=消行数 0..3，下标0为0）
	var tspin: Array = [0, 0, 0, 0]
	var ts_data: Dictionary = spin_damage_table.get("T-Spin", {})
	for i in range(1, 4):
		tspin[i] = ts_data.get(i, 0)
	tbl["tspin_damage"] = tspin
	# 连击伤害表（按下标=连击数 0..31）
	var combo: Array = []
	for i in range(32):
		if i < combo_damage_list.size():
			combo.append(combo_damage_list[i])
		else:
			# 超出表长：min(5, list[-1] + (i - size)/2)，与 _calculate_damage 一致
			var extra: float = (i - combo_damage_list.size()) / 2.0
			combo.append(min(5, combo_damage_list[-1] + int(extra)))
	tbl["combo_damage"] = combo
	# 连击计算方式：0=旧连击表，1=新公式（默认）——同步给 CC 的 combo 处理
	tbl["combo_formula"] = combo_formula
	tbl["b2b_bonus"] = 1
	tbl["pc_damage"] = pc_damage
	# All-Spin 伤害表（独立表，默认同 T-Spin 值，可由 buff 调整）
	var allspin_table: Array = [0, 0, 0, 0]
	for i in range(1, 4):
		allspin_table[i] = allspin_damage_table.get(i, 0)
	tbl["allspin_damage"] = allspin_table
	# allspin_1 规则是否启用（allspin==1）
	tbl["allspin_enabled"] = (allspin == 1)
	# rAS search state is snapshot-carried because the native worker may reuse a bot.
	# -1 = no prior action, 0 = VOID, 1..5 = SPIN(0..4).
	tbl["ras_enabled"] = rAS
	var ras_previous_action := -1
	if rAS and _ras_has_last:
		if _ras_last_action.get("action", "") == "void":
			ras_previous_action = 0
		elif _ras_last_action.get("action", "") == "spin":
			ras_previous_action = clampi(int(_ras_last_action.get("count", 0)) + 1, 1, 5)
	tbl["ras_previous_action"] = ras_previous_action
	# bot 评估权重：仅返回 buff 显式传参的键（bot_weight_override_keys 由
	# tower_controller._extra_data_deal 填充）。这样 bridge 默认权重为主，
	# 只有 buff 真正传了参的键才会覆盖 bridge。
	var bot_weights := {
		"eval_mult": bot_eval_mult,
		"attack_efficiency_weight": bot_attack_efficiency_weight,
		"b2b_clear": bot_b2b_clear,
		"height": bot_height,
		"clear4": bot_clear4,
		"clear1": bot_clear1,
		"clear2": bot_clear2,
		"clear3": bot_clear3,
		"tspin1": bot_tspin1,
		"tspin2": bot_tspin2,
		"tspin3": bot_tspin3,
		"mini_tspin1": bot_mini_tspin1,
		"mini_tspin2": bot_mini_tspin2,
		"allspin1": bot_allspin1,
		"allspin2": bot_allspin2,
		"allspin3": bot_allspin3,
		"allspin3plus": bot_allspin3plus,
		"perfect_clear": bot_perfect_clear,
		"combo_garbage": bot_combo_garbage,
		"wasted_t": bot_wasted_t,
		"move_time": bot_move_time,
		"allspin_repeat_penalty": bot_allspin_repeat_penalty,
	}
	for key in bot_weights:
		if bot_weight_override_keys.has(key):
			tbl[key] = bot_weights[key]
	return tbl

## 获取连击文本
func _get_combo_text() -> String:
	if combo_count > 0:
		return "%d Combo" % combo_count
	return ""

## 获取BTB文本
func _get_btb_text() -> String:
	if is_btb_active and btb_count > 1:
		return "%d x BTB" % _get_visible_btb_count()
	return ""

func _get_visible_btb_count(internal_count: int = btb_count) -> int:
	return maxi(0, internal_count - 1)

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
	
	# 消行碎片特效：在每一格位置飞溅对应颜色的小方块
	if effect_manager:
		for y: int in lines:
			for x in range(board_drawer.grid_width):
				var cell_color: Variant = board_drawer.get_cell_color(x, y)
				if cell_color != null and typeof(cell_color) == TYPE_COLOR:
					var world_pos: Vector2 = board_drawer.cell_to_world(x, y) + Vector2(board_drawer.cell_size, board_drawer.cell_size) * 0.5
					effect_manager.spawn_shards(world_pos, cell_color as Color, 1, 190.0)
	
	for y in lines:
		_clear_single_line(y)
	
	# 【AS】倒计时行同步：被清除行上方的行整体下移，倒计时行索引跟着下移
	if garbage_line_controller:
		garbage_line_controller.on_lines_cleared(lines)
	
	board_drawer.queue_redraw()

func _clear_single_line(line_y: int):
	for y in range(line_y, 0, -1):
		for x in range(board_drawer.grid_width):
			board_drawer.copy_cell(x, y - 1, x, y)
	
	for x in range(board_drawer.grid_width):
		board_drawer.set_cell_color(x, 0, null)

# ========== Spin检测系统 ==========

func _detect_spin_type() -> String:
	if no_spin:
		return ""
	if not spin_detection_enabled:
		return ""
	
	if not last_rotation_occurred:
		return ""
	
	if not _is_piece_stuck(last_rotation_piece_shape, last_rotation_position):
		# 未卡住 → T块额外检测 Mini T-Spin
		if last_rotation_piece_type == "T":
			return _detect_t_spin_mini()
		return ""
	
	# 卡住了
	if last_rotation_piece_type == "T":
		# T块卡住 → 全 T-Spin
		return "T-Spin"
	
	return _get_non_t_spin_label(last_rotation_piece_type)

func _get_non_t_spin_label(piece_type: String) -> String:
	if allspin == 1 or rAS:
		return piece_type + "-Spin"
	return "Mini " + piece_type + "-Spin"

func _is_piece_stuck(shape: Array, piece_position: Vector2i) -> bool:
	if not piece_controller:
		return false
	
	var directions = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	
	for dir in directions:
		var new_pos = Vector2i(piece_position.x + dir.x, piece_position.y + dir.y)
		if not piece_controller._check_collision(new_pos, shape):
			return false
	
	return true


## 检测T块专用 Mini T-Spin
## 条件：左下和右下都被方块或墙占据，且左上或右上有一个被方块或墙占据
## 返回 "Mini T-Spin" 或 ""
func _detect_t_spin_mini() -> String:
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

## 【rAS】Void 消除文本：常驻显示，直到下一次消除才被替换
func _show_void_text() -> void:
	if not text_printer:
		return
	var cell = board_drawer.cell_size
	var bottom_y = _get_text_base_y()
	var anchor_x = _get_text_anchor_x()
	var offset_y = clear_text_offset_y_cells * cell
	clear_text_position = Vector2(anchor_x, bottom_y + offset_y)
	text_printer.remove_text("clear")
	text_printer.remove_text("spin")
	text_printer.show_text("clear", "VOID", clear_text_position,
		clear_text_color, clear_text_outline_color, cell * 1.0,
		true, text_base_opacity)

## 文本锚点X坐标：版面外侧，距离左边框一小段距离
func _get_text_anchor_x() -> float:
	return board_drawer.offset_x - text_gap_cells * board_drawer.cell_size

## 非BTB文本的漂移速度（向左慢慢移动）
func _get_text_drift() -> Vector2:
	return Vector2(-text_drift_cells_per_sec * board_drawer.cell_size, 0)

## 消行文本基准Y（Hold框底部）
func _get_text_base_y() -> float:
	var hold_pos = board_drawer._get_hold_position()
	var hold_height = board_drawer.hold_display_height * board_drawer.cell_size
	return hold_pos.y + hold_height

## Allspin / 逆位全旋 模式：消行文本常驻显示（直到下一次消除才替换）
## 其他模式走默认 VFX（弹出 → 漂移 → 淡出）
func _is_allspin_ui_mode() -> bool:
	return allspin == 1 or rAS

func _show_clear_and_spin_text(clear_count: int, spin_type: String, _damage: int):
	if clear_count <= 0 or not text_printer:
		return
	
	# 【rAS】非Spin消除显示 "VOID"（像 SINGLE/DOUBLE/TRIPLE 一样弹字，常驻直到下次消除）
	if rAS and spin_type.is_empty():
		_show_void_text()
		return
	
	var clear_text = _get_clear_text(clear_count)
	if clear_text.is_empty():
		return
	
	var cell = board_drawer.cell_size
	var bottom_y = _get_text_base_y()
	var anchor_x = _get_text_anchor_x()
	
	var clear_spin_drift: Vector2 = _get_text_drift() * clear_spin_drift_scale
	var clear_spin_fade: float = text_fade_duration * clear_spin_fade_scale
	# 淡出与移动并行：这里把保持期缩短，让淡出在文本仍在移动时就开始
	var clear_spin_hold: float = clear_text_display_duration * clear_spin_hold_scale
	
	# Allspin/rAS：常驻显示；其他模式走默认 VFX（弹出→漂移→淡出）
	var ui_persist: bool = _is_allspin_ui_mode()
	var offset_y = clear_text_offset_y_cells * cell
	clear_text_position = Vector2(anchor_x, bottom_y + offset_y)
	text_printer.remove_text("clear")
	text_printer.show_text("clear", clear_text, clear_text_position,
		clear_text_color, clear_text_outline_color, cell * 1.0,
		ui_persist, text_base_opacity,
		clear_text_display_duration, text_fade_duration, _get_text_drift(),
		HORIZONTAL_ALIGNMENT_RIGHT, true, 0.3)
	
	if not spin_type.is_empty():
		var spin_offset_y = (clear_text_offset_y_cells - spin_text_offset_y_cells) * cell
		spin_text_position = Vector2(anchor_x, bottom_y + spin_offset_y)
		text_printer.remove_text("spin")
		text_printer.show_text("spin", spin_type, spin_text_position,
			display_spin_color, spin_text_outline_color, cell * 0.8,
			ui_persist, text_base_opacity,
			clear_text_display_duration, text_fade_duration, _get_text_drift(),
			HORIZONTAL_ALIGNMENT_RIGHT, true, 0.3)
	else:
		text_printer.remove_text("spin")
	
	var combo_text = _get_combo_text()
	if not combo_text.is_empty():
		var combo_offset_y = (clear_text_offset_y_cells + combo_text_offset_y_cells) * cell
		combo_text_position = Vector2(anchor_x, bottom_y + combo_offset_y)
		# combo 特例：有新 combo 时立即重置，移除旧文本后再显示新的，不做叠加
		text_printer.remove_text("combo")
		text_printer.show_text("combo", combo_text, combo_text_position,
			combo_text_color, combo_text_outline_color, cell * 0.8,
			false, text_base_opacity, clear_text_display_duration, text_fade_duration, _get_text_drift(),
			HORIZONTAL_ALIGNMENT_RIGHT, true, 0.3)
	else:
		text_printer.remove_text("combo")
	
	# BTB常驻显示（persistent=true）
	var btb_text = _get_btb_text()
	if not btb_text.is_empty():
		var btb_offset_y = btb_text_offset_y_cells * cell
		btb_text_position = Vector2(anchor_x, bottom_y + btb_offset_y)
		text_printer.show_text("btb", btb_text, btb_text_position,
			btb_text_color, btb_text_outline_color, cell * 1.0,
			true, 1.0)
	else:
		text_printer.remove_text("btb")
	
	##print("消行: ", clear_count, "，Spin: ", spin_type, "，伤害: ", damage, "，Spin颜色: ", display_spin_color)

## 仅显示Spin文本（无消行，Spin0）
func _show_spin_text_only(spin_type: String):
	if spin_type.is_empty() or not text_printer:
		return
	
	if spin_color_ready:
		display_spin_color = pending_spin_color
	else:
		display_spin_color = Color.YELLOW
	
	var cell = board_drawer.cell_size
	# 计算spin文本位置
	spin_text_position = Vector2(_get_text_anchor_x(), _get_text_base_y() + spin_text_offset_y_cells * cell)
	# Allspin/rAS：常驻显示；其他模式走默认 VFX
	text_printer.remove_text("spin")
	text_printer.show_text("spin", spin_type, spin_text_position,
		display_spin_color, spin_text_outline_color, cell * 0.8,
		_is_allspin_ui_mode(), text_base_opacity,
		clear_text_display_duration, text_fade_duration, _get_text_drift(),
		HORIZONTAL_ALIGNMENT_RIGHT, true, 0.3)
	# 不重置其他文本，让它们自然淡出

## 获取当前显示的Spin文本颜色
func get_spin_trigger_color() -> Color:
	return display_spin_color

## 检查是否有消行文本正在显示
func is_text_displaying() -> bool:
	return text_printer != null and text_printer.has_text("clear")

## 获取当前显示的Spin文本（供PieceController统计用）
func get_current_spin_text() -> String:
	if text_printer:
		return text_printer.get_text("spin")
	return ""

## 重置消行状态
func reset():
	lines_to_clear.clear()
	is_animating = false
	if text_printer:
		text_printer.clear_all()
	if effect_manager:
		effect_manager.clear_all()
	damage_timer.stop()
	reset_rotation_record()
	combo_count = 0
	btb_count = 0
	is_btb_active = false
	current_damage = 0
	accumulated_damage = 0
	damage_pending = false
	_last_clear_ras_b2b_plus_two = false
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
