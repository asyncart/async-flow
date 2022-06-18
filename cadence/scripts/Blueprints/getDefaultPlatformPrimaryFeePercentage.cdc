import Blueprints from "../../contracts/Blueprints.cdc"

// Default primary fee on Blueprints going to the platform
pub fun main(): UFix64 {
    return Blueprints.defaultPlatformPrimaryFeePercentage
}