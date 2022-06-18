import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

// Get AsyncArtwork NFT ids
pub fun main(user: Address): [UInt64] {
    let account = getAccount(user)
    let collection = account.getCapability<&{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
    return collection.getIDs()
}