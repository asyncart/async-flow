import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Move an AsyncArtwork minter resource off the caller's account to another account
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