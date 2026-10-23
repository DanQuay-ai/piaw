class_name Audio
## Sound effects, ambience and voice lines (with subtitles).
const SFX := "res://audio/sfx/"
const VO := "res://audio/vo/"

## key -> [file(s), subtitle, translation]
const LINES := {
	"masa_ku_no": [["khaya_male_low_masa_ku_no.wav", "khaya_male_high_masa_ku_no.wav", "v3_masa_ku_no.mp3"], "Masa, ku no!", "Bro, kill him!"],
	"ajei": [["khaya_male_low_ajei.wav", "khaya_male_high_ajei.wav", "v3_ajei.mp3"], "Agyei!", "Whoa!"],
	"obroni": [["khaya_male_low_obroni_ka_sen.wav", "v3_obroni.mp3"], "Ɔbroni no ka sɛn?", "What is the white man saying?"],
	"asaaka": [["khaya_male_low_asaaka.wav", "khaya_male_high_asaaka.wav", "v3_asaaka.mp3"], "Asaaka!", "Got him!"],
	"grrr_baow": [["v3_grrr_baow.mp3", "khaya_male_low_grrr_baow.wav"], "Grrrrr... BAOW!", ""],
	"yenko": [["khaya_male_low_yenko_yenko.wav", "khaya_male_high_yenko_yenko.wav", "v3_yenko.mp3"], "Yɛnkɔ, yɛnkɔ!", "Let's go, let's go!"],
	"wasei": [["khaya_male_low_wasei_ho_yenko.wav", "v3_wasei.mp3"], "Wasɛe ho! Yɛnkɔ!", "You've ruined it! Let's go!"],
	"off_hold": [["en_officer_hold.mp3"], "Hold the line, men! Hold!", ""],
	"off_ambush": [["en_officer_ambush.mp3"], "Ambush! In the trees! Form up!", ""],
	"off_where": [["en_officer_where.mp3"], "Where the devil are they?", ""],
	"off_bayonet": [["en_officer_bayonet.mp3"], "Fix bayonets! Charge!", ""],
	"off_gorilla": [["en_officer_gorilla.mp3"], "Good God, what is that beast?!", ""],
	"narr_asameni": [["narr_asameni.mp3"], "1693. Osu. The Danes of Christiansborg buy their gunpowder from Akwamu traders. Today, Asameni brings them more than powder.", ""],
	"narr_canoe": [["narr_canoe.mp3"], "1711. Pokesu. The Brandenburgers left, the Dutch came to collect. John Canoe kept the keys, and the cannons.", ""],
	"narr_amoaful": [["narr_amoaful.mp3"], "1874. Amoaful. Wolseley marches on Kumasi with rifles and rockets. The bush still belongs to the Asante.", ""],
	"narr_golden_stool": [["narr_golden_stool.mp3"], "1900. The governor demanded the Golden Stool, to sit on it. Yaa Asantewaa answered with a siege.", ""],
	"narr_intro": [["narr_intro.mp3"], "1824. Nsamankow. Sir Charles MacCarthy marches into the forest, certain the Asante will run. The forest has other plans.", ""],
}

static var root: Node
static var _cache := {}
static var _last_line := {}
static var voice: AudioStreamPlayer

static var music_p: AudioStreamPlayer
static var amb: AudioStreamPlayer

static func init(r: Node) -> void:
	root = r
	Settings.apply()
	voice = AudioStreamPlayer.new(); voice.bus = "Voice"; voice.process_mode = Node.PROCESS_MODE_ALWAYS; root.add_child(voice)
	music_p = AudioStreamPlayer.new(); music_p.bus = "Music"; music_p.process_mode = Node.PROCESS_MODE_ALWAYS; root.add_child(music_p)
	amb = AudioStreamPlayer.new(); var s: AudioStream = _load(SFX + "jungle_ambience.mp3")
	if s is AudioStreamMP3: s.loop = true
	amb.stream = s; amb.volume_db = -8; amb.bus = "SFX"; root.add_child(amb)

static func ambience(on: bool) -> void:
	if amb and on and not amb.playing: amb.play()
	elif amb and not on: amb.stop()

static func play_music(name: String, vol := -6.0) -> void:
	if not music_p: return
	var s := _load("res://audio/music/" + name + ".mp3")
	if not s or music_p.stream == s: return
	if s is AudioStreamMP3: s.loop = true
	var tw := root.create_tween()
	tw.tween_property(music_p, "volume_db", -40.0, 0.6 if music_p.playing else 0.0)
	tw.tween_callback(func(): music_p.stream = s; music_p.play())
	tw.tween_property(music_p, "volume_db", vol, 1.2)

static func _load(p: String) -> AudioStream:
	if _cache.has(p): return _cache[p]
	var s: AudioStream = load(p) if ResourceLoader.exists(p) else null
	_cache[p] = s; return s

static func play(name: String, pos = null, vol := 0.0, pitch_var := 0.08) -> void:
	if not root: return
	var s := _load(SFX + name + ".mp3")
	if not s: return
	var p: Node
	if pos == null:
		var a := AudioStreamPlayer.new(); a.stream = s; a.volume_db = vol; a.bus = "SFX"; p = a
		a.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
		root.add_child(a); a.play(); a.finished.connect(a.queue_free)
	else:
		var a := AudioStreamPlayer3D.new(); a.stream = s; a.volume_db = vol; a.unit_size = 12.0; a.max_distance = 160.0; a.bus = "SFX"
		a.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
		root.add_child(a); a.global_position = pos; a.play(); a.finished.connect(a.queue_free)

## Plays a voice line with subtitle. cooldown stops the same line spamming.
static func say(key: String, cooldown := 4.0) -> void:
	if not root or not LINES.has(key): return
	var now := Time.get_ticks_msec() / 1000.0
	if _last_line.has(key) and now - _last_line[key] < cooldown: return
	if voice.playing and voice.get_playback_position() < 0.6: return
	_last_line[key] = now
	var l: Array = LINES[key]
	var f: String = l[0].pick_random()
	var s := _load(VO + f)
	if s: voice.stream = s; voice.play()
	Hud.subtitle(l[1], l[2])
