class_name CardStateMachine

static func setCardState(card: Card, newCardState: int) -> void:
	var oldCardState = card.currentState
	if card.currentState == newCardState:
		return

	var input := card.input
	var shadow := card.shadow

	card.currentState = newCardState

	var interactable := true
	var shadowVisible := false
	var shadowStrong := false

	match newCardState:
		CardState.State.IN_DECK:
			interactable = true
			shadowVisible = false
			shadowStrong = false

		CardState.State.ON_BOARD:
			interactable = true
			shadowVisible = false
			shadowStrong = false

		CardState.State.BEING_DRAGGED:
			interactable = false
			shadowVisible = true
			shadowStrong = true

		CardState.State.IN_SLOT:
			interactable = true
			shadowVisible = false
			shadowStrong = false
		
		_:
			push_error("CardStateMachine: Unknown card state: %s" % str(newCardState))
			card.currentState = oldCardState
			return
	
	input.mouse_filter = Control.MOUSE_FILTER_STOP if interactable else Control.MOUSE_FILTER_IGNORE
	shadow.setVisible(shadowVisible, shadowStrong)

	GlobalSignalBus.emitCardStateChanged(card, oldCardState, newCardState)
