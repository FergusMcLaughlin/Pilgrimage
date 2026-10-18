extends Node

var failures := 0
var passed := 0

func _ready() -> void:
	var factory := CreateCard.new()
	var terrain := factory.createCard("M_0012")
	add_child(terrain)
	_expect(terrain.data.name == "Roadside Remains" and terrain.data.type == "terrain", "Roadside Remains loads as terrain.")
	_expect(terrain.health == 0 and terrain.attack == 0, "Terrain has zero health and attack.")
	_expect(terrain.visuals.face.texture is AnimatedTexture and terrain.visuals.face.texture.frames == 12, "Terrain uses the twelve-frame DeadMan animation.")
	_expect(_statsHidden(terrain), "Face-down terrain hides both stats.")
	for i in range(3):
		await terrain.flipCard()
		_expect(terrain.visuals.isFaceUp() and terrain.visuals.nameLable.visible, "Revealed terrain keeps its name and artwork.")
		_expect(_statsHidden(terrain), "Revealed terrain never shows combat stats.")
		terrain.modifyStat("health", 2)
		terrain.modifyStat("attack", 1)
		_expect(_statsHidden(terrain), "Stat refresh cannot reveal terrain stats.")
		await terrain.flipCard()
		_expect(!terrain.visuals.isFaceUp() and _statsHidden(terrain), "Flipping terrain back keeps stats hidden.")

	var unit := factory.createCard("M_0001")
	var unitData := unit.data.duplicate() as CardData
	unitData.baseHealth = 0
	unitData.baseAttack = 0
	unit.setCardData(unitData)
	add_child(unit)
	_expect(_statsHidden(unit), "Face-down unit starts with hidden stats.")
	await unit.flipCard()
	_expect(unit.visuals.healthLable.visible and unit.visuals.attackLable.visible, "Face-up units show stats even when both are zero.")
	unit.modifyStat("health", 3)
	_expect(unit.visuals.healthLable.text == "3" and unit.visuals.healthLable.visible, "Normal unit stat updates stay visible.")
	unit.setCardData(terrain.data)
	_expect(_statsHidden(unit), "Replacing a visible card with terrain hides its stats.")
	unit.setCardData(unitData)
	_expect(unit.visuals.healthLable.visible and unit.visuals.attackLable.visible, "Replacing terrain with a unit restores visible stats.")
	await unit.flipCard()
	unit.modifyStat("attack", 2)
	_expect(_statsHidden(unit), "Refreshing a face-down unit does not reveal its stats.")
	terrain.queue_free()
	unit.queue_free()
	await get_tree().process_frame
	print("Terrain card visuals: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _statsHidden(card: Card) -> bool:
	return !card.visuals.healthLable.visible and !card.visuals.attackLable.visible

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
