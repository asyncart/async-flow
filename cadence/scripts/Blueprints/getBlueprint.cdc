import Blueprints from "../../contracts/Blueprints.cdc"

// Get a Blueprint
pub fun main(blueprintID: UInt64): Blueprints.Blueprint{Blueprints.BlueprintPublic}? {
    return Blueprints.getBlueprint(blueprintID: blueprintID)
}