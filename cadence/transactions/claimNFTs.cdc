import NFTAuction from "../contracts/NFTAuction.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"

transaction(
    nftTypeIdentifier: String
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient
    let nftReceiver: &NonFungibleToken.Collection

    prepare(acct: AuthAccount) {
        let standardPathsForNFT = NFTAuction.getNftTypePaths()[nftTypeIdentifier] ?? panic("Invalid NFT type identifier")

        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
        self.nftReceiver = acct.borrow<&NonFungibleToken.Collection>(from: standardPathsForNFT.storage) ?? panic("Could not borrow NFT collection for deposit")
    }

    execute {
        let nfts <- self.marketplaceClient.claimNFTs(nftTypeIdentifier: nftTypeIdentifier)

        while nfts.length > 0 {
            let nft <- nfts.removeFirst()
            self.nftReceiver.deposit(token: <- nft)
        }

        destroy nfts
    }
}