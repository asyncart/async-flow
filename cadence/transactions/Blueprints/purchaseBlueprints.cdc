import Blueprints from "../../contracts/Blueprints.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// Purchase a certain quantity of blueprint nfts and send them to a specific recipient
transaction(blueprintID: UInt64, quantity: UInt64, recipient: Address) {

    prepare(acct: AuthAccount) {
        let blueprint: Blueprints.Blueprint{Blueprints.BlueprintPublic} = Blueprints.getBlueprint(blueprintID: blueprintID) ?? panic("Blueprint being purchased does not exist")
        let currencyInfo: Blueprints.Paths = Blueprints.getCurrencyPaths()[blueprint!.currency] ?? panic("Blueprint's currency no longer supported!")
        let paymentProviderRef: &{FungibleToken.Provider} = acct.borrow<&{FungibleToken.Provider}>(from: currencyInfo.storage) ?? panic("Could not borrow Vault resource")
        let payment: @FungibleToken.Vault <- paymentProviderRef.withdraw(amount: blueprint!.price * UFix64(quantity))
        let senderClientRef: &Blueprints.BlueprintsClient = acct.borrow<&Blueprints.BlueprintsClient>(from: Blueprints.blueprintsClientStoragePath) ?? panic("Could not borrow client resource")

        senderClientRef.purchaseBlueprints(
            blueprintID: blueprintID,
            quantity: quantity,
            payment: <-payment,
            nftRecipient: recipient
        )
    }
}