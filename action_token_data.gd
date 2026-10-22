class_name ActionTokenData
extends Resource

@export var action_type: GameEnums.ActionType
@export var owner_id: GameEnums.PlayerId
@export var state: GameEnums.TokenState = GameEnums.TokenState.AVAILABLE

func setup(type: GameEnums.ActionType, player: GameEnums.PlayerId) -> ActionTokenData:
    action_type = type
    owner_id = player
    state = GameEnums.TokenState.AVAILABLE
    return self

func reset_for_round() -> void:
    state = GameEnums.TokenState.AVAILABLE

func mark_used() -> void:
    state = GameEnums.TokenState.USED

func is_available() -> bool:
    return state == GameEnums.TokenState.AVAILABLE
