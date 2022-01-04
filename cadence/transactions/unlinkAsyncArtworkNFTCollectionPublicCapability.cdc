import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

transaction() {
    prepare(acct: AuthAccount) {
        acct.unlink(AsyncArtwork.collectionPublicPath)
    }
}