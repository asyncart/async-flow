import AsyncArtwork from "../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"

transaction(
    tokenUri: String, 
    leverMinValues: [Int64], 
    leverMaxValues: [Int64], 
    leverStartValues: [Int64], 
    numAllowedUpdates: Int64
) {
    var nftReceiverCapability: Capability<&{NonFungibleToken.CollectionPublic}>

    prepare(acct: AuthAccount) {
        // AsyncArtwork collection catch all
        if acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) == nil {
            acct.save(
                <- AsyncArtwork.createEmptyCollection(),
                to:AsyncArtwork.collectionStoragePath
            )

            acct.link<&{NonFungibleToken.CollectionPublic}>(
                AsyncArtwork.collectionPublicPath,
                target: AsyncArtwork.collectionStoragePath
            )
        }

        self.nftReceiverCapability = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath)
        if (!self.nftReceiverCapability.check()) {
            self.nftReceiverCapability = acct.link<&{NonFungibleToken.CollectionPublic}>(
                AsyncArtwork.collectionPublicPath,
                target: AsyncArtwork.collectionStoragePath
            )!
        }
    }

    execute {
        AsyncArtwork.setupControlToken(
            recipient: self.nftReceiverCapability.borrow()!,
            tokenUri: tokenUri, 
            leverMinValues: leverMinValues, 
            leverMaxValues: leverMaxValues, 
            leverStartValues: leverStartValues, 
            numAllowedUpdates: numAllowedUpdates
        )
        log("Setup control token")
    }
}
