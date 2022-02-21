import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to set a given blueprint's state to sale started
transaction(
    _blueprintID: UInt64
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath)
        if senderMinterRef == nil {
            panic("Coulf not borrow reference to blueprints minter resource")
        }

        senderMinterRef.beginSale(
            _blueprintID: _blueprintID
        )
    }
}