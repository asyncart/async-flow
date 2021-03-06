import NFTAuction from "../../contracts/NFTAuction.cdc"

// Withdraw a bid on an NFT
transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        self.marketplaceClient.withdrawBid(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId
        )
    }
}