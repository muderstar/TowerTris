extends Node

## 音频管理器
## 全局单例：加载并播放音效（SFX），支持多路混音与音量控制

const SFX_DIR: String = "res://Assets/sfx/"

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

## 注册全部音效（懒加载，仅在需要时从磁盘读取）
func _register_all_sounds():
	var dir = DirAccess.open(SFX_DIR)
	if not dir:
		push_warning("音频目录不存在: ", SFX_DIR)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".ogg"):
			var stream = _load_stream(SFX_DIR + file_name)
			if stream:
				var name = file_name.get_basename()
				sounds[name] = stream
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

## 预创建一批播放器用于混音
func _build_player_pool(pool_size: int = 8):
	for i in range(pool_size):
		var player := AudioStreamPlayer.new()
		player.volume_db = sfx_volume_db
		add_child(player)
		_players.append(player)

# ========== 对外接口 ==========

## 播放音效（name 为文件名，不含扩展名）
## 自动从池中选取空闲播放器，全部占用时复用第一个
func play(name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	if not sounds.has(name):
		push_warning("音效不存在: ", name)
		return
	var player: AudioStreamPlayer = _get_free_player()
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

## 获取空闲播放器
func _get_free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return _players[0]
