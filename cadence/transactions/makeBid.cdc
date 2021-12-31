import FungibleToken from "../contracts/FungibleToken.cdc"
import NFTAuction from "../contracts/NFTAuction.cdc"

transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
    currency: String,
    tokenAmount: UFix64
) {
    let vaultCapability: Capability<&FungibleToken.Vault>
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        let standardCurrencyVaultPaths = NFTAuction.getCurrencyPaths()[currency]

        if standardCurrencyVaultPath == nil {
            panic("Specified currency is not supported")
        }

        self.vaultCapability = acct.getCapability<&{FungibleToken.Vault}>(standardCurrencyVaultPaths.private) ?? panic("Could not borrow private capability to Vault resource")
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {

        self.marketplaceClient.makeBid(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            currency: String,
            tokenAmount: UFix64,
            bidderVaultCapability: self.vaultCapability
        )
    }
}