import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Mint an AsyncArtwork control token to the caller's address
transaction(
    id: UInt64,
    tokenUri: String, 
    leverMinValues: [Int64], 
    leverMaxValues: [Int64], 
    leverStartValues: [Int64],
    numAllowedUpdates: Int64,
    additionalCollaborators: [Address]
) {
    let collection: &AsyncArtwork.Collection

    prepare(acct: AuthAccount) {
        self.collection = acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) ?? panic("Could not borrow Collection resource")
    }

    execute {
        self.collection.mintControlToken(
            id: id,
            tokenUri: tokenUri, 
            leverMinValues: leverMinValues, 
            leverMaxValues: leverMaxValues, 
            leverStartValues: leverStartValues,
            numAllowedUpdates: numAllowedUpdates,
            additionalCollaborators: additionalCollaborators
        )
    }
}