import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import AsyncArtwork from "../contracts/AsyncArtwork.cdc"
import NFTAuction from "../contracts/NFTAuction.cdc"

transaction(
    tokenId: UInt64,
    currency: String,
    minPrice: UFix64,
    buyNowPrice: UFix64,
    feeRecipients: [Address],
    feePercentages: [UFix64]
) {
    let collectionCapability: Capability<&{NonFungibleToken.Collection}>
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.collectionCapability = acct.getCapability<&{NonFungibleToken.Collection}>(AsyncArtwork.collectionPrivatePath) ?? panic("Could not borrow private capability to Collection resource")
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        let collection = self.collectionCapability.borrow() ?? panic("Cannot borrow capability to collection")
        let nft = collection.borrowNFT(id: tokenId)

        if nft == nil {
            panic("Lister does not own nft")
        }

        self.marketplaceClient.createDefaultNftAuction(
            nftTypeIdentifier: nft.getType().identifier
            tokenId: tokenId,
            minPrice: UFix64,
            buyNowPrice: UFix64,
            feeRecipients: [Address],
            feePercentages: [UFix64],
            nftSellerCollectionCapability: 
        )
    }
}