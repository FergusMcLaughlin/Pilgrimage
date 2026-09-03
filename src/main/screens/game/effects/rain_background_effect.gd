extends Control
class_name RainBackgroundEffect

@export var dropCount := 600
@export var rainColour := Color(0.68, 0.78, 0.95, 0.36)
@export var minimumSpeed := 120.0
@export var maximumSpeed := 220.0
@export var minimumLength := 3
@export var maximumLength := 7

var drops: Array[Dictionary] = []
var randomNumberGenerator := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	randomNumberGenerator.randomize()
	resized.connect(_createDrops)
	call_deferred("_createDrops")

func _process(delta: float) -> void:
	for index in drops.size():
		var drop := drops[index]
		var dropPosition: Vector2 = drop["position"]
		dropPosition.y += drop["speed"] * delta

		if dropPosition.y > size.y:
			dropPosition = Vector2(
				randomNumberGenerator.randf_range(0.0, size.x),
				-drop["length"]
			)

		drop["position"] = dropPosition
		drops[index] = drop

	queue_redraw()

func _draw() -> void:
	for drop in drops:
		var startPosition: Vector2 = drop["position"]
		var endPosition := startPosition + Vector2(0.0, drop["length"])
		draw_line(startPosition, endPosition, rainColour, 1.0, false)

func _createDrops() -> void:
	if size == Vector2.ZERO:
		return

	drops.clear()

	for index in dropCount:
		drops.append({
			"position": Vector2(
				randomNumberGenerator.randf_range(0.0, size.x),
				randomNumberGenerator.randf_range(-size.y, size.y)
			),
			"speed": randomNumberGenerator.randf_range(minimumSpeed, maximumSpeed),
			"length": randomNumberGenerator.randi_range(minimumLength, maximumLength)
		})

	queue_redraw()
