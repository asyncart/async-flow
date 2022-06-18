import Blueprints from "../../contracts/Blueprints.cdc"

// Get the default secondary sale percentage going to the platform on Blueprints
pub fun main(): UFix64 {
    return Blueprints.defaultBlueprintSecondarySalePercentage
}