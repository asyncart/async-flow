import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

pub fun main(user: Address): {UInt64: UInt64} {
    let account = getAccount(user)
    let collection = account.getCapability<&{AsyncArtwork.AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
    return collection.getControlUpdate()
}