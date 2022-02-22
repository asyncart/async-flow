import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to update the parameters of a blueprint
transaction(
    _blueprintID: UInt64,
    _price: UFix64,
    _mintAmountArtist: UInt64,
    _mintAmountPlatform: UInt64,
    _newSaleState: UInt8,
    _newMaxPurchaseAmount: UInt64 
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath) ?? panic("Could not borrow minter resource")

        let newBlueprintState: Blueprints.SaleState = Blueprints.SaleState(rawValue: _newSaleState) ?? panic("Invalid sale state provided")

        senderMinterRef!.updateBlueprintSettings(
            _blueprintID: _blueprintID,
            _price: _price,
            _mintAmountArtist: _mintAmountArtist,
            _mintAmountPlatform: _mintAmountPlatform,
            _newSaleState: newBlueprintState,
            _newMaxPurchaseAmount: _newMaxPurchaseAmount
        )
    }
}