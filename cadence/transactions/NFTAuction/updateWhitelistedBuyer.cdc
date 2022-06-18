import NFTAuction from "../../contracts/NFTAuction.cdc"

// Update the whitelisted buyer that is the only buyer able to purchase a direct sale
transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
    newWhitelistedBuyer: Address
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        self.marketplaceClient.updateWhitelistedBuyer(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            newWhitelistedBuyer: newWhitelistedBuyer
        )
    }
}