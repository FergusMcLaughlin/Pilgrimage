extends Resource
class_name CursorSkin

const MAX_SIZE = 256

@export_group("Pointer")
@export var pointerSheet: Texture2D
@export var pointerFrameSize = Vector2i(64, 64)
@export var pointerFrameCount = 8
@export var pointerClickLocation = Vector2(6,4)

@export_group("Grabbable")
@export var grabbableSheet: Texture2D
@export var grabbableFrameSize = Vector2i(64, 64)
@export var grabbableFrameCount = 8
@export var grabbableClickLocation = Vector2(6,4)

@export_group("Grab")
@export var grabSheet: Texture2D
@export var grabFrameSize = Vector2i(64, 64)
@export var grabFrameCount = 8
@export var grabClickLocation = Vector2(6,4)

@export_group("Idle animation")
@export_range(0.0, 60.0) var idleFps = 10.0
@export_range(0.0, 2.0) var idleDelaySeconds = 0.15
@export_range(0.0, 20.0) var wakeDistance = 3.0

@export_group("Click animation")
@export var clickLastFrame = 4
@export_range(1.0, 60.0) var clickFps = 30.0
@export_range(0.0, 0.5) var clickMinHoldSeconds = 0.06

func validCursorSheet() -> bool:
	if pointerSheet == null:
		return false
	if grabbableSheet == null:
		return false
	if grabSheet == null:
		return false
	if clickLastFrame < 0 or clickLastFrame >= pointerFrameCount:
		return false
	return true
