import Blueprints from "../../contracts/Blueprints.cdc"

// grab the sale fees recipient on Blueprints
pub fun main(): Address {
    return Blueprints.asyncSaleFeesRecipient
}