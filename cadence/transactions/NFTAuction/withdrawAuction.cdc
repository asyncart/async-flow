import NFTAuction from "../../contracts/NFTAuction.cdc"

// Withdraw a created auction that hasn't received any bids
transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        self.marketplaceClient.withdrawAuction(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId
        )
    }
}