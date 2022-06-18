import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Link a public capability to an AsyncArtwork collection on a user's account
transaction() {
    prepare(acct: AuthAccount) {
        acct.link<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, AsyncArtwork.AsyncCollectionPublic}>(
            AsyncArtwork.collectionPublicPath,
            target: AsyncArtwork.collectionStoragePath
        )
    }
}