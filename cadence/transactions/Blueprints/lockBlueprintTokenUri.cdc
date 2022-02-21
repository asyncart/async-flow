import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to lock the uri of a particular blueprint
transaction(
    blueprintID: UInt64
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath)
        if senderPlatformRef == nil {
            panic("Coulf not borrow reference to blueprints Platform resource")
        }

        senderPlatformRef.lockBlueprintTokenUri(blueprintID: blueprintID)
    }
}