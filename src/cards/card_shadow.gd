extends Node2D
class_name CardShadow

const SHADOW_OPACITY_NORMAL := 0.3
const SHADOW_OPACITY_STRONG := 0.4
const SHADOW_OFFSET_DEFAULT := Vector2(5, 5)

@onready var shadowSprite: TextureRect = $Shadow
@onready var back: TextureRect = $"../CardVisuals/CardBack"

var card: Card

func init(cardReference: Card) -> void:
	card = cardReference

func refresh() -> void:
	_syncTexture()
	_applyNormalShadow()
	shadowSprite.visible = false

func setVisible(isVisible: bool, isDragging: bool = false, isFocused: bool = false) -> void:
	shadowSprite.visible = isVisible
	if !isVisible:
		return
	
	if isDragging or isFocused:
		_applyStrongShadow()
	else:
		_applyNormalShadow()

func _syncTexture() -> void: # maybe remove this
	if shadowSprite.texture == null and back != null:
		push_warning("Card Shadow: No shadow texture found, using card back texture.")
		shadowSprite.texture = back.texture

func _applyNormalShadow() -> void:
	shadowSprite.position = SHADOW_OFFSET_DEFAULT
	shadowSprite.modulate.a = SHADOW_OPACITY_NORMAL
	shadowSprite.scale = back.scale * 1.05

func _applyStrongShadow() -> void:
	shadowSprite.position = SHADOW_OFFSET_DEFAULT * 1.6
	shadowSprite.modulate.a = SHADOW_OPACITY_STRONG
	shadowSprite.scale = back.scale * 0.95
