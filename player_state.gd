class_name PlayerState
extends RefCounted

var player_id: GameEnums.PlayerId
var display_name := ""
var hand_cards: Array[GiftCardData] = []
var action_tokens: Array[ActionTokenData] = []
var secret_cards: Array[GiftCardData] = []
var tradeoff_cards: Array[GiftCardData] = []
var sent_cards_by_geisha: Dictionary = {}
var controlled_geisha_ids: Array[StringName] = []
var charm_score := 0

func setup(id: GameEnums.PlayerId, name: String) -> PlayerState:
    player_id = id
    display_name = name
    for action_type in [GameEnums.ActionType.SECRET, GameEnums.ActionType.TRADEOFF, GameEnums.ActionType.GIFT, GameEnums.ActionType.COMPETITION]:
        action_tokens.append(ActionTokenData.new().setup(action_type, id))
    return self

func reset_round() -> void:
    hand_cards.clear()
    secret_cards.clear()
    tradeoff_cards.clear()
    sent_cards_by_geisha.clear()
    for token in action_tokens:
        token.reset_for_round()

func get_token(action_type: GameEnums.ActionType) -> ActionTokenData:
    for token in action_tokens:
        if token.action_type == action_type:
            return token
    return null
