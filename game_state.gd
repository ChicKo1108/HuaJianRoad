class_name GameState
extends RefCounted

var phase: GameEnums.GamePhase = GameEnums.GamePhase.SETUP
var round_number := 0
var active_player: GameEnums.PlayerId = GameEnums.PlayerId.PLAYER_ONE
var starting_player: GameEnums.PlayerId = GameEnums.PlayerId.PLAYER_ONE
var actions_completed := {GameEnums.PlayerId.PLAYER_ONE: 0, GameEnums.PlayerId.PLAYER_TWO: 0}
var deck: Array[GiftCardData] = []
var removed_card: GiftCardData
var geishas: Array[GeishaData] = []
var players := {}
var winner: GameEnums.PlayerId = -1

func initialize() -> void:
    players[GameEnums.PlayerId.PLAYER_ONE] = PlayerState.new().setup(GameEnums.PlayerId.PLAYER_ONE, "玩家 1")
    players[GameEnums.PlayerId.PLAYER_TWO] = PlayerState.new().setup(GameEnums.PlayerId.PLAYER_TWO, "玩家 2")
    phase = GameEnums.GamePhase.SETUP

func begin_round() -> void:
    round_number += 1
    phase = GameEnums.GamePhase.ROUND_DEAL
    actions_completed[GameEnums.PlayerId.PLAYER_ONE] = 0
    actions_completed[GameEnums.PlayerId.PLAYER_TWO] = 0
    for player in players.values():
        player.reset_round()
    active_player = starting_player

func get_controlled_geisha_count(id: GameEnums.PlayerId) -> int:
    var count := 0
    for geisha in geishas:
        if geisha.owner == id + 1:
            count += 1
    return count

func get_charm_score(id: GameEnums.PlayerId) -> int:
    var score := 0
    for geisha in geishas:
        if geisha.owner == id + 1:
            score += geisha.charm_value
    return score

func has_won(id: GameEnums.PlayerId) -> bool:
    return get_controlled_geisha_count(id) >= 4 or get_charm_score(id) >= 11
