extends Node

## 音频管理器
## 全局单例：加载并播放音效（SFX），支持多路混音与音量控制

const SFX_DIR: String = "res://Assets/sfx/"

# 全部音效文件名（不含扩展名）。
# 注意：导出后 res:// 是打包的 PCK，无法用 DirAccess 枚举目录，
# 因此必须用显式列表 + load() 加载（编辑器与导出包均可用）。
const SOUND_NAMES: Array[String] = [
	"allclear", "boardappear", "boardlock", "boardlock_clear",
	"btb_1", "btb_2", "btb_3", "btb_break",
	"b2bcharge_start", "b2bcharge_1", "b2bcharge_2", "b2bcharge_3",
	"b2bcharge_danger", "b2bcharge_blast_1", "b2bcharge_blast_2",
	"b2bcharge_blast_3", "b2bcharge_blast_4",
	"clearline", "clearquad", "clearspin",
	"combo_1", "combo_2", "combo_4", "combo_6", "combo_8", "combo_16",
	"combobreak", "countdown1", "countdown3",
	"gameover", "garbage_in_small", "garbagerise", "garbagesmash",
	"go", "harddrop", "hold", "hyperalert", "levelup",
	"menuback", "menuclick", "menuconfirm", "menuhover",
	"move", "pause_continue", "pause_start", "piece_change",
	"rotate", "softdrop", "spin", "victory", "warning",
]

# 预加载的音效表（名称 → AudioStream）
var sounds: Dictionary = {}

# 播放器池（允许同音效叠加播放）
var _players: Array[AudioStreamPlayer] = []

# 音量设置（分贝）
var sfx_volume_db: float = 0.0

# ========== 生命周期 ==========

func _ready():
	_register_all_sounds()
	_build_player_pool()

## 注册全部音效（显式列表加载，兼容编辑器与导出包）
func _register_all_sounds():
	for name in SOUND_NAMES:
		var stream = _load_stream(SFX_DIR + name + ".ogg")
		if stream:
			sounds[name] = stream
	if sounds.is_empty():
		push_warning("未加载到任何音效，请检查 res://Assets/sfx/ 资源是否已导入")

func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

## 预创建一批播放器用于混音（更大的池 + 每条音效独立播放，减少互相打断）
func _build_player_pool(pool_size: int = 24):
	for i in range(pool_size):
		var player := AudioStreamPlayer.new()
		player.volume_db = sfx_volume_db
		add_child(player)
		_players.append(player)

# ========== 对外接口 ==========

## 播放音效（name 为文件名，不含扩展名）
## 自动从池中选取空闲播放器；全部占用时复用"已播放最久"的播放器，
## 保证新的音效总能播出，且不会频繁打断刚响起的音效。
func play(name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	if not sounds.has(name):
		push_warning("音效不存在: ", name)
		return
	var player: AudioStreamPlayer = _get_free_player()
	if player == null:
		return
	player.stream = sounds[name]
	player.volume_db = sfx_volume_db + volume_db
	player.pitch_scale = pitch_scale
	player.play()

## 停止某个音效
func stop(name: String):
	for player in _players:
		if player.stream == sounds.get(name):
			player.stop()

## 停止所有音效
func stop_all():
	for player in _players:
		player.stop()

## 设置音效音量（分贝）
func set_sfx_volume(value_db: float):
	sfx_volume_db = value_db
	for player in _players:
		player.volume_db = sfx_volume_db

## 获取空闲播放器；全部占用时复用已播放时间最长的那个（最早开始 → 最接近自然结束）。
## 不再总是复用 _players[0]（那会反复打断同一个播放器上的音效）。
func _get_free_player() -> AudioStreamPlayer:
	var free: Array[AudioStreamPlayer] = []
	for player in _players:
		if not player.playing:
			free.append(player)
	if not free.is_empty():
		return free[0]
	# 全部占用：找出播放最久的（get_playback_position 相对播放长度，最接近结束）
	var oldest: AudioStreamPlayer = _players[0]
	var oldest_remain: float = 1e9
	for player in _players:
		var stream_len: float = player.stream.get_length() if player.stream else 0.0
		var remain: float = stream_len - player.get_playback_position()
		if remain < oldest_remain:
			oldest_remain = remain
			oldest = player
	return oldest
