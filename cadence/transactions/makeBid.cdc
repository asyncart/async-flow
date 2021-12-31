import FungibleToken from "../contracts/FungibleToken.cdc"
import NFTAuction from "../contracts/NFTAuction.cdc"

transaction(
    nftTypeIdentifier: String,
    tokenId: UInt64,
    currency: String,
    tokenAmount: UFix64
) {
    let vaultRef: &FungibleToken.Vault
    let marketplaceClient: &NFTAuction.MarketplaceClient

    prepare(acct: AuthAccount) {
        let standardCurrencyVaultPaths = NFTAuction.getCurrencyPaths()[currency]

        if standardCurrencyVaultPaths == nil {
            panic("Specified currency is not supported")
        }

        self.vaultRef = acct.borrow<&FungibleToken.Vault>(standardCurrencyVaultPaths.storage) ?? panic("Could not borrow Vault resource")
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        let tokens <- vaultRef.withdraw(amount: tokenAmount)

        self.marketplaceClient.makeBid(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            currency: String,
            tokens: <- tokens
        )
    }
}