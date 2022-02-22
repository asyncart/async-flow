import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to set a given blueprint's state to sale started after being paused
transaction(
    _blueprintID: UInt64
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath) ?? panic("Could not borrow minter resource")

        senderMinterRef!.unpauseSale(
            _blueprintID: _blueprintID
        )
    }
}