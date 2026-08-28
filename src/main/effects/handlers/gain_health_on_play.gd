extends CardEffect

func onEvent(event: GameplayEvent) -> void:
	var cardPlayedEvent = event as CardPlayedEvent
	if cardPlayedEvent == null or cardPlayedEvent.type != data.trigger:
		return
	
	if cardPlayedEvent.card != hostCard:
		return
	
	if data.target != "self":
		push_warning("Effect GainHealthOnPlay: target must be self.")
		return
	var parameters = data.parameters as GainHealthParameters
	if parameters == null:
		push_warning("Effect GainHealthOnPlay: invalid parameters.")
		return
	
	context.queueAction(ActionType.make(
		ActionType.MODIFY_STATS,
		hostCard,
		hostCard,
		ModifyStatsPayload.create("health", parameters.amount, data.id)
	))
