extends CardEffect

func onEvent(event: Dictionary) -> void:
	if event.get("type") != data.trigger:
		return

	if event.get("card") != hostCard:
		return

	if data.target != "self":
		push_warning("Effect GainHealthOnPlay: target must be self.")
		return
	var amount = data.parameters.get("amount")
	if amount is float && amount == floorf(amount):
		amount = int(amount)
	if !(amount is int) || amount <= 0:
		push_warning("Effect GainHealthOnPlay: amount must be positive.")
		return

	context.queueAction(ActionType.make(
		ActionType.MODIFY_STATS,
		hostCard,
		hostCard,
		{"stat": "health", "amount": amount},
	))
