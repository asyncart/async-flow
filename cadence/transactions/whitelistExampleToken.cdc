import FungibleToken from "../contracts/FungibleToken.cdc"
import ExampleToken from "../contracts/ExampleToken.cdc"
import Blueprints from "../contracts/Blueprints.cdc"
import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

transaction() {
    prepare(acct: AuthAccount) {
        let exampleTokenVault1 <- ExampleToken.createEmptyVault()

        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow Blueprints platform resource from acct")
        senderPlatformRef.whitelistCurrency(
            currency: exampleTokenVault1.getType().identifier,
            currencyPublicPath: /public/exampleTokenReceiver,
            // Unknown standard -- prefer custom path
            currencyPrivatePath: /private/asyncArtworkExampleTokenProvider,
            currencyStoragePath: /storage/exampleTokenVault,
            vault: <- exampleTokenVault1
        )

        let exampleTokenVault2 <- ExampleToken.createEmptyVault()

        let admin: &AsyncArtwork.Admin = acct.borrow<&AsyncArtwork.Admin>(from: AsyncArtwork.adminStoragePath) ?? panic("Could not borrow AsyncArtwork admin resource from acct")
        admin.whitelistCurrency(
            currency: exampleTokenVault2.getType().identifier,
            currencyPublicPath: /public/exampleTokenReceiver,
            // Unknown standard -- prefer custom path
            currencyPrivatePath: /private/asyncArtworkExampleTokenProvider,
            currencyStoragePath: /storage/exampleTokenVault,
            vault: <- exampleTokenVault2
        )
    }
}