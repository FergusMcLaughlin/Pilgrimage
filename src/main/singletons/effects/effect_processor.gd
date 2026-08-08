extends Node

var activeEffectsByCard: Dictionary = {}
var effectContext: EffectContext

func _ready() -> void:
	effectContext = EffectContext.new(self)
	GlobalSignalBus.actionResolved.connect(_onActionResolved)

func _onActionResolved(action: Dictionary, result: Variant) -> void:
	var actionType = action.get("type")
	if actionType in [ActionType.REMOVE_CARD, ActionType.DELETE_CARD]:
		var removeCard = action.get("target")
		if removeCard is Card:
			_deactivateCardEffects(removeCard)

	_dispatchEvent({
		"type": "action_resolved",
		"action": action,
		"result": result
	})

	match actionType:
		ActionType.REVEAL_CARD:
			if result is Card:
				_activateCardEffects(result)
				_dispatchEvent({
					"type": "on_play",
					"card": result
				})

func _activateCardEffects(card: Card) -> void:
	if card == null || card.data == null:
		return

	_deactivateCardEffects(card)
	var cardEffects: Array[CardEffect] = []

	for effectId in card.data.effects:
		if !EffectLibrary.hasEffectData(effectId):
			continue

		var effectData = EffectLibrary.getEffectData(effectId)
		var effect = _createEffect(card, effectData)
		if effect == null:
			continue

		cardEffects.append(effect)
		effect.onActivated()

	if !cardEffects.is_empty():
		activeEffectsByCard[card] = cardEffects

func _createEffect(card: Card, effectData: EffectData) -> CardEffect:
	if effectData.scriptPath.is_empty():
		push_warning("EffectProcessor: effect %s has no script path." % effectData.id)
		return null

	var effectScript = load(effectData.scriptPath)
	if effectScript == null:
		push_warning("EffectProcessor: could not load %s." % effectData.scriptPath)
		return null

	var effect = effectScript.new()
	if !(effect is CardEffect):
		push_warning("EffectProcessor: effect %s must extend CardEffect." % effectData.id)
		return null

	effect.setup(card, effectData, effectContext)
	return effect

func _dispatchEvent(event: Dictionary) -> void:
	for card in activeEffectsByCard.keys():
		if !is_instance_valid(card):
			activeEffectsByCard.erase(card)
			continue

		var cardEffects: Array = activeEffectsByCard[card]
		for effect in cardEffects:
			effect.onEvent(event)

func _deactivateCardEffects(card: Card) -> void:
	if !activeEffectsByCard.has(card):
		return

	var cardEffects: Array = activeEffectsByCard[card]
	for effect in cardEffects:
		effect.onDeactivated()

	activeEffectsByCard.erase(card)


func clearEffects() -> void:
	for card in activeEffectsByCard.keys():
		if is_instance_valid(card):
			_deactivateCardEffects(card)

	activeEffectsByCard.clear()
