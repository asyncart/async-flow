import Blueprints from "../../contracts/Blueprints.cdc"

pub fun main(blueprintID: UInt64): Blueprints.Blueprint{Blueprints.BlueprintPublic}? {
    return Blueprints.getBlueprint(blueprintID: blueprintID)
}