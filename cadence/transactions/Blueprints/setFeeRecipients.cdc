import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to update the fee recipients and their percentages for a given blueprint
transaction(
    _blueprintID: UInt64,
    _primaryFeeRecipients: [Address],
    _primaryFeePercentages: [UFix64],
    _secondaryFeeRecipients: [Address],
    _secondaryFeePercentages: [UFix64]
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath) ?? panic("Could not borrow minter resource")

        senderMinterRef!.setFeeRecipients(
            _blueprintID: _blueprintID,
            _primaryFeeRecipients: _primaryFeeRecipients,
            _primaryFeePercentages: _primaryFeePercentages,
            _secondaryFeeRecipients: _secondaryFeeRecipients,
            _secondaryFeePercentages: _secondaryFeePercentages
        )
    }
}