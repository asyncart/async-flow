import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to update the default percentage the Async will receive as a fee-royalty on secondary sales
transaction(
    newFeePercentage: UFix64
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath)
        if senderPlatformRef == nil {
            panic("Coulf not borrow reference to blueprints Platform resource")
        }

        senderPlatformRef.changeDefaultPlatformSecondaryFeePercentage(newFee: newFeePercentage)
    }
}