import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

transaction() {
    prepare(mover: AuthAccount, receiver: AuthAccount) {
        let minter <- mover.load<@AsyncArtwork.Minter>(from: AsyncArtwork.minterStoragePath) ?? panic("Could not find minter")

        receiver.save(<-minter, to: AsyncArtwork.minterStoragePath)

        receiver.link<&AsyncArtwork.Minter>(
            AsyncArtwork.minterPrivatePath,
            target: AsyncArtwork.minterStoragePath
        )

        log("Moved Minter")
    }
}