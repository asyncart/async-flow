import Blueprints from "../../contracts/Blueprints.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// Purchase a certain quantity of blueprint nfts and send them to a specific recipient
transaction(blueprintID: UInt64, quantity: UInt64, recipient: Address) {

    prepare(acct: AuthAccount) {
        let blueprint: Blueprints.Blueprint = Blueprints.getBlueprint(blueprintID: blueprintID)
        if blueprint == nil {
            panic("Blueprint being purchased does not exist!")
        }

        let currencyInfo: Blueprints.Paths = Blueprints.getCurrencyPaths()[blueprint!.currency]
        if currencyInfo == nil {
            panic("Blueprint currency is no longer supported!")
        }

        let paymentProviderRef: &{FungibleToken.Provider} = acct.borrow<&{FungibleToken.Provider}>(from: currencyInfo.storage) ?? panic("Could not borrow Vault resource")
        let payment: @FungibleToken.Vault = paymentProviderRef.withdraw(amount: blueprint!.price * UFix64(quantity))

        let senderClientRef: &Blueprints.BlueprintClient = acct.borrow<&Blueprints.BlueprintClient>(from: Blueprints.blueprintsClientStoragePath)
        if senderClientRef == nil {
            panic("Cannot borrow reference to blueprints client resource")
        }

        senderClientRef.purchaseBlueprints(
            blueprintID: blueprintID,
            quantity: quantity,
            payment: payment,
            nftRecipient: recipient
        )
    }
}