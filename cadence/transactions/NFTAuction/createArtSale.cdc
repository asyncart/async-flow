import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import NFTAuction from "../../contracts/NFTAuction.cdc"

transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
    currency: String,
    buyNowPrice: UFix64,
    whitelistedBuyer: Address,
    feeRecipients: [Address],
    feePercentages: [UFix64]
) {
    let collectionProviderCapability: Capability<&{NonFungibleToken.Provider}>
    let collectionPublicCapability: Capability<&{NonFungibleToken.CollectionPublic}>

    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        let standardPathsForNFT = NFTAuction.getNftTypePaths()[nftTypeIdentifier] ?? panic("NFT type not supported")

        self.collectionProviderCapability = acct.getCapability<&{NonFungibleToken.Provider}>(standardPathsForNFT.private)
        self.collectionPublicCapability = acct.getCapability<&{NonFungibleToken.CollectionPublic}>(standardPathsForNFT.public)
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        let collection = self.collectionPublicCapability.borrow() ?? panic("Cannot borrow capability to collection public")
        let nft = collection.borrowNFT(id: tokenId)

        if nft == nil {
            panic("Lister does not own nft")
        }

        self.marketplaceClient.createSale(
            nftTypeIdentifier: nft.getType().identifier,
            tokenId: tokenId,
            currency: currency,
            buyNowPrice: buyNowPrice,
            whitelistedBuyer: whitelistedBuyer,
            feeRecipients: feeRecipients,
            feePercentages: feePercentages,
            nftProviderCapability: self.collectionProviderCapability
        )
    }
}