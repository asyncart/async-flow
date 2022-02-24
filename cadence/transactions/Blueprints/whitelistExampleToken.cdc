import FungibleToken from "../../contracts/FungibleToken.cdc"
import ExampleToken from "../../contracts/ExampleToken.cdc"
import Blueprints from "../../contracts/Blueprints.cdc"

transaction() {

    prepare(acct: AuthAccount) {

        let asyncAccountVaultRef = acct.borrow<&ExampleToken.Vault>(from: /storage/exampleTokenVault) ?? panic("Async account does not have example token vault")
        let exTokenVault <- asyncAccountVaultRef.withdraw(amount: 0.0)

        let customReceiverCap = acct.getCapability<&{FungibleToken.Provider}>(/private/asyncArtworkExampleTokenProvider)
        if !customReceiverCap.check() {
            acct.link<&{FungibleToken.Provider}>(/private/asyncArtworkExampleTokenProvider, target: /storage/exampleTokenVault) ?? panic("Linking custom private provider cap unexpectedly failed")
        }

        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow platform resource from acct")
        senderPlatformRef.whitelistCurrency(
            currency: exTokenVault.getType().identifier,
            currencyPublicPath: /public/exampleTokenReceiver,
            // Unknown standard -- prefer custom path
            currencyPrivatePath: /private/asyncArtworkExampleTokenProvider,
            currencyStoragePath: /storage/exampleTokenVault,
            vault: <- exTokenVault
        )
    }
}