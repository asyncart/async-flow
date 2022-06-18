import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Grant a user permission to update an AsyncArtwork control token 
transaction(
    id: UInt64,
    permissionedUser: Address,
    grant: Bool
) {
    let collection: &AsyncArtwork.Collection

    prepare(acct: AuthAccount) {
        self.collection = acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) ?? panic("Could not borrow Collection resource")
    }

    execute {
        self.collection.grantControlPermission(
            id: id,
            permissionedUser: permissionedUser,
            grant: grant
        )
    }
}