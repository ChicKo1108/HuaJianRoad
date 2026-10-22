class_name GiftCardData
extends Resource

@export var card_id: StringName
@export var gift_type: StringName
@export var target_geisha_id: StringName
@export var is_hidden := false
@export var location: StringName = &"deck"

func setup(id: StringName, type: StringName, geisha_id: StringName) -> GiftCardData:
    card_id = id
    gift_type = type
    target_geisha_id = geisha_id
    return self
