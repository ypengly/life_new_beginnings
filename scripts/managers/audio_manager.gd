extends Node
## Audio + settings. SFX are synthesized so the game has sound without any asset files.
## Drop .ogg files in assets/audio/music and assets/audio/ambience to add real tracks.

const CFG := "user://settings.cfg"
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080"]
var settings := {"master": 0.8, "music": 0.6, "sfx": 0.8, "fullscreen": false, "resolution": "1280x720", "vsync": true,
	"language": "English", "text_speed": 1.0, "autosave": true}
var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer

func _ready() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	_sfx = {"click": _tone(880, 0.05), "coin": _tone(1320, 0.1), "error": _tone(170, 0.18), "event": _tone(660, 0.3),
		"step": _tone(110, 0.04, 0.25), "door": _tone(300, 0.14), "engine": _tone(80, 0.3, 0.35), "notify": _tone(990, 0.08)}
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new(); _music.bus = "Music"; add_child(_music)
	_ambient = AudioStreamPlayer.new(); _ambient.bus = "Music"; add_child(_ambient)
	load_settings()
	apply_settings()

func _tone(freq: float, dur: float, vol := 0.4) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / n
		bytes.encode_s16(i * 2, int(sin(TAU * freq * float(i) / rate) * env * vol * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = bytes
	return w

func play_sfx(name: String) -> void:
	if not _sfx.has(name): return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[name]
			p.play()
			return

func play_music(path: String, ambient := false) -> void:
	if not ResourceLoader.exists(path): return
	var stream = load(path)
	if stream is AudioStreamOggVorbis: stream.loop = true
	var pl := _ambient if ambient else _music
	pl.stream = stream
	pl.play()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings.master), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(float(settings.music), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(float(settings.sfx), 0.0001)))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var parts: PackedStringArray = str(settings.resolution).split("x")
		if parts.size() == 2: DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))

func save_settings() -> void:
	var c := ConfigFile.new()
	for k in settings: c.set_value("settings", k, settings[k])
	c.save(CFG)

func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) != OK: return
	for k in settings: settings[k] = c.get_value("settings", k, settings[k])
