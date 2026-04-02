extends Control # possible mistake
class_name CardVisuals

const STAT_COLOUR_NORMAL = Color.BLACK
const STAT_COLOUR_BUFFED = Color.DARK_GREEN
const STAT_COLOUR_DEBUFFED = Color.DARK_RED

@onready var face: TextureRect = %CardFace
@onready var back: TextureRect = %CardBack
@onready var nameLable: RichTextLabel = %CardName
@onready var healthLable: RichTextLabel = %CardHealth
@onready var attackLable: RichTextLabel = %CardAttack


var card: Card
var isHovered := false
var isDragging := false
var scaleTween: Tween

var defaultZIndex := 0
var dragZIndex := 1000

func init(cardReference: Card):
	card = cardReference
	defaultZIndex = z_index

func refresh() -> void:
	nameLable.text = str(card.data.name)
	healthLable.text = str(card.health)
	attackLable.text = str(card.attack)

	_loadCardImage()
	_updateStatColours()

func _loadCardImage() -> void:
	var imagePath := "res://assets/images/cards/%s.png" % card.data.name
	var texture := load(imagePath)

	if texture:
		face.texture = texture
	else:
		push_error("Card Visuals: Cant load picture: " + imagePath)

func _updateStatColours() -> void:
	if card.data.type == "player":
		return
	
	attackLable.modulate = _getStatColour(card.attack, card.data.baseAttack)
	healthLable.modulate = _getStatColour(card.health, card.data.baseHealth)

func _getStatColour(current: int, base: int) -> Color:
	if current > base:
		return STAT_COLOUR_BUFFED
	elif current < base:
		return STAT_COLOUR_DEBUFFED
	return STAT_COLOUR_NORMAL

func flip() -> void: # shadow functionality is gone currently
	var flipTween = card.create_tween()

	flipTween.tween_property(self, "scale:x", 0.0, 0.15)
	flipTween.tween_callback(func(): _toggleCardVisibility())
	flipTween.tween_property(self, "scale:x", 1.0, 0.15)

	GlobalSignalBus.emitCardFlipped(card)

func _toggleCardVisibility() -> void:
	var componenets = [face, back, nameLable, healthLable, attackLable]
	for component in componenets:
		component.visible = !component.visible

func handleHovered(hovered: bool) -> void:
	if isHovered == hovered:
		return
	isHovered = hovered
	_updateScale()

func handleDragging(dragging: bool) -> void:
	if isDragging == dragging:
		return
	isDragging = dragging
	if isDragging:
		z_as_relative = false
		z_index = dragZIndex
	else:
		z_index = defaultZIndex
	_updateScale()

func _updateScale() -> void:
	if scaleTween:
		scaleTween.kill()
	
	var targetScale := Vector2.ONE
	
	if isDragging:
		targetScale = Vector2(1.10, 1.10)
	elif isHovered:
		targetScale = Vector2(1.05, 1.05)
	
	scaleTween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scaleTween.tween_property(self, "scale", targetScale, 0.12)
	
