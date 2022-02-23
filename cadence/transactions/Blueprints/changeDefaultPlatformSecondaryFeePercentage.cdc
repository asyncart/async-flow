import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to update the default percentage the Async will receive as a fee-royalty on secondary sales
transaction(
    newFeePercentage: UFix64
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow reference to Platform resource")
        senderPlatformRef.changeDefaultPlatformSecondaryFeePercentage(newFee: newFeePercentage)
    }
}