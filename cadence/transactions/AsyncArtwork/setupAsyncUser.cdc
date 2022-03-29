import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import MetadataViews from "../../contracts/MetadataViews.cdc"

transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) == nil {
            let collection <- AsyncArtwork.createEmptyCollection()
            acct.save(<- collection, to: AsyncArtwork.collectionStoragePath)

            acct.link<&AsyncArtwork.Collection{NonFungibleToken.Provider, AsyncArtwork.AsyncCollectionPrivate}>(
                AsyncArtwork.collectionPrivatePath,
                target: AsyncArtwork.collectionStoragePath
            )

            acct.link<&AsyncArtwork.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, AsyncArtwork.AsyncCollectionPublic, MetadataViews.ResolverCollection}>(
                AsyncArtwork.collectionPublicPath,
                target: AsyncArtwork.collectionStoragePath
            )
        }
    }
}