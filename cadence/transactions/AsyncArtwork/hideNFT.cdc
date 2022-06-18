import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Test mucking around with how an NFT is indexed on a collection
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