import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

pub fun main(user: Address): [&NonFungibleToken.NFT] {
    let account = getAccount(user)
    let collection = account.getCapability<&{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
    let ids: [UInt64] = collection.getIDs()
    let nfts: [&NonFungibleToken.NFT] = []

    for id in ids {
        nfts.append(collection.borrowNFT(id: id))
    }

    return nfts
}