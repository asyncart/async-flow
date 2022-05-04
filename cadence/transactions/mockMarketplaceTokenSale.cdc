import AsyncArtwork from "../contracts/AsyncArtwork.cdc"
import Blueprints from "../contracts/Blueprints.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import FlowToken from "../contracts/FlowToken.cdc"
import NFTAuction from "../contracts/NFTAuction.cdc"
import FUSD from "../contracts/FUSD.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"

// The signer of this txn is the implicit money source to pay out all of the royalties out of a big pot
transaction(
    nftSeller: Address,
    nftTypeIdentifier: String,
    nftId: UInt64,
    mockSaleValue: UFix64,
    mockSaleCurrency: String
) {
    prepare(acct: AuthAccount) {
        let nftSellerAccount = getAccount(nftSeller)
        let nftCollectionPath = NFTAuction.getNftTypePaths()[nftTypeIdentifier]!.public
        let resolverCollection = nftSellerAccount.getCapability<&{MetadataViews.ResolverCollection}>(nftCollectionPath).borrow() ?? panic("Could not obtain reference to NFT collection")
        let viewResolver = resolverCollection.borrowViewResolver(id: nftId)
        let royaltyWrapper = viewResolver.resolveView(Type<MetadataViews.Royalties>()) as! MetadataViews.Royalties
        let royalties = royaltyWrapper.getRoyalties()
        let standardCurrencyProviderPath = NFTAuction.getCurrencyPaths()[mockSaleCurrency]!.storage
        let mockPaymentVault <- acct.borrow<&{FungibleToken.Provider}>(from: standardCurrencyProviderPath)!.withdraw(amount: mockSaleValue)
        for royalty in royalties {
            let royaltyVault <- mockPaymentVault.withdraw(amount: royalty.cut * mockSaleValue)
            royalty.receiver.borrow()!.deposit(from: <- royaltyVault)
        }
        let sellerReceiver = nftSellerAccount.getCapability<&{FungibleToken.Receiver}>(NFTAuction.getCurrencyPaths()[mockSaleCurrency]!.public).borrow() ?? panic("NFT seller cannot receive payment in currency")
        sellerReceiver.deposit(from: <- mockPaymentVault)
    }

    /*execute {
        let nfts <- self.marketplaceClient.claimNFTs(nftTypeIdentifier: nftTypeIdentifier)

        while nfts.length > 0 {
            let nft <- nfts.removeFirst()
            self.nftReceiver.deposit(token: <- nft)
        }

        destroy nfts
    }*/
}