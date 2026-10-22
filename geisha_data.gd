class_name GeishaData
extends Resource

@export var geisha_id: StringName
@export var display_name := ""
@export var charm_value := 0
@export var target_gift_type: StringName
@export var owner: GameEnums.GeishaOwner = GameEnums.GeishaOwner.NEUTRAL

func setup(id: StringName, name: String, charm: int, gift_type: StringName) -> GeishaData:
    geisha_id = id
    display_name = name
    charm_value = charm
    target_gift_type = gift_type
    owner = GameEnums.GeishaOwner.NEUTRAL
    return self
