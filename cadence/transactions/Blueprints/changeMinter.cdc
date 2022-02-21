import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to change the address of the minter
transaction(
    newMinterAddress: Address
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath)
        if senderPlatformRef == nil {
            panic("Coulf not borrow reference to blueprints Platform resource")
        }

        senderPlatformRef.changeMinter(newMinter: newMinterAddress)
    }
}