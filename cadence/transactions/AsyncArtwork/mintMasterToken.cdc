import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

transaction(
    id: UInt64, 
    artworkUri: String, 
    controlTokenArtists: [Address], 
    uniqueArtists: [Address]
) {
    let collection: &AsyncArtwork.Collection

    prepare(acct: AuthAccount) {
        self.collection = acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) ?? panic("Could not borrow Collection resource")
    }

    execute {
        self.collection.mintMasterToken(
            id: id,
            artworkUri: artworkUri,
            controlTokenArtists: controlTokenArtists,
            uniqueArtists: uniqueArtists
        )
    }
}