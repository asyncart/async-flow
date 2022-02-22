import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to update the address that will receive Async's fee payouts
transaction(
    newFeeRecipientAddress: Address
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow platform resource")
        senderPlatformRef.setAsyncFeeRecipient(_asyncSalesFeeRecipient: newFeeRecipientAddress)
    }
}