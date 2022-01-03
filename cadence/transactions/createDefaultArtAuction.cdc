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
    let collectionProviderCapability: Capability<&{NonFungibleToken.Provider}>
    let collectionPublicCapability: Capability<&{NonFungibleToken.CollectionPublic}>

    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.collectionProviderCapability = acct.getCapability<&{NonFungibleToken.Provider}>(AsyncArtwork.collectionPrivatePath)
        self.collectionPublicCapability = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath)
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        let collection = self.collectionPublicCapability.borrow() ?? panic("Cannot borrow capability to collection public")
        let nft = collection.borrowNFT(id: tokenId)

        if nft == nil {
            panic("Lister does not own nft")
        }

        if nft.id != tokenId {
            panic("User has altered their ownedNFTs mapping")
        }

        self.marketplaceClient.createDefaultNftAuction(
            nftTypeIdentifier: nft.getType().identifier,
            tokenId: tokenId,
            currency: currency,
            minPrice: minPrice,
            buyNowPrice: buyNowPrice,
            feeRecipients: feeRecipients,
            feePercentages: feePercentages,
            nftProviderCapability: self.collectionProviderCapability
        )
    }
}