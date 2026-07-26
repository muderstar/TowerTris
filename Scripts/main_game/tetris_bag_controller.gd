extends Node
class_name TetrisBagController

## 俄罗斯方块Bag生成器
## 负责7-Bag随机生成器逻辑，管理方块序列

# 方块类型定义
enum PieceType {
	I, O, T, S, Z, J, L
}

# 方块形状定义（矩阵）
# I: 4x4
const SHAPE_I = [
	[0, 0, 0, 0],
	[1, 1, 1, 1],
	[0, 0, 0, 0],
	[0, 0, 0, 0]
]

# O: 2x2
const SHAPE_O = [
	[1, 1],
	[1, 1]
]

# T: 3x3
const SHAPE_T = [
	[0, 1, 0],
	[1, 1, 1],
	[0, 0, 0]
]

# S: 3x3
const SHAPE_S = [
	[0, 1, 1],
	[1, 1, 0],
	[0, 0, 0]
]

# Z: 3x3
const SHAPE_Z = [
	[1, 1, 0],
	[0, 1, 1],
	[0, 0, 0]
]

# J: 3x3
const SHAPE_J = [
	[1, 0, 0],
	[1, 1, 1],
	[0, 0, 0]
]

# L: 3x3
const SHAPE_L = [
	[0, 0, 1],
	[1, 1, 1],
	[0, 0, 0]
]

# 方块颜色
const COLORS = {
	"I": Color(0.0, 0.8, 0.8),  # 青色
	"O": Color(1.0, 0.8, 0.0),  # 黄色
	"T": Color(0.8, 0.0, 0.8),  # 紫色
	"S": Color(0.0, 1.0, 0.0),  # 绿色
	"Z": Color(1.0, 0.0, 0.0),  # 红色
	"J": Color(0.0, 0.0, 1.0),  # 蓝色
	"L": Color(1.0, 0.5, 0.0)   # 橙色
}

# 方块数据映射
var piece_data: Dictionary = {
	"I": {"shape": SHAPE_I, "color": COLORS["I"]},
	"O": {"shape": SHAPE_O, "color": COLORS["O"]},
	"T": {"shape": SHAPE_T, "color": COLORS["T"]},
	"S": {"shape": SHAPE_S, "color": COLORS["S"]},
	"Z": {"shape": SHAPE_Z, "color": COLORS["Z"]},
	"J": {"shape": SHAPE_J, "color": COLORS["J"]},
	"L": {"shape": SHAPE_L, "color": COLORS["L"]}
}

# 方块类型列表（用于生成）
var piece_types: Array = ["I", "O", "T", "S", "Z", "J", "L"]

# 方块序列
var piece_queue: Array = []  # 存储方块类型名称的队列

# 信号
signal piece_spawned(piece_type: String, shape: Array, color: Color)

## 生成单个7-Bag（7个不同方块的随机排列）
func _generate_single_bag() -> Array:
	var new_bag = piece_types.duplicate()
	var bag_rng = RandomManager.get_random("BAG")
	for i in range(new_bag.size() - 1, 0, -1):
		var j = bag_rng.randi_range(0, i)
		var temp = new_bag[i]
		new_bag[i] = new_bag[j]
		new_bag[j] = temp
	return new_bag

## 补充方块序列（当队列少于14个时补充）
func _refill_queue():
	while piece_queue.size() < 14:
		var new_bag = _generate_single_bag()
		piece_queue += new_bag
		# print("当前序列：",piece_queue)

## 获取下一个方块（从队列头部取出）
func get_next_piece() -> Dictionary:
	# 检查是否需要补充（队列少于14个时补充）
	if piece_queue.size() < 14:
		_refill_queue()
	
	# 取出第一个方块
	var piece_type = piece_queue.pop_front()
	
	# 获取方块数据（深拷贝形状矩阵，防止引用污染）
	var shape = _deep_copy_matrix(piece_data[piece_type]["shape"])
	var color = piece_data[piece_type]["color"]
	
	# 发射信号
	piece_spawned.emit(piece_type, shape, color)
	
	return {
		"type": piece_type,
		"shape": shape,
		"color": color
	}

## 获取下一个方块的类型（用于预览）
func peek_next_piece() -> String:
	if piece_queue.is_empty():
		return "I"
	return piece_queue[0]

## 获取接下来N个方块的类型（用于Next显示）
func peek_next_pieces(count: int = 4) -> Array:
	var result = []
	
	# 确保队列有足够的方块
	while piece_queue.size() < count:
		_refill_queue()
	
	for i in range(count):
		result.append(piece_queue[i])
	
	return result

## 获取当前队列的副本（用于调试）
func get_queue_copy() -> Array:
	return piece_queue.duplicate()

## 深拷贝矩阵
func _deep_copy_matrix(matrix: Array) -> Array:
	var copy = []
	for row in matrix:
		copy.append(row.duplicate())
	return copy

## 获取方块的原始形状（未旋转状态）
func get_original_shape(piece_type: String) -> Array:
	return _deep_copy_matrix(piece_data[piece_type]["shape"])

## 获取方块的颜色
func get_piece_color(piece_type: String) -> Color:
	return piece_data[piece_type]["color"]

## 获取方块类型名称
func get_piece_type_name(piece_type: String) -> String:
	return piece_type

# ========== 回放模式（已禁用） ==========
# var _replay_mode: bool = false
# var _replay_sequence: Array = []
# var _replay_index: int = 0
# 
# ## 启用回放模式，使用预先生成的方块序列
# func enable_replay_mode(sequence: Array):
# 	_replay_mode = true
# 	_replay_sequence = sequence.duplicate()
# 	_replay_index = 0
# 	piece_queue.clear()
# 	piece_queue = sequence.duplicate()
# 	print("回放模式已启用，序列长度: ", piece_queue.size())
# 
# ## 关闭回放模式
# func disable_replay_mode():
# 	_replay_mode = false
# 	_replay_sequence.clear()
# 	_replay_index = 0
# 	piece_queue.clear()
# 	_refill_queue()
# 
# func is_replay_mode() -> bool:
# 	return _replay_mode
# 
# ## 重置生成器（用于Replay）
# func reset():
# 	piece_queue.clear()
# 	if _replay_mode:
# 		piece_queue = _replay_sequence.duplicate()
# 		_replay_index = 0
# 	else:
# 		_refill_queue()
