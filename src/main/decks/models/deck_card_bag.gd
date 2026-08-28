class_name DeckCardBag
extends RefCounted

var cards: Array[String] = []

var _createCard := CreateCard.new()

func initialiseDeck(Ids: Array[String], shuffleAfter: bool = true) -> void:
	if Ids.is_empty():
		push_error("DeckData: Cannot initialise with an empty id list.")
		return
	
	cards = Ids.duplicate()
	if shuffleAfter:
		shuffleDeck()

func shuffleDeck() -> void:
	cards.shuffle()
	GlobalSignalBus.emitDeckShuffled(self)

func getDeckSize() -> int:
	if cards.is_empty():
		return 0
	
	return cards.size()

func isEmpty() -> bool:
	return cards.is_empty()

func addCardToTop(cardId: String) -> void:
	if cardId.is_empty():
		push_warning("DeckData: Tried to add a null card Id to a deck.")
		return
	
	cards.push_front(cardId)

func addCardToBottom(cardId: String) -> void:
	if cardId.is_empty():
		push_warning("DeckData: Tried to add a null card Id to a deck.")
		return
	
	cards.push_back(cardId)

func drawCardId() -> String:
	if cards.is_empty():
		push_warning("DeckData: Cannot draw card from an empty deck.")
		GlobalSignalBus.emitDeckEmptied(self)
		return ""
	
	var drawnCardId := cards[0]
	cards.pop_front()
	
	if cards.is_empty():
		GlobalSignalBus.emitDeckEmptied(self)
	
	return drawnCardId

func drawCard() -> Card:
	var drawnCardId := drawCardId()
	
	if drawnCardId == "":
		return null
	
	var drawnCard := _createCard.createCard(drawnCardId)
	
	if drawnCard == null:
		push_error("DeckData: Cannot create card for id %s." % drawnCardId)
		return null
	
	GlobalSignalBus.emitCardDrawnFromDeck(drawnCard)
	return drawnCard

func drawCardById(Id: String) -> Card:
	if cards.is_empty():
		push_warning("DeckData: Cannot draw card from an empty deck.")
		GlobalSignalBus.emitDeckEmptied(self)
		return null
	
	if Id.is_empty():
		push_warning("DeckData: Cannot draw card with an empty id.")
		return null
	
	if Id not in cards:
		push_warning("DeckData: Id %s is not in the deck." % Id)
		return null
	
	cards.erase(Id)
	
	if cards.is_empty():
		GlobalSignalBus.emitDeckEmptied(self)
	
	var drawnCard := _createCard.createCard(Id)
	
	if drawnCard == null:
		push_error("DeckData: Cannot create card for id %s." % Id)
		return null
	
	GlobalSignalBus.emitCardDrawnFromDeck(drawnCard)
	return drawnCard
