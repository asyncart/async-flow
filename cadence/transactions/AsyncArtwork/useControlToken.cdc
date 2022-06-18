import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// Update the values on a control token 
transaction(
    id: UInt64, 
    leverIds: [UInt64], 
    newLeverValues: [Int64], 
    tip: UFix64
) {
    let collection: &AsyncArtwork.Collection
    let tipVault: @FungibleToken.Vault?

    prepare(acct: AuthAccount) {
        self.collection = acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) ?? panic("Could not borrow Collection resource")
        if tip > 0.0 {
            let vault = acct.borrow<&{FungibleToken.Provider}>(from: /storage/flowTokenVault) ?? panic("Flow Token vault does not exist")
            self.tipVault <- vault.withdraw(amount: tip)
        } else {
            self.tipVault <- nil
        }
    }

    execute {
        self.collection.useControlToken(
            id: id,
            leverIds: leverIds,
            newLeverValues: newLeverValues,
            renderingTip: <- self.tipVault
        )
    }
}