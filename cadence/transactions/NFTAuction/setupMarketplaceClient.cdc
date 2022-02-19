import NFTAuction from "../../contracts/NFTAuction.cdc"

transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) == nil {
            let marketplaceClient <- NFTAuction.createMarketplaceClient()
            acct.save(<- marketplaceClient, to: NFTAuction.marketplaceClientStoragePath)

            acct.link<&NFTAuction.MarketplaceClient>(
                NFTAuction.marketplaceClientPrivatePath,
                target: NFTAuction.marketplaceClientStoragePath
            )

            acct.link<&NFTAuction.MarketplaceClient>(
                NFTAuction.marketplaceClientPublicPath,
                target: NFTAuction.marketplaceClientStoragePath
            )
        }
    }
}