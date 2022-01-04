import NFTAuction from "../contracts/NFTAuction.cdc"
import AsyncArtwork from "../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"

transaction(
    nftTypeIdentifier: String
) {
    let marketplaceClient: &NFTAuction.MarketplaceClient
    let nftReceiverCapability: Capability<&{NonFungibleToken.Receiver}>

    prepare(acct: AuthAccount) {
        self.marketplaceClient = acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) ?? panic("Could not borrow Marketplace Client resource")
        self.nftReceiverCapability = acct.getCapability<&{NonFungibleToken.Receiver}>(AsyncArtwork.collectionPublicPath)
    }

    execute {
        let nfts <- self.marketplaceClient.claimNFTs(nftTypeIdentifier: nftTypeIdentifier)

        let receiver = self.nftReceiverCapability.borrow() ?? panic("Invalid NFT Receiver Capability")

        while nfts.length > 0 {
            let nft <- nfts.removeFirst()
            receiver.deposit(token: <- nft)
        }

        destroy nfts
    }
}