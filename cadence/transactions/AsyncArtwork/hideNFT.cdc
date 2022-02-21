import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

transaction(
    id: UInt64
) {
    let collection: &AsyncArtwork.Collection

    prepare(acct: AuthAccount) {
        self.collection = acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) ?? panic("Could not borrow Collection resource")
    }

    execute {
        self.collection.ownedNFTs[1] <-> self.collection.ownedNFTs[99]
    }
}