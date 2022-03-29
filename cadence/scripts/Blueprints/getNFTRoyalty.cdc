import Blueprints from "../../contracts/Blueprints.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import MetadataViews from "../../contracts/MetadataViews.cdc"
import Royalties from "../../contracts/Royalties.cdc"

pub fun main(user: Address, id: UInt64): String? {
    let account = getAccount(user)
    let collection = account.getCapability<&{MetadataViews.ResolverCollection}>(Blueprints.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
    let nft = collection.borrowViewResolver(id: id)
    let royaltyView = nft.resolveView(Type<{Royalties.Royalty}>()) as! AnyStruct{Royalties.Royalty}
    return royaltyView.displayRoyalty()
}