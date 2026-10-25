extends CardEffect

func onEvent(event: GameplayEvent) -> void:
	if !is_instance_valid(hostCard) or hostCard.is_queued_for_deletion():
		return
	var played = event as CardPlayedEvent
	var resolved = event as ActionResolvedEvent
	if played == null and (resolved == null or resolved.action == null or resolved.action.type != ActionType.REMOVE_CARD):
		return
	if data.target != "self":
		push_warning("Effect Stew Feind: target must be self.")
		return
	var parameters = data.parameters as StewFeindParameters
	if parameters == null:
		push_warning("Effect Stew Feind: invalid parameters.")
		return

	var amount := 0
	if played != null:
		if !is_instance_valid(played.card) or played.card.data == null:
			return
		if played.card.data.id == parameters.watchedCardId:
			amount = parameters.amount
	else:
		var entry = resolved.result as GraveyardEntry
		if entry != null and entry.cardId == parameters.watchedCardId and entry.instanceId != hostCard.instanceId:
			amount = -parameters.amount

	if amount == 0:
		return
	var action = ActionType.make(
		ActionType.MODIFY_STATS,
		hostCard,
		hostCard,
		ModifyStatsPayload.create("health", amount, data.id)
	)
	context.queueAction(action)
