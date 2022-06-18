import Blueprints from "../../contracts/Blueprints.cdc"

// Returns if a currency is supported on Blueprints
pub fun main(currency: String): Bool {
    return Blueprints.isCurrencySupported(currency: currency)
}