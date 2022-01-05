import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

transaction() {
    prepare(acct: AuthAccount) {
        acct.link<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, AsyncArtwork.AsyncCollectionPublic}>(
            AsyncArtwork.collectionPublicPath,
            target: AsyncArtwork.collectionStoragePath
        )
    }
}