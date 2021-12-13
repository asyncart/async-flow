import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AsyncArtwork.AsyncUser>(from: AsyncArtwork.asyncUserStoragePath) == nil {
            let user <- AsyncArtwork.createAsyncUser()
            acct.save(<- user, to: AsyncArtwork.asyncUserStoragePath)

            acct.link<&AsyncArtwork.AsyncUser>(
                AsyncArtwork.asyncUserPrivatePath,
                target: AsyncArtwork.asyncUserStoragePath
            )

            acct.link<&AsyncArtwork.AsyncUser>(
                AsyncArtwork.asyncUserPublicPath,
                target: AsyncArtwork.asyncUserStoragePath
            )

            log("Initialized async user")
        }
    }
}
