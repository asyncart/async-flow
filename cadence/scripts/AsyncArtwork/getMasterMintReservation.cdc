import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Get details about what AsyncArtwork master tokens a user can mint
pub fun main(user: Address): {UInt64: UInt64} {
    let account = getAccount(user)
    let collection = account.getCapability<&AsyncArtwork.Collection{AsyncArtwork.AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
    return collection.getMasterMintReservation()
}