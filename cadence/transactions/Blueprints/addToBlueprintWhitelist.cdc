import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to add new addresses to the whitelist of a given blueprint
transaction(
    _blueprintID: UInt64,
    _whitelistAdditions: [Address]
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath)
        if senderMinterRef == nil {
            panic("Coulf not borrow reference to blueprints minter resource")
        }

        senderMinterRef.addToBlueprintWhitelist(
            _blueprintID: _blueprintID,
            _whitelistAdditions: _whitelistAdditions
        )
    }
}