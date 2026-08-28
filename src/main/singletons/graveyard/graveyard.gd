extends Node

var entries: Array[GraveyardEntry] = []
var _nextEntryId = 1
var _createCard = CreateCard.new()

func buryCard(card: Card, source, cause: String, boardController: BoardController, sourceInstanceId: int = 0 ) -> GraveyardEntry:
	if card == null or card.data == null:
		return null
	
	if boardController == null or !boardController.removeCard(card):
		return null
	
	var entry = GraveyardEntry.new()
	entry.entryId = _nextEntryId
	entry.instanceId = card.instanceId
	entry.cardId = card.data.id
	entry.cause = cause
	entry.statSnapshot = CardStatSnapshot.fromCard(card)
	entry.sourceInstanceId = (
		source.instanceId
		if is_instance_valid(source) and source is Card
		else sourceInstanceId
	)
	_nextEntryId += 1
	
	var event = BoardHistory.recordEvent(CardRemovedHistoryEvent.fromGraveyardEntry(entry))
	entry.removedSequence = event.sequence
	entries.append(entry)
	
	card.queue_free()
	return entry

func getEntries() -> Array[GraveyardEntry]:
	return entries.duplicate()

func getEntry(entryId: int) -> GraveyardEntry:
	for entry in entries:
		if entry.entryId == entryId:
			return entry
	return null

func getCardIds():
	var cardIds: Array[String] = []
	for entry in entries:
		cardIds.append(entry.cardId)
	return cardIds

func deleteEntry(entryId: int, source = null) -> bool:
	var entry = getEntry(entryId)
	if entry == null:
		return false
	
	entries.erase(entry)
	BoardHistory.recordEvent(CardDeletedHistoryEvent.fromGraveyardEntry(entry, source))
	return true

func reviveCard(entryId: int, slot: CardSlot, boardController: BoardController) -> Card:
	var entry = getEntry(entryId)
	if entry == null or slot == null or slot.isOccupied():
		return null
	
	var card = _createCard.createCard(entry.cardId, entry.instanceId)
	if card == null:
		return null
	if !boardController.placeCard(card, slot):
		card.queue_free()
		return null
	
	entries.erase(entry)
	
	BoardHistory.recordEvent(CardRevivedHistoryEvent.fromGraveyardEntry(entry))
	
	return card

func reset() -> void:
	entries.clear()
	_nextEntryId = 1
