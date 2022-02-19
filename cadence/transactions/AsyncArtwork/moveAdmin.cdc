import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

transaction() {
    prepare(mover: AuthAccount, receiver: AuthAccount) {
        let admin <- mover.load<@AsyncArtwork.Admin>(from: AsyncArtwork.adminStoragePath) ?? panic("Could not find Admin")

        receiver.save(<-admin, to: AsyncArtwork.adminStoragePath)

        receiver.link<&AsyncArtwork.Admin>(
            AsyncArtwork.adminPrivatePath,
            target: AsyncArtwork.adminStoragePath
        )

        log("Moved Admin")
    }
}