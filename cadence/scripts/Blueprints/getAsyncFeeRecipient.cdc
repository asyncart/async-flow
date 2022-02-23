import Blueprints from "../../contracts/Blueprints.cdc"

pub fun main(): Address {
    return Blueprints.asyncSaleFeesRecipient
}