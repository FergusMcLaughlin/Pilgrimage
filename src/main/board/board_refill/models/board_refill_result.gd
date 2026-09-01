extends RefCounted
class_name BoardRefillResult

var request: BoardRefillRequest
var plan: BoardShiftPlan
var completedSteps: Array[BoardShiftStep] = []
var revealedCard: Card
var succeeded = false
var skipped = false
var failureReason := ""
