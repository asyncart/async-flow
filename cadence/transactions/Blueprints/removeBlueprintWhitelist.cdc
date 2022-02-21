import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to remove specific addresses from the blueprint whitelist
transaction(
    _blueprintID: UInt64,
    _whitelistRemovals: [Address]
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath)
        if senderMinterRef == nil {
            panic("Coulf not borrow reference to blueprints minter resource")
        }

        senderMinterRef.removeBlueprintWhitelist(
            _blueprintID: _blueprintID,
            _whitelistRemovals: _whitelistRemovals
        )
    }
}