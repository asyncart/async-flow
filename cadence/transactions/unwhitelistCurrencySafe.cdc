import Blueprints from "../contracts/Blueprints.cdc"
import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

// The platform can call this to safely unwhitelist a currency on the Blueprints and AsyncArtwork contract. See contract for safe vs. unsafe unwhitelisting
transaction(currency: String) {

    prepare(acct: AuthAccount) {

        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow platform resource from acct")
        senderPlatformRef.unwhitelistCurrencySafe(
            currency: currency
        )

        let admin: &AsyncArtwork.Admin = acct.borrow<&AsyncArtwork.Admin>(from: AsyncArtwork.adminStoragePath) ?? panic("Could not borrow AsyncArtwork admin resource from acct")
        admin.unwhitelistCurrencySafe(
            currency: currency
        )
    }
}