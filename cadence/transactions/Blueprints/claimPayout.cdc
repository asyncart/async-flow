import Blueprints from "../../contracts/Blueprints.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// Claim owed fee payments that were not paid at the time of purchase due to capability receiver errors
transaction(currency: String) {

    prepare(acct: AuthAccount) {
        let senderClientRef: &Blueprints.BlueprintsClient = acct.borrow<&Blueprints.BlueprintsClient>(from: Blueprints.blueprintsClientStoragePath) ?? panic ("Could not borrow client resource")
        let currencyInfo: Blueprints.Paths = Blueprints.getCurrencyPaths()[currency] ?? panic("Blueprint's currency no longer supported!")
        let receiver: &FungibleToken.Vault = acct.borrow<&FungibleToken.Vault>(from: currencyInfo.storage) ?? panic("Could not find currency's vault in storage")

        let payout <- senderClientRef.claimPayout(
            currency: currency
        )

        receiver.deposit(from: <- payout)
    }
}