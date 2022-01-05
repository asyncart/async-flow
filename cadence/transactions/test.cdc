import FungibleToken from "../contracts/FungibleToken.cdc"
import FUSD from "../contracts/FUSD.cdc"
import NFTAuction from "../contracts/NFTAuction.cdc"

transaction() {
    let vaultRef: &FungibleToken.Vault
    let marketplaceClient: &NFTAuction.MarketplaceClient
    prepare(acct: AuthAccount) {
        let standardCurrencyVaultPaths = NFTAuction.getCurrencyPaths()["A.f8d6e0586b0a20c7.FUSD.Vault"]

        self.vaultRef = acct.borrow<&FungibleToken.Vault>(from: standardCurrencyVaultPaths!.storage) ?? panic("aaaA")
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
        log(self.vaultRef.balance)
    }

    execute {
        log("FUSD BALANCE IN TXN")
        log(self.vaultRef.balance)
        let tokens <- self.vaultRef.withdraw(amount: 15.0)

        /*self.marketplaceClient.makeBid(
            nftTypeIdentifier: "A.01cf0e2f2f715450.AsyncArtwork.NFT",
            tokenId: 1,
            vault: <- tokens
        )*/
        destroy tokens
    }
}