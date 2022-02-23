import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the platform to change the address of the minter
transaction(
    newMinterAddress: Address
) {

    prepare(acct: AuthAccount) {
        let senderPlatformRef: &Blueprints.Platform = acct.borrow<&Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not borrow platform resource from acct")
        senderPlatformRef.changeMinter(newMinter: newMinterAddress)
    }
}