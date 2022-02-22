import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to override the whitelist of a given blueprint with a new one
transaction(
    _blueprintID: UInt64,
    _whitelistedAddresses: [Address]
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath) ?? panic("Could not borrow minter resource")

        senderMinterRef!.overrideBlueprintWhitelist(
            _blueprintID: UInt64,
            _whitelistedAddresses: [Address]
        )
    }
}