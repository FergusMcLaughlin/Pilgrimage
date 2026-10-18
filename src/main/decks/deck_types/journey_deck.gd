extends Control
class_name JourneyDeck

@export var boardController: BoardController
@export var slotGrid: SlotGrid

@onready var deckVisuals: DeckVisuals = %DeckVisuals
@onready var deckImage: TextureRect = %DeckImage

var journeyDeckCardBag := DeckCardBag.new()
var pendingRevealRequests := 0
var isProcessingRevealQueue := false

const JOURNEY_DECK_PRESET_CARDS: Array[String] = [
	"M_0001",
	"M_0002",
	"M_0003",
	"M_0004",
	"M_0005",
	"M_0006",
	"M_0007",
	"M_0008",
	"M_0009",
	"M_0010",
	"M_0011",
	"M_0001",
	"M_0002",
	"M_0003",
	"M_0004",
	"M_0005",
	"M_0006",
	"M_0007",
	"M_0008",
	"M_0009",
	"M_0010",
	"M_0001",
	"M_0002",
	"M_0003",
	"M_0004",
	"M_0005",
	"M_0006",
	"M_0007",
	"M_0008",
	"M_0009",
	"M_0010",
]

const JOURNEY_DECK_COPIES := 3
const ROADSIDE_REMAINS_ID := "M_0012"
const ROADSIDE_REMAINS_EXTRA_COPIES := 9

func initialiseJourneyDeck(shuffleAfter: bool = true) -> void:
	var cardIds: Array[String] = []
	for _copy in range(JOURNEY_DECK_COPIES):
		cardIds.append_array(JOURNEY_DECK_PRESET_CARDS)
	for _copy in range(ROADSIDE_REMAINS_EXTRA_COPIES):
		cardIds.append(ROADSIDE_REMAINS_ID)
	journeyDeckCardBag.initialiseDeck(cardIds, shuffleAfter)
	journeyDeckCardBag.addCardToTop(ROADSIDE_REMAINS_ID)
	deckVisuals.refresh()

func _ready() -> void:
	deckVisuals.init(self)
	#added for testing: manual deck clicks are connected by card_test_scene only.

func getDeckSize() -> int:
	return journeyDeckCardBag.getDeckSize()

func isEmpty() -> bool:
	return journeyDeckCardBag.isEmpty()

func revealTopCard(slot: CardSlot) -> Card:
	if boardController == null:
		push_error("JourneyDeck: BoardController has not been assigned.")
		return null
	
	if slot == null or slot.isOccupied():
		return null
	
	var cardToPlace := journeyDeckCardBag.drawCard()
	if cardToPlace == null:
		return null
	
	await deckVisuals.animateCardToSlot(cardToPlace, slot)
	
	if not boardController.placeCard(cardToPlace, slot):
		journeyDeckCardBag.addCardToTop(cardToPlace.data.id)
		cardToPlace.queue_free()
		return null
	
	deckVisuals.refresh()
	return cardToPlace

func _requestRevealAtSlot(slot: CardSlot) -> Card:
	if slot == null or slot.isOccupied():
		return null
	
	var revealAction = ActionType.make(
		ActionType.REVEAL_CARD,
		self,
		slot,
		RevealCardPayload.create("deck_reveal")
	)
	
	if !ActionQueue.enqueueAction(revealAction):
		return null
	
	var result = await ActionQueue.waitForActionToResolve(revealAction)
	return result as Card

func fillEmptySlots(grid: SlotGrid) -> void:
	if grid == null:
		push_error("JourneyDeck: Cannot fill slots without a SlotGrid.")
		return
	
	for slot in grid.getEmptySlots():
		if isEmpty():
			return
	
		var revealedCard = await _requestRevealAtSlot(slot)
		if revealedCard == null:
			return

func revealToNextEmptySlot() -> Card:
	if slotGrid == null:
		push_error("JourneyDeck: SlotGrid has not been assigned.")
		return null
	
	var emptySlots := slotGrid.getEmptySlots()
	if emptySlots.is_empty():
		return null
	
	return await _requestRevealAtSlot(emptySlots[0])

func queueRevealToNextEmptySlot() -> void:
	pendingRevealRequests += 1
	
	if not isProcessingRevealQueue:
		_processRevealQueue()

func _processRevealQueue() -> void:
	isProcessingRevealQueue = true
	
	while pendingRevealRequests > 0:
		pendingRevealRequests -= 1
	
		if isEmpty():
			break
	
		var revealedCard := await revealToNextEmptySlot()
		if revealedCard == null:
			break
	
	pendingRevealRequests = 0
	isProcessingRevealQueue = false
