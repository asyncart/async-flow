import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Unlink a user's public capability to an AsyncArtwork collection
transaction() {
    prepare(acct: AuthAccount) {
        acct.unlink(AsyncArtwork.collectionPublicPath)
    }
}