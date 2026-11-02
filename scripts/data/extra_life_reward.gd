class_name ExtraLifeReward
extends UpgradeReward

@export var amount := 1


func apply(world: Variant) -> String:
    world.lives += amount
    return "+%d LIFE" % amount
