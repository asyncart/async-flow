import Blueprints from "../../contracts/Blueprints.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// Claim owed fee payments that were not paid at the time of purchase due to capability receiver errors
transaction(currency: String) {

    prepare(acct: AuthAccount) {
        let senderClientRef: &Blueprints.BlueprintClient = acct.borrow<&Blueprints.BlueprintClient>(from: Blueprints.blueprintsClientStoragePath)
        if senderClientRef == nil {
            panic("Cannot borrow reference to blueprints client resource")
        }

        senderClientRef.claimPayout(
            currency: currency
        )
    }
}