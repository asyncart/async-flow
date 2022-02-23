import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to update something...is it needed?
transaction(
    newFeePercentage: UFix64
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow reference to Platform resource")
        senderPlatformRef.changeDefaultBlueprintSecondaryFeePercentage(newFee: newFeePercentage)
    }
}