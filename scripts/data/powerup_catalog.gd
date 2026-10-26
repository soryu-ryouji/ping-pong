class_name PowerupCatalog
extends Resource

@export var definitions: Array[PowerupDefinition] = []


func get_definition(powerup_id: StringName) -> PowerupDefinition:
    for definition in definitions:
        if definition.id == powerup_id:
            return definition
    return null


func definition_at(index: int) -> PowerupDefinition:
    if definitions.is_empty():
        return null
    return definitions[index % definitions.size()]
