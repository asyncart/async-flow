import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

pub fun main(user: Address, id: UInt64): &NonFungibleToken.NFT {
    let account = getAccount(user)
    let collection = account.getCapability<&{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
    return collection.borrowNFT(id: id)
}