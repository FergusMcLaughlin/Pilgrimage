extends TextureRect
class_name CardShadow

const SHADOW_OPACITY_NORMAL := 0.3
const SHADOW_OPACITY_STRONG := 0.4
const SHADOW_OFFSET_DEFAULT := Vector2(20, 20)
const SHADOW_SCALE_NORMAL := 1.05
const SHADOW_SCALE_STRONG := 0.95

var card: Card
var back: TextureRect

func init(cardReference: Card, backReference: TextureRect) -> void:
	card = cardReference
	back = backReference

func refresh() -> void:
	_syncTexture()
	setVisible(false,false)

func setVisible(isVisible: bool, isStrong: bool) -> void:
	visible = isVisible
	if !isVisible:
		return
	_applyShadow(isStrong)

func _syncTexture() -> void: # maybe remove this
	if self.texture == null and back != null:
		push_warning("Card Shadow: No shadow texture found, using card back texture.")
		self.texture = back.texture

func _applyShadow(strong: bool) -> void:
	position = SHADOW_OFFSET_DEFAULT * 1.6
	modulate = Color(0, 0, 0, SHADOW_OPACITY_STRONG if strong else SHADOW_OPACITY_NORMAL)
	if back != null:
		scale = back.scale * (SHADOW_SCALE_STRONG if strong else SHADOW_SCALE_NORMAL)
