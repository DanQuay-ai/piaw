class_name Game
## Difficulty: 0 Easy, 1 Normal, 2 Hard
static var difficulty := 1
static func enemy_accuracy() -> float: return [0.25, 0.45, 0.7][difficulty]
static func enemy_hp() -> float: return [40.0, 60.0, 90.0][difficulty]
static func enemy_sight() -> float: return [25.0, 35.0, 45.0][difficulty]
