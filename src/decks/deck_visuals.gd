#PLACE HOLDER REPLACE WITH ANIMATION PLAYER
extends Control
class_name DeckVisuals

const REVEAL_DURATION := 0.5
const REVEAL_START_ROTATION := PI / 2.0

@onready var deckCount: RichTextLabel = %DeckCount

var currentCount := 0
var journeyDeck: JourneyDeck

func init(journeyDeckReference: JourneyDeck) -> void:
	journeyDeck = journeyDeckReference
	refresh()

func refresh() -> void:
	_getCurrentCardCount()
	deckCount.text = str(currentCount)

func _getCurrentCardCount() -> int:
	currentCount = journeyDeck.getDeckSize()
	
	return currentCount

func animateCardToSlot(card: Card, slot: CardSlot) -> void:
	add_child(card)
	
	card.global_position = global_position
	card.rotation = REVEAL_START_ROTATION
	var targetRotation := (
		slot.cardAnchor.get_global_transform().get_rotation()
		- get_global_transform().get_rotation()
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(card, "global_position", slot.cardAnchor.global_position, REVEAL_DURATION)
	tween.parallel().tween_property(card, "rotation", targetRotation, REVEAL_DURATION)
	card.visuals.beginFlip()

	await tween.finished
	card.global_position = slot.cardAnchor.global_position
	card.rotation = targetRotation
