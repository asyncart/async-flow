import NFTAuction from "../../contracts/NFTAuction.cdc"

// update the minimum price on a listing required to start holding bidder amounts on the contract
transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
    newMinPrice: UFix64
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        self.marketplaceClient.updateMinimumPrice(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            newMinPrice: newMinPrice
        )
    }
}