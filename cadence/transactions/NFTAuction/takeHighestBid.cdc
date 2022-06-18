import NFTAuction from "../../contracts/NFTAuction.cdc"

// Take the highest bid on an NFT listing 
transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        self.marketplaceClient.takeHighestBid(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId
        )
    }
}