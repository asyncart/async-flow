import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to lock the uri of a particular blueprint
transaction(
    blueprintID: UInt64
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow reference to Platform resource")
        senderPlatformRef.lockBlueprintTokenUri(blueprintID: blueprintID)
    }
}