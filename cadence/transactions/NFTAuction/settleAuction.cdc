import NFTAuction from "../../contracts/NFTAuction.cdc"

// The auction creator can use this tx to settle an auction, and give the NFT listed to the highest bidder
transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        self.marketplaceClient.settleAuction(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId
        )
    }
}