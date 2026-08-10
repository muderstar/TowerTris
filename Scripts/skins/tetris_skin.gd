extends Resource
class_name TetrisSkin

## 皮肤资源类
## 定义一套方块皮肤：方块类型 → 贴图
## piece_textures 为空时表示使用纯色（original 皮肤行为）

@export var skin_id: String = "original"
@export var display_name: String = "Original"

# 方块类型 → Texture2D（如 {"Z": preload(...), "L": ...}）
# 为空字典时，绘制回退到 BlockData.json 提供的纯色
@export var piece_textures: Dictionary = {}
