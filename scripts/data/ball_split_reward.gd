class_name BallSplitReward
extends UpgradeReward


func apply(world: Variant) -> String:
    var added: int = world.double_balls(color)
    return "BALLS ×2" if added > 0 else "MAX BALLS"
