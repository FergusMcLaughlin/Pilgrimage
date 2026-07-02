extends Control
class_name Deck

var deckCardBag := DeckCardBag.new()

func _ready() -> void:
	#deckVisuals.init(self)
	_refreshDeck()

func _refreshDeck() -> void:
	#deckVisuals.refresh()
	pass

func initialiseDeck(Ids: Array[String], shuffleAfter: bool = true) -> void:
	deckCardBag.initialiseDeck(Ids, shuffleAfter)
	_refreshDeck()

func shuffleDeck() -> void:
	deckCardBag.shuffleDeck()
	_refreshDeck()

func getDeckSize() -> int:
	return deckCardBag.getDeckSize()

func isEmpty() -> bool:
	return deckCardBag.isEmpty()

func addCardToTop(cardId: String) -> void:
	deckCardBag.addCardToTop(cardId)
	_refreshDeck()

func addCardToBottom(cardId: String) -> void:
	deckCardBag.addCardToBottom(cardId)
	_refreshDeck()

func drawCardId() -> String:
	var drawnCardId := deckCardBag.drawCardId()
	_refreshDeck()
	return drawnCardId

func drawCard() -> Card:
	var drawnCard := deckCardBag.drawCard()
	_refreshDeck()
	return drawnCard

func drawCardById(Id: String) -> Card:
	var drawnCard := deckCardBag.drawCardById(Id)
	_refreshDeck()
	return drawnCard
