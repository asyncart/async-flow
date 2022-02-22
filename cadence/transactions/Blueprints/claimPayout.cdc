import Blueprints from "../../contracts/Blueprints.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// Claim owed fee payments that were not paid at the time of purchase due to capability receiver errors
transaction(currency: String) {

    prepare(acct: AuthAccount) {
        let senderClientRef: &Blueprints.BlueprintsClient = acct.borrow<&Blueprints.BlueprintsClient>(from: Blueprints.blueprintsClientStoragePath) ?? panic ("Could not borrow client resource")

        senderClientRef.claimPayout(
            currency: currency
        )
    }
}