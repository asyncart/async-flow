import FungibleToken from "../../contracts/FungibleToken.cdc"
import NFTAuction from "../../contracts/NFTAuction.cdc"

// If an account is owed currency but did not have the receiver capability set up to receive it, they can use this transaction to claim it later
transaction(
    currency: String
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient
    let receiver: &FungibleToken.Vault

    prepare(acct: AuthAccount) {
        let standardPathsForCurrency = NFTAuction.getCurrencyPaths()[currency] ?? panic("Attempting to claim in unsupported currency")

        self.receiver = acct.borrow<&FungibleToken.Vault>(from: standardPathsForCurrency.storage) ?? panic("Could not borrow vault")
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
    }

    execute {
        self.receiver.deposit(from: <- self.marketplaceClient.claimPayout(currency: currency)) 
    }
}