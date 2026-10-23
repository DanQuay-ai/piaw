class_name Missions
## Mission data: map layout + a list of stages.
## Stage types: kill (spawn & clear), waves (defend: groups attack a point), capture (stand on the flag).
const R := "british_redcoat"
const W := "west_india_regt"
const D := "dutch_soldier"

static func get_def(id: String) -> Dictionary:
	match id:
		"asameni": return {
			"title": "THE KEYS OF OSU", "year": "1693",
			"map": {"coast": true, "sea_z": -100.0, "fort": Vector2(0, -78), "fort_hill": 0.0, "fort_style": "castle", "village": Vector2(48, -20), "spawn": Vector2(0, 95)},
			"names": {D: "Danish soldier"}, "narr": "narr_asameni",
			"stages": [
				{"type": "reach", "pos": Vector3(0, 0, -50), "radius": 6.0, "text": "Osu, 1693. Asameni's Akwamu pose as traders. Walk up to Christiansborg Castle without raising the alarm."},
				{"type": "kill", "text": "The gate is open. Seize the castle: cut down the Danish garrison in the courtyard.", "cannon": false,
					"posts": [[Vector3(-8, 0, 4), D], [Vector3(8, 0, 4), D], [Vector3(0, 0, -6), D], [Vector3(-12, 0, -10), D], [Vector3(12, 0, -10), D], [Vector3(-4, 0, 10), D], [Vector3(4, 0, 10), D], [Vector3(0, 0, 0), D]]},
				{"type": "capture", "text": "The castle is Akwamu's. Raise the colours and take the keys of Osu."},
			]}
		"canoe": return {
			"title": "JOHN CANOE'S FORT", "year": "1711",
			"map": {"coast": true, "sea_z": -112.0, "fort": Vector2(0, -60), "fort_hill": 9.0, "fort_style": "hill", "village": Vector2(55, 10), "spawn": Vector2(-7, -64), "fort_yaw": 3.14159},
			"names": {D: "Dutch soldier"}, "narr": "narr_canoe", "start_in_fort": true,
			"stages": [
				{"type": "waves", "text": "Pokesu, 1711. John Canoe holds Groß Friedrichsburg. The Dutch are landing on the beach. Hold the walls.", "target": "fort",
					"waves": [[[Vector3(-20, 0, -100), D], [Vector3(-10, 0, -102), D], [Vector3(0, 0, -100), D], [Vector3(10, 0, -102), D]],
						[[Vector3(-30, 0, -98), D], [Vector3(-15, 0, -100), D], [Vector3(15, 0, -100), D], [Vector3(30, 0, -98), D], [Vector3(0, 0, -103), D]],
						[[Vector3(-35, 0, -95), D], [Vector3(-20, 0, -100), D], [Vector3(-5, 0, -102), D], [Vector3(5, 0, -102), D], [Vector3(20, 0, -100), D], [Vector3(35, 0, -95), D]]]},
				{"type": "capture", "text": "The Dutch fall back to their boats. Raise John Canoe's flag over the fort."},
			]}
		"amoaful": return {
			"title": "AMOAFUL", "year": "1874",
			"map": {"has_fort": false, "village": Vector2(10, -70), "spawn": Vector2(0, 95)},
			"names": {}, "narr": "narr_amoaful",
			"stages": [
				{"type": "kill", "text": "Amoaful, 1874. Wolseley's column pushes for Kumasi. Bleed it in the bush before it reaches the town.",
					"column": [R, W, R, R, W, R, W, R]},
				{"type": "waves", "text": "They regrouped. Defend the town of Amoaful.", "target": "village",
					"waves": [[[Vector3(-30, 0, 20), R], [Vector3(-20, 0, 25), W], [Vector3(30, 0, 20), R], [Vector3(20, 0, 25), W]],
						[[Vector3(0, 0, 30), R], [Vector3(-10, 0, 34), R], [Vector3(10, 0, 34), W], [Vector3(-25, 0, 10), W], [Vector3(25, 0, 10), R]]]},
			]}
		"golden_stool": return {
			"title": "THE GOLDEN STOOL", "year": "1900",
			"map": {"fort": Vector2(0, -110), "fort_hill": 12.0, "village": Vector2(52, -40), "spawn": Vector2(-10, -70)},
			"names": {}, "narr": "narr_golden_stool",
			"stages": [
				{"type": "kill", "text": "Kumasi, 1900. Yaa Asantewaa besieges the British fort. Clear the stockade guards on the slope.",
					"posts_abs": [[Vector3(-18, 0, -84), W], [Vector3(15, 0, -86), W], [Vector3(0, 0, -80), R], [Vector3(-30, 0, -95), W]]},
				{"type": "waves", "text": "A relief column is coming up the road. Stop it before it reaches the fort.", "target": "road",
					"waves": [[[Vector3(0, 0, 60), R], [Vector3(-4, 0, 64), W], [Vector3(4, 0, 64), W], [Vector3(0, 0, 68), R]],
						[[Vector3(0, 0, 50), R], [Vector3(-4, 0, 54), R], [Vector3(4, 0, 54), W], [Vector3(-4, 0, 58), W], [Vector3(4, 0, 58), R], [Vector3(0, 0, 62), R]]]},
				{"type": "end", "text": "The relief column is broken. The siege holds."},
			]}
	return {
		"title": "NSAMANKOW", "year": "1824",
		"map": {"fort": Vector2(0, -110), "fort_hill": 15.0, "village": Vector2(52, -40), "spawn": Vector2(0, 95)},
		"names": {}, "narr": "narr_intro",
		"stages": [
			{"type": "kill", "text": "Nsamankow, 1824. A British column marches up the red road. Hide in the bush and break it.", "column": [R, W, R, W, R, R]},
			{"type": "kill", "text": "Take the hill fort. Silence the cannon crews and clear the walls.", "cannon": true,
				"posts": [[Vector3(-4, 3.2, 9), R], [Vector3(4, 3.2, 9), W], [Vector3(-8, 0.1, 4), R], [Vector3(8, 0.1, -4), W], [Vector3(-15, 7.1, -15), R], [Vector3(15, 7.1, 15), R]]},
			{"type": "capture", "text": "The walls are yours. Stand at the flag to raise the Asante colours."},
		]}
