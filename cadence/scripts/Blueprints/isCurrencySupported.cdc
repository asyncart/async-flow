import Blueprints from "../../contracts/Blueprints.cdc"

pub fun main(currency: String): Bool {
    return Blueprints.isCurrencySupported(currency: currency)
}