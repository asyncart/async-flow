import Blueprints from "../contracts/Blueprints.cdc"
import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

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