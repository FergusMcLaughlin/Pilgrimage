extends Node
class_name BoardController

@export var slotGridPath: NodePath
@onready var grid: SlotGrid = get_node(slotGridPath)

func _ready() -> void:
	add_to_group("boardController")

func placeCard(card: Card, slot: CardSlot) -> bool:
	if card == null:
		return false
	
	if slot == null:
		return false
		
	if !slot.canAcceptCard(card):
		return false
	
	var cardPlaced = slot.setCard(card)
	
	if cardPlaced:
		GlobalSignalBus.emitBoardStateChanged()
	
	return cardPlaced

func moveCard(card: Card, destinationSlot: CardSlot) -> bool:
	if card == null:
		return false
	
	if destinationSlot == null:
		return false
	
	if !destinationSlot.canAcceptCard(card):
		return false
	
	var startSlot = getSlotCardIsIn(card)
	
	if startSlot == null:
		return false
	
	startSlot.clearSlot()
	
	var cardPlaced = destinationSlot.setCard(card)
	
	if cardPlaced:
		GlobalSignalBus.emitBoardStateChanged()
	else:
		startSlot.setCard(card)
	
	return cardPlaced

func clearBoard() -> void:
	if grid == null:
		return
	
	for slot in grid.getOccupiedSlots():
		slot.clearSlot()
	
	GlobalSignalBus.emitBoardStateChanged()

func removeCard(card: Card) -> bool:
	if card == null:
		return false
	
	var slot := getSlotCardIsIn(card)
	if slot == null:
		return false
	
	slot.clearSlot()
	GlobalSignalBus.emitBoardStateChanged()
	return true

func getSlotCardIsIn(card: Card) -> CardSlot:
	if card == null || grid == null:
		return null
	
	for slot in grid.getOccupiedSlots():
		if slot.currentCard == card:
			return slot
			
	return null
