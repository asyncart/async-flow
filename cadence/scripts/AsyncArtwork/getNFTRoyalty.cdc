import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import MetadataViews from "../../contracts/MetadataViews.cdc"

pub fun main(user: Address, id: UInt64): MetadataViews.Royalties? {
    let account = getAccount(user)
    let collection = account.getCapability<&{MetadataViews.ResolverCollection}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
    let nft = collection.borrowViewResolver(id: id)
    let royalties = nft.resolveView(Type<MetadataViews.Royalties>()) as! MetadataViews.Royalties
    return royalties
}