import Blueprints from "../../contracts/Blueprints.cdc"

transaction(currency: String) {

    prepare(acct: AuthAccount) {

        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow platform resource from acct")
        senderPlatformRef.unwhitelistCurrency(
            currency: currency
        )
    }
}