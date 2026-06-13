extends Control
class_name Deck

var cardsInDeck: Array[String] = []
var _createCard := CreateCard.new()

func _ready() -> void:
	#deckVisuals.init(self)
	_refreshDeck()
	
func _refreshDeck() -> void:
	#deckVisuals.refresh()
	pass

func initialiseDeck(Ids: Array[String], shuffleAfter: bool = true) -> void:
	if Ids.is_empty():
		push_error("Deck: Cannot initialise with an empty id list.")
		return
	
	cardsInDeck = Ids.duplicate()
	if shuffleAfter:
		shuffleDeck()
	
	_refreshDeck()

func shuffleDeck() -> void:
	cardsInDeck.shuffle()
	GlobalSignalBus.emitDeckShuffled(self)

func getDeckSize() -> int:
	if cardsInDeck.is_empty():
		return 0
	
	return cardsInDeck.size()

func isEmpty() -> bool: 
	return cardsInDeck.is_empty()

func addCardToTop(cardId: String) -> void:
	if cardId.is_empty():
		push_warning("Deck: Tried to add a null card Id to a deck.")
		return
	
	cardsInDeck.push_front(cardId)
	_refreshDeck()

func addCardToBottom(cardId: String) -> void:
	if cardId.is_empty():
		push_warning("Deck: Tried to add a null card Id to a deck.")
		return
	
	cardsInDeck.push_back(cardId)
	_refreshDeck()

func drawCard() -> Card:
	if cardsInDeck.is_empty():
		push_warning("Deck : Cannot draw card from an empty deck.")
		return 
	
	var drawnCardId = cardsInDeck[0]
	cardsInDeck.pop_front()
	_refreshDeck()
	
	var drawnCard = _createCard.createCard(drawnCardId)
	
	if drawnCard == null:
		push_error("Deck : Cannot draw card.")
		return 
		
	GlobalSignalBus.emitCardDrawnFromDeck(drawnCard)
	_refreshDeck()
	return drawnCard

func drawCardById(Id: String) -> Card:
	if cardsInDeck.is_empty():
		push_warning("Deck : Cannot draw card from an empty deck.")
		GlobalSignalBus.emitDeckEmptied(self)
		_refreshDeck()
		return
	
	if Id.is_empty():
		push_warning("Deck: Cannot draw card from an empty deck. Deck id: %s" % Id)
		return
	
	var drawnCardId = Id
	cardsInDeck.erase(drawnCardId)
	_refreshDeck()
	
	var drawnCard = _createCard.createCard(drawnCardId)
	GlobalSignalBus.emitCardDrawnFromDeck(drawnCard)
	return drawnCard
