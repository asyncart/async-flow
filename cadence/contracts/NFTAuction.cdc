import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import FUSD from "./FUSD.cdc"
import AsyncArtwork from "./AsyncArtwork.cdc"
import Blueprints from "./Blueprints.cdc"
import Royalties from "./Royalties.cdc"
import MetadataViews from "./MetadataViews.cdc"

pub contract NFTAuction {

    // The paths at which resources will be stored, and capabilities linked
    pub var marketplaceClientPublicPath: PublicPath
    pub var marketplaceClientPrivatePath: PrivatePath
    pub var marketplaceClientStoragePath: StoragePath
    pub var escrowCollectionStoragePath: StoragePath
    pub var escrowCollectionPrivatePath: PrivatePath
    pub var escrowCollectionPublicPath: PublicPath

    // The type identifier of an AsyncArtwork NFT
    pub var asyncArtworkNFTType: String

    // The type identifier of an Async Blueprints NFT
    pub var blueprintsNFTType: String

    // The type identifier for FlowTokens
    pub var flowTokenCurrencyType: String

    // The default minimum bind percentage increment for NFT Auctions
    pub var defaultBidIncreasePercentage: UFix64

    // The minimum bid increase percentage that a user can specify for their NFT Auction
    pub var minimumSettableIncreasePercentage: UFix64

    // The maximum allowable value for the "minPrice" as a percentage of the buyNowPrice
    // i.e. if this is 80, then if a given NFT has a buyNowPrice of 200, it's minPrice <= 160
    pub var maximumMinPricePercentage: UFix64

    // The bid period
    pub var defaultAuctionBidPeriod: UFix64

    // A mapping of NFT type identifiers (analog of NFT contract addresses on ETH) to {nftIds -> Auctions}
    access(self) let auctions: {String: {UInt64: Auction}}

    // A mapping of currency type identifiers to their escrow vaults
    access(self) let escrowVaults: @{String: FungibleToken.Vault}

    // A mapping of NFT type identifiers to expected paths
    access(self) let nftTypePaths: {String: Paths}

    // A mapping of currency type identifiers to expected paths
    access(self) let currencyPaths: {String: Paths}

    // A mapping of NFT type identifiers to {nftIds -> Capabilities to grab an nft}
    access(self) let nftProviderCapabilities: {String: {UInt64: Capability<&{NonFungibleToken.Provider}>}}

    // A mapping of NFT type identifiers to {User Addresses -> Ids of NFTs they are owed}
    access(self) let nftClaims: {String: {Address: [UInt64]}}

    // A mapping of currency type identifiers to {User Addresses -> Amounts of currency they are owed}
    access(self) let payoutClaims: {String: {Address: UFix64}}

    access(self) var escrowCollectionCap: Capability<&escrowCollection>

    // Emitted when a new NFT Auction (bidding on an NFT) is created
    pub event NftAuctionCreated(
        nftProjectIdentifier: String,
        tokenId: UInt64,
        nftSeller: Address,
        currency: String,
        minPrice: UFix64,
        buyNowPrice: UFix64,
        auctionBidPeriod: UFix64,
        bidIncreasePercentage: UFix64,
        feeRecipients: [Address],
        feePercentages: [UFix64]
    );

    // Emitted when a new direct NFT sale is created
    pub event SaleCreated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftSeller: Address,
        currency: String,
        buyNowPrice: UFix64,
        whitelistedBuyer: Address,
        feeRecipients: [Address],
        feePercentages: [UFix64]
    );

    // Emitted when a user makes a bid for a specific NFT
    pub event BidMade(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        bidder: Address,
        currency: String,
        tokenAmount: UFix64
    );

    // Emitted when the duraton of an auction is extended by a newly received bid
    pub event AuctionPeriodUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        auctionEndPeriod: UFix64
    );

    // Emitted when the sale/auctioning of an NFT closes and the recipient has been given their NFT and the seller has been paid
    pub event NFTTransferredAndSellerPaid(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftSeller: Address,
        nftHighestBid: UFix64,
        nftHighestBidder: Address,
        nftRecipient: Address
    );

    // Emitted when an auction is sucesfully closed (the highest bid is taken after the auction expires)
    pub event AuctionSettled(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        auctionSettler: Address
    );

    // Emitted when the creator of an auction chooses to withdraw it
    pub event AuctionWithdrawn(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftOwner: Address
    );

    // Emitted when a user withdraws their bid on a certain NFT
    pub event BidWithdrawn(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        highestBidder: Address
    );

    // Emitted when the (only) whitelisted buyer for a specific NFT is changed
    pub event WhitelistedBuyerUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newWhitelistedBuyer: Address
    );

    // Emitted when the minimum price in the auctioning of a specific NFT has changed
    pub event MinimumPriceUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newMinPrice: UFix64
    );

    // Emitted when the "buy now" price for a specific NFT has changed
    pub event BuyNowPriceUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newBuyNowPrice: UFix64
    );

    // Emitted when the creator of an auction accepts the highest bid
    pub event HighestBidTaken(
        nftTypeIdentifier: String,
        tokenId: UInt64
    );

    pub event ContractInitialized()

    pub struct Paths {
        pub var public: PublicPath
        pub var private: PrivatePath
        pub var storage: StoragePath

        init(_ _public: PublicPath, _ _private: PrivatePath, _ _storage: StoragePath) {
            self.public = _public 
            self.private = _private 
            self.storage = _storage 
        }
    }

    pub fun getNftTypePaths(): {String: Paths} {
        return self.nftTypePaths
    }

    pub fun getCurrencyPaths(): {String: Paths} {
        return self.currencyPaths
    }

    access(self) fun getPortionOfBid(totalBid: UFix64, percentage: UFix64): UFix64 {
        return (totalBid * percentage) / 100.0
    }

    access(self) fun sumPercentages(percentages: [UFix64]): UFix64 {
        var totalPercentage: UFix64 = 0.0 

        for percentage in percentages {
            totalPercentage = totalPercentage + percentage
        }

        return totalPercentage
    }

    access(self) fun _transferNftToAuctionContract(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        let provider = auction.nftProviderCapability!.borrow() ?? panic("Could not find reference to nft collection provider")
        let nft <- provider.withdraw(withdrawID: tokenId)
        self.escrowCollectionCap.borrow()!.deposit(token: <- nft)
    }

    access(self) fun _transferNftAndPaySeller(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

        let vault <- self.escrowVaults.remove(key: auction.biddingCurrency)!
        let bid <- vault.withdraw(amount: auction.nftHighestBid!)

        destroy <- self.escrowVaults.insert(key: auction.biddingCurrency, <- vault)

        self.auctions[nftTypeIdentifier]![tokenId]!.resetBids()

        let receiverPath = self.nftTypePaths[nftTypeIdentifier]!.public
        let collection = getAccount(auction.getNFTRecipient()).getCapability<&{NonFungibleToken.CollectionPublic}>(receiverPath).borrow()

        // for AsyncArtwork and Blueprints NFTs, ignore feeRecipients and feePercentages, for contract defined royalties
        if nftTypeIdentifier == self.asyncArtworkNFTType || nftTypeIdentifier == self.blueprintsNFTType {
            let readNFT = self.escrowCollectionCap.borrow()!.borrowViewResolver(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)

            let views: [Type] = readNFT.getViews()
            var royalty: {Royalties.Royalty}? = nil
            for view in views {
                if view == Type<{Royalties.Royalty}>() {
                    royalty = readNFT.resolveView(view) as! {Royalties.Royalty}?
                    break
                }
            }

            self._payFeesAndSellerAsyncContracts(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                seller: auction.nftSeller!, 
                bid: <- bid,
                royalty: royalty
            )
        } else {
            self._payFeesAndSellerGeneral(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                seller: auction.nftSeller!, 
                bid: <- bid
            )   
        }

        let nft <- self.escrowCollectionCap.borrow()!.withdraw(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
        let type: String = nft.getType().identifier

        if collection != nil {
          collection!.deposit(token: <- nft)
        } else {
          self._sendToNftClaims(recipient: auction.getNFTRecipient(), nft: <- nft, type: type)
        }

        self.auctions[nftTypeIdentifier]![tokenId]!.reset()

        emit NFTTransferredAndSellerPaid(
          nftTypeIdentifier: nftTypeIdentifier,
          tokenId: tokenId,
          nftSeller: auction.nftSeller!,
          nftHighestBid: auction.nftHighestBid!,
          nftHighestBidder: auction.nftHighestBidder!,
          nftRecipient: auction.getNFTRecipient()
        )
    }

    access(self) fun _sendToNftClaims(
      recipient: Address,
      nft: @NonFungibleToken.NFT,
      type: String
    ) {
      var ids: [UInt64] = []
      if self.nftClaims[type]![recipient] != nil {
        ids = self.nftClaims[type]![recipient]!
      } 
      ids.append(nft.id)
      self.nftClaims[type]!.insert(key: recipient, ids)
      
      self.escrowCollectionCap.borrow()!.deposit(token: <- nft)
    }

    access(self) fun _payFeesAndSellerAsyncContracts(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        seller: Address, 
        bid: @FungibleToken.Vault,
        royalty: {Royalties.Royalty}?
    ) {
        if royalty == nil {
            // didn't identify royalty view, try paying generally
            self._payFeesAndSellerGeneral(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                seller: seller, 
                bid: <- bid
            )
        } else {
            let royaltyAmount: UFix64? = royalty!.calculateRoyalty(type: bid.getType(), amount: bid.balance)
            if royaltyAmount == nil {
                // try paying fees via general
                self._payFeesAndSellerGeneral(
                    nftTypeIdentifier: nftTypeIdentifier,
                    tokenId: tokenId,
                    seller: seller, 
                    bid: <- bid
                )   
            } else {
                royalty!.distributeRoyalty(vault: <- bid.withdraw(amount: royaltyAmount!))

                self._payout(
                    recipient: seller, 
                    amount: <- bid
                )
            }
        }
    }

    access(self) fun _payFeesAndSellerGeneral(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        seller: Address, 
        bid: @FungibleToken.Vault
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        var feesPaid: UFix64 = 0.0
        var i: UInt64 = 0
        let originalBidBalance: UFix64 = bid.balance

        while i < UInt64(auction.feeRecipients.length) {
            let fee: UFix64 = self.getPortionOfBid(totalBid: originalBidBalance, percentage: auction.feePercentages[i])
            feesPaid = feesPaid + fee 
            let amount <- bid.withdraw(amount: fee)
            self._payout(
                recipient: auction.feeRecipients[i], 
                amount: <- amount
            )

            i = i + 1
        }

        self._payout(
            recipient: seller, 
            amount: <- bid
        )
    }

    access(self) fun _payout(
        recipient: Address, 
        amount: @FungibleToken.Vault
    ) {
        let currency: String = amount.getType().identifier
        let receiverPath = self.currencyPaths[currency]!.public
        let vaultReceiver = getAccount(recipient).getCapability<&{FungibleToken.Receiver}>(receiverPath).borrow()

        if vaultReceiver != nil {
          vaultReceiver!.deposit(from: <- amount)
        } else {
          self._payClaims(recipient: recipient, amount: <- amount, currency: currency)
        }
    }

    access(self) fun _payClaims(
      recipient: Address, 
      amount: @FungibleToken.Vault,
      currency: String
    ) {
      var newClaim: UFix64 = 0.0
      if self.payoutClaims[currency]![recipient] == nil {
        newClaim = amount.balance
      } else {
        newClaim = self.payoutClaims[currency]![recipient]! + amount.balance
      }
      self.payoutClaims[currency]!.insert(key: recipient, newClaim)

      let escrowVault <- self.escrowVaults.remove(key: currency)!
      escrowVault.deposit(from: <- amount)

      destroy <- self.escrowVaults.insert(key: currency, <- escrowVault)
    }
    
    access(self) fun _updateAuctionBasedOnLatestBid(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

        if auction.nftHighestBid != nil {
            if auction.buyNowPrice != nil {
                if auction.nftHighestBid! > auction.buyNowPrice! {
                    // Only pull the NFT into escrow if it is not already there
                    if !self.escrowCollectionCap.borrow()!.containsNFT(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId) {
                        self._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    }
                    self._transferNftAndPaySeller(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    return
                }
            }

            if auction.minPrice != nil {
                if auction.nftHighestBid! >= auction.minPrice! {
                    // Only pull the NFT into claims if it is not already there
                    if !self.escrowCollectionCap.borrow()!.containsNFT(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId) {
                        self._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    }

                    // Extend the auction period every time a new bid is received
                    self.auctions[nftTypeIdentifier]![tokenId]!.setAuctionEnd()

                    emit AuctionPeriodUpdated(
                        nftTypeIdentifier: nftTypeIdentifier,
                        tokenId: tokenId,
                        auctionEndPeriod: self.auctions[nftTypeIdentifier]![tokenId]!.auctionEnd!
                    )
                }
            }
        }
    }

    access(self) fun _resolveAuctionForBid(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        sender: Address
    ): Auction {
        var auction: Auction? = nil

        if NFTAuction.auctions[nftTypeIdentifier]![tokenId] == nil {
            // early bid

            // when supporting contracts not implementing royalty standard, or allowing overriding of recipients and percentages set on AsyncArtwork and Blueprints, refactor this
            let feeRecipients: [Address] = []
            let feePercentages: [UFix64] = []

            auction = Auction(
                feeRecipients: feeRecipients,
                feePercentages: feePercentages,
                nftHighestBid: nil, // will update in _makeBid
                nftHighestBidder: nil, // will update in _makeBid
                nftRecipient: nil,
                minPrice: nil,
                buyNowPrice: nil,
                biddingCurrency: NFTAuction.flowTokenCurrencyType,
                whitelistedBuyer: nil,
                nftSeller: nil,
                bidIncreasePercentage: NFTAuction.defaultBidIncreasePercentage,
                auctionBidPeriod: NFTAuction.defaultAuctionBidPeriod,
                nftProviderCapability: nil
            )

            NFTAuction.auctions[nftTypeIdentifier]!.insert(key: tokenId, auction!)
        } else {
            auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

            if auction!.auctionEnd != nil && getCurrentBlock().timestamp >= auction!.auctionEnd! {
                panic("Auction has ended")
            }
        }

        if !NFTAuction.onlyApplicableBuyer(auction: auction!, sender: sender) {
            panic("NFT on sale, only whitelisted account can bid")
        }

        return auction!
    }

    access(self) fun _makeBid(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        vault: @FungibleToken.Vault,
        sender: Address,
        auction: Auction 
    ) {
        pre {
            sender != auction.nftSeller : "Owner can't bid on own NFT"
            vault.getType().identifier == auction.biddingCurrency : "Attempted to bid with invalid currency"
            self.doesBidMeetRequirements(auction: auction, amount: vault.balance) : "Bid does not meet amount requirements"
        }

        // reverse previous bid if it exists
        if auction.nftHighestBidder != nil {
          let escrowVault <- self.escrowVaults.remove(key: auction.biddingCurrency)!
          let previousBid <- escrowVault.withdraw(amount: auction.nftHighestBid!)
          destroy <- self.escrowVaults.insert(key: auction.biddingCurrency, <- escrowVault)
          self._payout(
              recipient: auction.nftHighestBidder!, 
              amount: <- previousBid
          )
        }

        // update highest bid
        self.auctions[nftTypeIdentifier]![tokenId]!.setHigherBid(
            nftHighestBid: vault.balance,
            nftHighestBidder: sender
        )

        let tokenAmount: UFix64 = vault.balance

        let escrowVault <- self.escrowVaults.remove(key: auction.biddingCurrency)!
        escrowVault.deposit(from: <- vault)

        destroy <- self.escrowVaults.insert(key: auction.biddingCurrency, <- escrowVault)

        emit BidMade(
          nftTypeIdentifier: nftTypeIdentifier,
          tokenId: tokenId,
          bidder: sender,
          currency: auction.biddingCurrency,
          tokenAmount: tokenAmount
        )

        self._updateAuctionBasedOnLatestBid(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId
        )
    }

    access(self) fun _createNewNftAuction(
        sender: Address,
        nftTypeIdentifier: String,
        tokenId: UInt64,
        currency: String,
        minPrice: UFix64,
        buyNowPrice: UFix64,
        feeRecipients: [Address],
        feePercentages: [UFix64],
        nftProviderCapability: Capability<&{NonFungibleToken.Provider}>,
        auctionBidPeriod: UFix64,
        bidIncreasePercentage: UFix64
    ) {
        pre {
            self.minPriceDoesNotExceedLimit(buyNowPrice: buyNowPrice, minPrice: minPrice) : "MinPrice > 80% of buyNowPrice"
            feeRecipients.length == feeRecipients.length : "Recipients length != percentages length"
            self.sumPercentages(percentages: feePercentages) <= 100.0 : "Fee percentages exceed maximum"
        }

        if self.auctions[nftTypeIdentifier]![tokenId] == nil {
            let auction = Auction(
                feeRecipients: feeRecipients,
                feePercentages: feePercentages,
                nftHighestBid: nil,
                nftHighestBidder: nil,
                nftRecipient: nil,
                minPrice: minPrice,
                buyNowPrice: buyNowPrice,
                biddingCurrency: currency,
                whitelistedBuyer: nil,
                nftSeller: sender,
                bidIncreasePercentage: bidIncreasePercentage,
                auctionBidPeriod: auctionBidPeriod,
                nftProviderCapability: nftProviderCapability
            )
            self.auctions[nftTypeIdentifier]!.insert(key: tokenId, auction)
        } else {
            self.auctions[nftTypeIdentifier]![tokenId]!.setAuction(
                auctionBidPeriod: auctionBidPeriod, 
                minPrice: minPrice, 
                buyNowPrice: buyNowPrice, 
                biddingCurrency: currency, 
                whitelistedBuyer: nil, 
                nftSeller: sender, 
                bidIncreasePercentage: bidIncreasePercentage
            )

            self.auctions[nftTypeIdentifier]![tokenId]!.setNFTProviderCapability(nftProviderCapability: nftProviderCapability)

            let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

            if auction.nftHighestBid != nil {
                // send back the early bid as early bids can only be made in flowtoken, and specified currency is different currency
                if currency != self.flowTokenCurrencyType {
                    let escrowVault <- self.escrowVaults.remove(key: self.flowTokenCurrencyType)!
                    let previousBid <- escrowVault.withdraw(amount: auction.nftHighestBid!)
                    destroy <- self.escrowVaults.insert(key: self.flowTokenCurrencyType, <- escrowVault)

                    self._payout(recipient: auction.nftHighestBidder!, amount: <- previousBid)

                    // Null out highest bidder, because highest early bid currency does not match auction currency
                    self.auctions[nftTypeIdentifier]![tokenId]!.nullifyCurrentBidder()
                }
            }
        }

        emit NftAuctionCreated(
          nftProjectIdentifier: nftTypeIdentifier,
          tokenId: tokenId,
          nftSeller: sender,
          currency: currency,
          minPrice: minPrice,
          buyNowPrice: buyNowPrice,
          auctionBidPeriod: auctionBidPeriod,
          bidIncreasePercentage: bidIncreasePercentage,
          feeRecipients: feeRecipients,
          feePercentages: feePercentages
        )

        self._updateAuctionBasedOnLatestBid(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
    }

    access(self) fun _setupSale(
        sender: Address,
        nftTypeIdentifier: String,
        tokenId: UInt64,
        currency: String,
        buyNowPrice: UFix64,
        whitelistedBuyer: Address,
        feeRecipients: [Address],
        feePercentages: [UFix64],
        nftProviderCapability: Capability<&{NonFungibleToken.Provider}>
    ) {
        pre {
            feeRecipients.length == feePercentages.length : "Recipients and percentages lengths not the same"
            self.sumPercentages(percentages: feePercentages) <= 100.0 : "Fee percentages exceed maximum"
        }
        var auction: Auction? = nil

        if self.auctions[nftTypeIdentifier]![tokenId] == nil {
            auction = Auction(
                feeRecipients: feeRecipients,
                feePercentages: feePercentages,
                nftHighestBid: nil,
                nftHighestBidder: nil,
                nftRecipient: nil,
                minPrice: nil,
                buyNowPrice: buyNowPrice,
                biddingCurrency: currency,
                whitelistedBuyer: whitelistedBuyer,
                nftSeller: sender,
                bidIncreasePercentage: self.defaultBidIncreasePercentage,
                auctionBidPeriod: self.defaultAuctionBidPeriod,
                nftProviderCapability: nftProviderCapability
            )
            self.auctions[nftTypeIdentifier]!.insert(key: tokenId, auction!)
        } else {
            auction = self.auctions[nftTypeIdentifier]![tokenId]!

            auction!.setAuction(
                auctionBidPeriod: nil, 
                minPrice: nil, 
                buyNowPrice: buyNowPrice, 
                biddingCurrency: currency, 
                whitelistedBuyer: whitelistedBuyer, 
                nftSeller: sender, 
                bidIncreasePercentage: nil
            )

            auction!.setNFTProviderCapability(nftProviderCapability: nftProviderCapability)
        }
    }

    access(self) fun _reverseAndResetPreviousBid(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        let escrowVault <- self.escrowVaults.remove(key: auction.biddingCurrency)!
        let previousBid <- escrowVault.withdraw(amount: auction.nftHighestBid!)
        destroy <- self.escrowVaults.insert(key: auction.biddingCurrency, <- escrowVault)

        self._payout(
            recipient: auction.nftHighestBidder!, 
            amount: <- previousBid
        )

        self.auctions[nftTypeIdentifier]![tokenId]!.resetBids()
    }

    // This is a client resource that every user is expected to have. It facilitates all major interactions with the auction contract like making auctions, placing bids and accepting bids.
    pub resource MarketplaceClient {

        // Create an auction for a specific NFT with the default governance parameters set for some fields
        pub fun createDefaultNftAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            minPrice: UFix64,
            buyNowPrice: UFix64,
            feeRecipients: [Address],
            feePercentages: [UFix64],
            nftProviderCapability: Capability<&{NonFungibleToken.Provider}>
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                NFTAuction.escrowVaults[currency] != nil : "Currency not supported"
                self.owner != nil : "Cannot perform operation while client in transit"
            }

            let sender: Address = self.owner!.address 
            NFTAuction.manageAuctionStarted(nftTypeIdentifier, tokenId, sender)

            NFTAuction._createNewNftAuction(
                sender: sender,
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                currency: currency,
                minPrice: minPrice,
                buyNowPrice: buyNowPrice,
                feeRecipients: feeRecipients,
                feePercentages: feePercentages,
                nftProviderCapability: nftProviderCapability,
                auctionBidPeriod: NFTAuction.defaultAuctionBidPeriod,
                bidIncreasePercentage: NFTAuction.defaultBidIncreasePercentage
            )
        }

        // Create a new NFT Auction with as many custom options as possible
        pub fun createNewNftAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            minPrice: UFix64,
            buyNowPrice: UFix64,
            auctionBidPeriod: UFix64,
            bidIncreasePercentage: UFix64,
            feeRecipients: [Address],
            feePercentages: [UFix64],
            nftProviderCapability: Capability<&{NonFungibleToken.Provider}>,
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                NFTAuction.escrowVaults[currency] != nil : "Currency not supported"
                self.owner != nil : "Cannot perform operation while client in transit"
                bidIncreasePercentage >= NFTAuction.minimumSettableIncreasePercentage : "Bid increase percentage too low"
            }
            let sender: Address = self.owner!.address 
            NFTAuction.manageAuctionStarted(nftTypeIdentifier, tokenId, sender)

            NFTAuction._createNewNftAuction(
                sender: sender,
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                currency: currency,
                minPrice: minPrice,
                buyNowPrice: buyNowPrice,
                feeRecipients: feeRecipients,
                feePercentages: feePercentages,
                nftProviderCapability: nftProviderCapability,
                auctionBidPeriod: auctionBidPeriod,
                bidIncreasePercentage: bidIncreasePercentage
            )
        }   

        // Create a direct sale of an owned NFT asset to a particular buyer
        pub fun createSale(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            buyNowPrice: UFix64,
            whitelistedBuyer: Address,
            feeRecipients: [Address],
            feePercentages: [UFix64],
            nftProviderCapability: Capability<&{NonFungibleToken.Provider}>
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                NFTAuction.escrowVaults[currency] != nil : "Currency not supported"
                self.owner != nil : "Cannot perform operation while client in transit"
            }
            NFTAuction.manageAuctionStarted(nftTypeIdentifier, tokenId, self.owner!.address)
            NFTAuction._setupSale(
                sender: self.owner!.address,
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                currency: currency,
                buyNowPrice: buyNowPrice,
                whitelistedBuyer: whitelistedBuyer,
                feeRecipients: feeRecipients,
                feePercentages: feePercentages,
                nftProviderCapability: nftProviderCapability
            )

            emit SaleCreated(
              nftTypeIdentifier: nftTypeIdentifier,
              tokenId: tokenId,
              nftSeller: self.owner!.address,
              currency: currency,
              buyNowPrice: buyNowPrice,
              whitelistedBuyer: whitelistedBuyer,
              feeRecipients: feeRecipients,
              feePercentages: feePercentages
            )

            let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

            if auction.nftHighestBid != nil {
                // if the currency isn't FlowToken, send back the early bid as early bid has to be in FlowToken
                if (currency == NFTAuction.flowTokenCurrencyType) && (auction.whitelistedBuyer == nil || auction.whitelistedBuyer! == auction.nftHighestBidder!) {
                    if auction.buyNowPrice != nil && auction.nftHighestBid! > auction.buyNowPrice! {
                        NFTAuction._transferNftToAuctionContract(
                            nftTypeIdentifier: nftTypeIdentifier,
                            tokenId: tokenId
                        )
                        NFTAuction._transferNftAndPaySeller(
                            nftTypeIdentifier: nftTypeIdentifier,
                            tokenId: tokenId
                        )
                    }
                } else {
                    NFTAuction._reverseAndResetPreviousBid(
                        nftTypeIdentifier: nftTypeIdentifier,
                        tokenId: tokenId
                    )
                } 
            }
        }

        // Make a bid on a specific NFT asset
        pub fun makeBid(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            vault: @FungibleToken.Vault
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                self.owner != nil : "Cannot perform operation while client in transit"
                NFTAuction.nftCollectionSetup(nftTypeIdentifier: nftTypeIdentifier, futureRecipient: self.owner!.address) : "Collection receiver not setup"
            }

            var auction: Auction = NFTAuction._resolveAuctionForBid(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                sender: self.owner!.address
            )
        
            NFTAuction._makeBid(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                vault: <- vault,
                sender: self.owner!.address,
                auction: auction
            )
        }

        // Make a bid on a specific NFT asset, and specify an address that the NFT should be transferred to if accepted
        pub fun makeCustomBid(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            vault: @FungibleToken.Vault,
            nftRecipient: Address 
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                self.owner != nil : "Cannot perform operation while client in transit"
                NFTAuction.nftCollectionSetup(nftTypeIdentifier: nftTypeIdentifier, futureRecipient: self.owner!.address) : "Collection receiver not setup"
            }

            // make sure nftRecipient can receive the nft being bid on

            var auction: Auction = NFTAuction._resolveAuctionForBid(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                sender: self.owner!.address
            )

            NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.setNFTRecipient(nftRecipient: nftRecipient)
        
            NFTAuction._makeBid(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                vault: <- vault,
                sender: self.owner!.address,
                auction: auction
            )
        }

        // This function can be called by anyone to "settle" a given auction after it has ended. The default behaviour is to accept the highest bid above the minimum price (if applicable).
        pub fun settleAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
                NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.nftHighestBid != nil : "This auction does not have any valid bids, to cancel auction call: withdrawAuction"
                NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.nftHighestBidder != nil : "NFT highest bidder is invalid, cannot settle"
                NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.auctionEnd != nil : "Auction end date not set, cannot settle"
                getCurrentBlock().timestamp > NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.auctionEnd! + 10.0 : "Cannot settle auction before end time" // accounting for potential 10 second offset
                self.owner != nil : "Cannot perform operation while client in transit"
            }

            let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

            NFTAuction._transferNftAndPaySeller(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId
            )

            emit AuctionSettled(
              nftTypeIdentifier: nftTypeIdentifier,
              tokenId: tokenId,
              auctionSettler: self.owner!.address
            )
        }

        // The creator of an auction may withdraw the auction so long as they have not recieved any bids at or above the minimum price.
        pub fun withdrawAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
                self.owner != nil : "Cannot perform operation while client in transit"
                NFTAuction.nftTypePaths[nftTypeIdentifier] != nil : "Paths for nft type must exist"
            }

            let collectionPath: PublicPath = NFTAuction.nftTypePaths[nftTypeIdentifier]!.public
            let collection = getAccount(self.owner!.address).getCapability<&{NonFungibleToken.CollectionPublic}>(collectionPath).borrow()
                ?? panic("Could not borrow public reference to owner's collection")

            if collection.borrowNFT(id: tokenId).id != tokenId {
                panic("User does not currently own NFT! If the NFT is in escrow, the auction cannot be withdrawn!")
            }
            
            NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.reset()

            emit AuctionWithdrawn(
              nftTypeIdentifier: nftTypeIdentifier,
              tokenId: tokenId,
              nftOwner: self.owner!.address
            )
        }

        // A user may withdraw a bid that they have made on a speicifc NFT (as long as it hasn't been accepted already).
        pub fun withdrawBid(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
                self.owner != nil : "Cannot perform operation while client in transit"
            }
            let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

            if auction.nftHighestBid == nil {
                panic("No bid to withdraw")
            }

            if auction.minPrice != nil {
                if auction.nftHighestBid! >= auction.minPrice! {
                    panic("The auction has a valid bid made")
                }
            }

            if auction.nftHighestBidder! != self.owner!.address {
                panic("Cannot withdraw funds")
            }

            let escrowVault <- NFTAuction.escrowVaults.remove(key: auction.biddingCurrency)!            
            let previousBid <- escrowVault.withdraw(amount: auction.nftHighestBid!)
            destroy <- NFTAuction.escrowVaults.insert(key: auction.biddingCurrency, <- escrowVault)

            NFTAuction._payout(recipient: auction.nftHighestBidder!, amount: <- previousBid)

            NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.resetBids()

            emit BidWithdrawn(
              nftTypeIdentifier: nftTypeIdentifier,
              tokenId: tokenId,
              highestBidder: auction.nftHighestBidder!
            )
        }

        // Update the address of the user who is allowed to purchase the given NFT
        pub fun updateWhitelistedBuyer(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newWhitelistedBuyer: Address
        ) {
          pre {
              NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
              NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
              self.owner != nil : "Cannot perform operation while client in transit"
              NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.nftSeller != nil : "Auction NFT seller must be set"
              NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.nftSeller! == self.owner!.address : "This function is only callable by the NFT seller"
              NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.buyNowPrice != nil && NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.minPrice == nil : "The Auction must be a sale to update the whitelisted buyer field"
          }

          let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

          NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.setWhitelistedBuyer(newWhitelistedBuyer: newWhitelistedBuyer)

          if auction.nftHighestBid != nil {
            // If a bid exists from another user, then that bid should be returned to them since they are no longer whitelisted for this NFT
            if auction.nftHighestBidder! != newWhitelistedBuyer {
              let escrowVault <- NFTAuction.escrowVaults.remove(key: auction.biddingCurrency)!
              let previousBid <- escrowVault.withdraw(amount: auction.nftHighestBid!)
              destroy <- NFTAuction.escrowVaults.insert(key: auction.biddingCurrency, <- escrowVault)
              NFTAuction._payout(recipient: auction.nftHighestBidder!, amount: <- previousBid)

              NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.resetBids()
            }
          }

          emit WhitelistedBuyerUpdated(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            newWhitelistedBuyer: newWhitelistedBuyer
          )
        }

        // Update the minimum price property for a specific NFT
        pub fun updateMinimumPrice(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newMinPrice: UFix64
        ) {
          pre {
            NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
            NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
            self.owner != nil : "Cannot perform operation while client in transit"
            NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.nftSeller != nil : "Auction NFT seller cannot be nil to update min price"
            NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.nftSeller! == self.owner!.address : "Min price can only be updated by nftSeller"
            newMinPrice > 0.0 : "New min price has to be greater than 0"
          }

          let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

          if auction.minPrice != nil {
            if auction.nftHighestBid != nil {
              if auction.nftHighestBid! >= auction.minPrice! {
                  panic("The auction has a valid bid made")
              }
            }
          }

          if auction.buyNowPrice != nil && auction.minPrice == nil {
            panic("Not applicable for a sale")
          }

          if !NFTAuction.minPriceDoesNotExceedLimit(buyNowPrice: auction.buyNowPrice, minPrice: newMinPrice) {
            panic("MinPrice > 80% of buyNowPrice")
          }

          NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.setPriceParams(minPrice: newMinPrice, buyNowPrice: nil)

          emit MinimumPriceUpdated(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            newMinPrice: newMinPrice
          )

          if auction.nftHighestBid != nil {
            if auction.nftHighestBid! >= auction.minPrice! {
              if !NFTAuction.escrowCollectionCap.borrow()!.containsNFT(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId) {
                NFTAuction._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
              }

              NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.setAuctionEnd()

              emit AuctionPeriodUpdated(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                auctionEndPeriod: NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.auctionEnd!
              )
            }
          }
        }

        // Update the "buy now" price for a specific NFT
        pub fun updateBuyNowPrice(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newBuyNowPrice: UFix64
        ) {
          pre {
            NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
            NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
            self.owner != nil : "Cannot perform operation while client in transit"
            newBuyNowPrice > 0.0 : "Buy now price is not greater than 0"
          }

          let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

          if auction.nftSeller == nil {
            panic("NFT seller must be set")
          } else if auction.nftSeller! != self.owner!.address {
            panic("Only NFT seller")
          }

          if !NFTAuction.minPriceDoesNotExceedLimit(buyNowPrice: newBuyNowPrice, minPrice: auction.minPrice!) {
            panic("MinPrice > 80% of buyNowPrice")
          }

          NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.setPriceParams(minPrice: nil, buyNowPrice: newBuyNowPrice)

          emit BuyNowPriceUpdated(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            newBuyNowPrice: newBuyNowPrice
          )

          if auction.nftHighestBid != nil {
            if auction.nftHighestBid! > auction.buyNowPrice! {
              if !NFTAuction.escrowCollectionCap.borrow()!.containsNFT(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId) {
                NFTAuction._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
              }
              NFTAuction._transferNftAndPaySeller(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
            }
          }
        }

        // The creator of an auction can accept the highest bid, closing out the auction
        pub fun takeHighestBid(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {
          pre {
            NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
            NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
            self.owner != nil : "Cannot perform operation while client in transit"
          }

          let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

          if auction.nftSeller == nil {
            panic("NFT seller must be set")
          } else if auction.nftSeller! != self.owner!.address {
            panic("Only NFT seller")
          }

          if auction.nftHighestBid == nil {
            panic("Cannot payout 0 bid")
          }

          if !NFTAuction.escrowCollectionCap.borrow()!.containsNFT(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId) {
              NFTAuction._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
          }

          NFTAuction._transferNftAndPaySeller(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)

          emit HighestBidTaken(
            nftTypeIdentifier: nftTypeIdentifier, 
            tokenId: tokenId
          )
        }

        // If a user was successful in bidding to recieve a specific NFT, but at the time of payout did not have the correct collection/linked capabilities
        // to be able to recieve the NFT we store it in "claims". The user can then "claim" the NFT at any time using this function. This function will return
        // all NFTs that the user successfully purchased but was unable to receive.
        pub fun claimNFTs(nftTypeIdentifier: String): @[NonFungibleToken.NFT] {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                NFTAuction.nftClaims[nftTypeIdentifier] != nil : "NFT type is not supported"
                NFTAuction.nftClaims[nftTypeIdentifier]![self.owner!.address] != nil : "Sender does not have any NFTs to claim for this NFT type"
            }

            let nfts: @[NonFungibleToken.NFT] <- []
            let ids = NFTAuction.nftClaims[nftTypeIdentifier]![self.owner!.address]!
            let escrowCollection = NFTAuction.escrowCollectionCap.borrow()!

            for id in ids {
              nfts.append(<- escrowCollection.withdraw(nftTypeIdentifier: nftTypeIdentifier, tokenId: id))
            }

            // Remove user from the claims mapping
            NFTAuction.nftClaims[nftTypeIdentifier]!.remove(key: self.owner!.address)

            return <- nfts
        }

        // If an auction creator accepts a bid, or has their auction settled but does not have the correct vaults or capabilities linked to recieve their payment
        // the payment is added to a "claims" vault.
        pub fun claimPayout(currency: String): @FungibleToken.Vault {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                NFTAuction.payoutClaims[currency] != nil : "Currency type is not supported"
                NFTAuction.payoutClaims[currency]![self.owner!.address] != nil : "Sender does not have any payouts to claim for this currency"
            }

            let withdrawAmount: UFix64 = NFTAuction.payoutClaims[currency]![self.owner!.address]!
            let escrowVault <- NFTAuction.escrowVaults.remove(key: currency)!
            let payout: @FungibleToken.Vault <- escrowVault.withdraw(amount: withdrawAmount)

            destroy <- NFTAuction.escrowVaults.insert(key: currency, <- escrowVault)

            return <- payout
        }
    }

    // Function for anyone to create a marketplace client resource
    pub fun createMarketplaceClient(): @MarketplaceClient {
        return <- create MarketplaceClient()
    }

    // Publicly visible properties of any auction
    pub struct interface AuctionPublic {
      pub var feeRecipients: [Address]
      pub var feePercentages: [UFix64]
      pub var nftHighestBid: UFix64?
      pub var nftHighestBidder: Address?
      pub var nftRecipient: Address?
      pub var auctionBidPeriod: UFix64
      pub var auctionEnd: UFix64?
      pub var minPrice: UFix64?
      pub var buyNowPrice: UFix64?
      pub var biddingCurrency: String
      pub var whitelistedBuyer: Address?
      pub var nftSeller: Address?
      pub var bidIncreasePercentage: UFix64
    }

    // Public getter for auction information, returns a copy of the public auction object (subsequent data maniuplation does not affect the source)
    pub fun getAuction(_ nftTypeIdentifier: String,_ tokenId: UInt64): Auction{AuctionPublic}? {
        if !self.auctions.containsKey(nftTypeIdentifier) {
            return nil
        }
        return self.auctions[nftTypeIdentifier]![tokenId]
    }

    // A generic auction structure that manages the auctioning and selling of NFT assets
    pub struct Auction: AuctionPublic {
        pub var feeRecipients: [Address]
        pub var feePercentages: [UFix64]
        pub var nftHighestBid: UFix64?
        pub var nftHighestBidder: Address?
        pub var nftRecipient: Address?
        pub var auctionBidPeriod: UFix64
        pub var auctionEnd: UFix64?
        pub var minPrice: UFix64?
        pub var buyNowPrice: UFix64?
        pub var biddingCurrency: String
        pub var whitelistedBuyer: Address?
        pub var nftSeller: Address?
        
        pub var nftProviderCapability: Capability<&{NonFungibleToken.Provider}>?
        pub var bidIncreasePercentage: UFix64

        pub fun reset() {
            self.nftRecipient = nil
            self.auctionEnd = nil
            self.minPrice = nil
            self.buyNowPrice = nil
            self.biddingCurrency = NFTAuction.flowTokenCurrencyType
            self.whitelistedBuyer = nil
            self.nftSeller = nil
            self.auctionBidPeriod = NFTAuction.defaultAuctionBidPeriod
            self.bidIncreasePercentage = NFTAuction.defaultBidIncreasePercentage
            self.nftProviderCapability = nil 
        }

        pub fun resetBids() {
            self.nftHighestBidder = nil 
            self.nftHighestBid = nil 
            self.nftRecipient = nil
        }

        pub fun setAuction(
            auctionBidPeriod: UFix64?,
            minPrice: UFix64?,
            buyNowPrice: UFix64?,
            biddingCurrency: String?,
            whitelistedBuyer: Address?,
            nftSeller: Address?,
            bidIncreasePercentage: UFix64?
        ) {
            if buyNowPrice != nil && buyNowPrice! <= 0.0 {
                panic("Buy now price cannot be 0")
            }

            if minPrice != nil && minPrice! <= 0.0 {
                panic("Min price cannot be 0")
            }

            if bidIncreasePercentage != nil && bidIncreasePercentage! <= 0.0 {
                panic("Bid increase percentage cannot be 0")
            }

            if auctionBidPeriod != nil && auctionBidPeriod! <= 0.0 {
                panic("Auction bid period cannot be 0")
            }

            self.auctionBidPeriod = auctionBidPeriod != nil ? auctionBidPeriod! : self.auctionBidPeriod
            self.minPrice = minPrice != nil ? minPrice : self.minPrice
            self.buyNowPrice = buyNowPrice != nil ? buyNowPrice : self.buyNowPrice
            self.biddingCurrency = biddingCurrency != nil ? biddingCurrency! : self.biddingCurrency
            self.whitelistedBuyer = whitelistedBuyer != nil ? whitelistedBuyer : self.whitelistedBuyer
            self.nftSeller = nftSeller != nil ? nftSeller : self.nftSeller
            self.bidIncreasePercentage = bidIncreasePercentage != nil ? bidIncreasePercentage! : self.bidIncreasePercentage
        }

        pub fun setNFTRecipient(nftRecipient: Address) {
            self.nftRecipient = nftRecipient
        }

        pub fun setHigherBid(nftHighestBid: UFix64, nftHighestBidder: Address) {
            self.nftHighestBid = nftHighestBid
            self.nftHighestBidder = nftHighestBidder
        }

        pub fun nullifyCurrentBidder() {
            self.nftHighestBid = nil
            self.nftHighestBidder = nil
        }

        pub fun setAuctionEnd() {
            self.auctionEnd = self.auctionBidPeriod + getCurrentBlock().timestamp
        }

        pub fun setNFTProviderCapability(nftProviderCapability: Capability<&{NonFungibleToken.Provider}>) {
            self.nftProviderCapability = nftProviderCapability
        }

        pub fun setWhitelistedBuyer(newWhitelistedBuyer: Address) {
          self.whitelistedBuyer = newWhitelistedBuyer
        }

        pub fun getNFTRecipient(): Address {
            return self.nftRecipient != nil ? self.nftRecipient! : self.nftHighestBidder!
        }

        pub fun setPriceParams(minPrice: UFix64?, buyNowPrice: UFix64?) {
          self.minPrice = minPrice != nil ? minPrice : self.minPrice
          self.buyNowPrice = buyNowPrice != nil ? buyNowPrice : self.buyNowPrice
        }

        init(
            feeRecipients: [Address],
            feePercentages: [UFix64],
            nftHighestBid: UFix64?,
            nftHighestBidder: Address?,
            nftRecipient: Address?,
            minPrice: UFix64?,
            buyNowPrice: UFix64?,
            biddingCurrency: String,
            whitelistedBuyer: Address?,
            nftSeller: Address?,
            bidIncreasePercentage: UFix64,
            auctionBidPeriod: UFix64,
            nftProviderCapability: Capability<&{NonFungibleToken.Provider}>?
        ) {
            pre {
                feeRecipients.length <= 500 : "More than 500 fee recipients not allowed"
            }

            if buyNowPrice != nil && buyNowPrice! <= 0.0 {
                panic("Buy now price cannot be 0")
            }

            if minPrice != nil && minPrice! <= 0.0 {
                panic("Min price cannot be 0")
            }

            if bidIncreasePercentage != nil && bidIncreasePercentage <= 0.0 {
                panic("Bid increase percentage cannot be 0")
            }

            if auctionBidPeriod != nil && auctionBidPeriod <= 0.0 {
                panic("Auction bid period cannot be 0")
            }

            self.nftHighestBid = nftHighestBid
            self.nftHighestBidder = nftHighestBidder 
            self.feeRecipients = feeRecipients
            self.feePercentages = feePercentages

            self.nftRecipient = nftRecipient
            self.auctionEnd = nil
            self.minPrice = minPrice
            self.buyNowPrice = buyNowPrice
            self.biddingCurrency = biddingCurrency
            self.whitelistedBuyer = whitelistedBuyer
            self.nftSeller = nftSeller
            self.auctionBidPeriod = auctionBidPeriod
            self.bidIncreasePercentage = bidIncreasePercentage

            self.nftProviderCapability = nftProviderCapability
        }
    }

    access(self) fun manageAuctionStarted(_ nftTypeIdentifier: String, _ tokenId: UInt64, _ sender: Address) {
        let auction: Auction? = self.auctions[nftTypeIdentifier]![tokenId]
        if auction != nil {
            // auction exists
            if auction!.nftSeller != nil {
                if auction!.nftSeller! == sender {
                    panic("Auction already started by owner")
                }

                let path: PublicPath = self.nftTypePaths[nftTypeIdentifier]!.public

                let collection = getAccount(sender).getCapability<&{NonFungibleToken.CollectionPublic}>(path).borrow() ?? panic("Could not borrow reference to sender's collection")
                if collection.borrowNFT(id: tokenId) == nil || collection.borrowNFT(id: tokenId).id != tokenId {
                    panic("Cannot confirm sender owns NFT")
                }

                self.auctions[nftTypeIdentifier]![tokenId]!.reset()
            }
        }
    }

    access(self) fun minPriceDoesNotExceedLimit(buyNowPrice: UFix64?, minPrice: UFix64): Bool {
        return buyNowPrice == nil || buyNowPrice! * (self.maximumMinPricePercentage/100.0) >= minPrice
    }

    access(self) fun doesBidMeetRequirements(auction: Auction, amount: UFix64): Bool {
        pre {
            amount > 0.0 : "Zero value bids are invalid"
        }
        
        if auction.buyNowPrice != nil && amount >= auction.buyNowPrice! {
            return true
        }

        if auction.nftHighestBid == nil {
            // allow bid of any amount greater than 0
            return true 
        } else {
            return amount >= auction.nftHighestBid! * (1.0 + (auction.bidIncreasePercentage/100.0))
        }
    }

    access(self) fun onlyApplicableBuyer(auction: Auction, sender: Address): Bool {
        if auction.whitelistedBuyer == nil {
            return true 
        } else {
            return auction.whitelistedBuyer! == sender
        }
    }

    access(self) fun nftCollectionSetup(nftTypeIdentifier: String, futureRecipient: Address): Bool {
        let path: PublicPath = self.nftTypePaths[nftTypeIdentifier]!.public

        return getAccount(futureRecipient).getCapability<&{NonFungibleToken.CollectionPublic}>(path).check()
    }

    // The public interface into the NFT escrow collection. These are public methods that can be called to view the contents of which NFTs this contract is holding in escrow
    pub resource interface escrowCollectionPublic {

        // The number of NFTs in escrow
        pub var totalSupply: UInt64

        // Borrow a reference to an NFT that is in escrow
        pub fun borrowNFT(nftTypeIdentifier: String, tokenId: UInt64): &NonFungibleToken.NFT 

        // Borrow a ViewResolver to fetch metadata for a specific NFT in escrow
        pub fun borrowViewResolver(nftTypeIdentifier: String, tokenId: UInt64): &{MetadataViews.Resolver}

        // Check if an NFT is in escrow
        pub fun containsNFT(nftTypeIdentifier: String, tokenId: UInt64): Bool

        // Get paths that the escrow collection uses to payout and withdraw NFTs
        pub fun getTypesToProviderPaths(): {String: PrivatePath}
        pub fun getTypesToStoragePaths(): {String: StoragePath}
        pub fun getTypesToReceiverPaths(): {String: PublicPath}
    }
    
    // The resource that manages escrow of NFTs. NFTs are pulled into escrow when a minimum price bid is received for an auction they are associated with. Upon the conclusion of the auction, the NFTs are removed from escrow and given to
    // the appropriate recipient.
    pub resource escrowCollection: escrowCollectionPublic {
        access(self) var ownedNFTs: {String: {UInt64: UInt64}}

        // Dictionary of NFT types -> capabilities to their collections
        access(self) var typesToCollectionCapabilities: {String: Capability<&NonFungibleToken.Collection>}

        access(self) var typesToViewCollectionCapabilities: {String: Capability<&{MetadataViews.ResolverCollection}>}

        access(self) var typesToProviderPaths: {String: PrivatePath}

        access(self) var typesToStoragePaths: {String: StoragePath}

        access(self) var typesToReceiverPaths: {String: PublicPath}

        pub var totalSupply: UInt64

        pub fun getTypesToProviderPaths(): {String: PrivatePath} {
            return self.typesToProviderPaths
        }

        pub fun getTypesToStoragePaths(): {String: StoragePath} {
            return self.typesToStoragePaths
        }

        pub fun getTypesToReceiverPaths(): {String: PublicPath} {
            return self.typesToReceiverPaths
        }

        pub fun containsNFT(nftTypeIdentifier: String, tokenId: UInt64): Bool {
            return self.ownedNFTs.containsKey(nftTypeIdentifier) && self.ownedNFTs[nftTypeIdentifier]!.containsKey(tokenId)
        }

        pub fun withdraw(nftTypeIdentifier: String, tokenId: UInt64): @NonFungibleToken.NFT{
            if self.ownedNFTs.containsKey(nftTypeIdentifier) && self.ownedNFTs[nftTypeIdentifier]!.containsKey(tokenId) {
                self.ownedNFTs[nftTypeIdentifier]!.remove(key: tokenId)
            } else {
                panic("Withdrawing id that is not in ownedNFTs")
            }

            let typeRef = self.typesToCollectionCapabilities[nftTypeIdentifier] ?? panic("NFT type not supported") 
            let collection = typeRef.borrow() ?? panic("Could not borrow reference to Collection") 
            let nft <- collection.withdraw(withdrawID: tokenId)
            self.totalSupply = self.totalSupply - (1 as UInt64)
            return <- nft
        }
    
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let tokenType = token.getType().identifier

            if self.ownedNFTs.containsKey(tokenType) {
                if self.ownedNFTs[tokenType]!.containsKey(token.id) {
                    panic("Somehow depositing token that is already in claims!")
                }
                self.ownedNFTs[tokenType]!.insert(key: token.id, token.id)
            } else {
                self.ownedNFTs.insert(key: tokenType, {token.id : token.id})
            }

            let typeRef = self.typesToCollectionCapabilities[tokenType] ?? panic("NFT type not supported") 
            let collection = typeRef.borrow() ?? panic("Could not borrow reference to Collection") 
            collection.deposit(token: <- token)
            self.totalSupply = self.totalSupply + (1 as UInt64)
        }

        pub fun borrowNFT(nftTypeIdentifier: String, tokenId: UInt64): &NonFungibleToken.NFT {
            let typeRef = self.typesToCollectionCapabilities[nftTypeIdentifier] ?? panic("Does not support NFT type") 
            let collection = typeRef.borrow() ?? panic("Could not borrow reference to NFTCollection") 
            let nft: &NonFungibleToken.NFT = collection.borrowNFT(id: tokenId)
            return nft
        }

        pub fun borrowViewResolver(nftTypeIdentifier: String, tokenId: UInt64): &{MetadataViews.Resolver} {
            let typeRef = self.typesToViewCollectionCapabilities[nftTypeIdentifier] ?? panic("Does not support NFT type") 
            let collection = typeRef.borrow() ?? panic("Could not borrow reference to NFTCollection") 
            let nft: &{MetadataViews.Resolver} = collection.borrowViewResolver(id: tokenId)
            return nft
        }
        
        init (
            asyncArtworkNFTType: String, 
            blueprintNFTType: String, 
            asyncArtworkEscrowCollectionPrivateCap: Capability<&NonFungibleToken.Collection>, 
            blueprintEscrowCollectionPrivateCap: Capability<&NonFungibleToken.Collection>,
            asyncArtworkEscrowCollectionPublicCap: Capability<&{MetadataViews.ResolverCollection}>, 
            blueprintEscrowCollectionPublicCap: Capability<&{MetadataViews.ResolverCollection}>
        ) {
            self.totalSupply = 0
            self.ownedNFTs = {}
            self.typesToCollectionCapabilities = {
                asyncArtworkNFTType: asyncArtworkEscrowCollectionPrivateCap,
                blueprintNFTType: blueprintEscrowCollectionPrivateCap
            }
            self.typesToViewCollectionCapabilities = {
                asyncArtworkNFTType: asyncArtworkEscrowCollectionPublicCap,
                blueprintNFTType: blueprintEscrowCollectionPublicCap
            }
            self.typesToStoragePaths = {
                asyncArtworkNFTType: AsyncArtwork.collectionStoragePath,
                blueprintNFTType: Blueprints.collectionStoragePath
            } 
            self.typesToProviderPaths = {
                asyncArtworkNFTType: AsyncArtwork.collectionPrivatePath,
                blueprintNFTType: Blueprints.collectionPrivatePath
            }
            self.typesToReceiverPaths = {
                asyncArtworkNFTType: AsyncArtwork.collectionPublicPath,
                blueprintNFTType: Blueprints.collectionPublicPath
            }
        }
    }

	init(asyncArtworkNFTType: String, blueprintNFTType: String, flowTokenCurrencyType: String, fusdCurrencyType: String) {

        self.defaultBidIncreasePercentage = 0.1
        self.defaultAuctionBidPeriod = 86400.0
        self.minimumSettableIncreasePercentage = 0.1
        self.maximumMinPricePercentage = 80.0
        self.marketplaceClientPublicPath = /public/MarketplaceClient
        self.marketplaceClientPrivatePath = /private/MarketplaceClient
        self.marketplaceClientStoragePath = /storage/MarketplaceClient
        self.escrowCollectionPrivatePath = /private/EscrowCollectionPrivate
        self.escrowCollectionPublicPath = /public/escrowCollectionPublic
        self.escrowCollectionStoragePath = /storage/escrowCollection
        self.asyncArtworkNFTType = asyncArtworkNFTType
        self.blueprintsNFTType = blueprintNFTType
        self.flowTokenCurrencyType = flowTokenCurrencyType

        self.auctions = {
            asyncArtworkNFTType: {},
            blueprintNFTType: {}
        }

        self.nftProviderCapabilities = {
            asyncArtworkNFTType: {},
            blueprintNFTType: {}
        }

        self.nftTypePaths = {
            asyncArtworkNFTType: Paths(
                AsyncArtwork.collectionPublicPath,
                AsyncArtwork.collectionPrivatePath, 
                AsyncArtwork.collectionStoragePath
            ),
            blueprintNFTType: Paths(
                Blueprints.collectionPublicPath, 
                Blueprints.collectionPrivatePath, 
                Blueprints.collectionStoragePath
            )
        }

        self.currencyPaths = {
            flowTokenCurrencyType: Paths(
                /public/flowTokenReceiver,
                /private/flowTokenVault, // technically unknown standard
                /storage/flowTokenVault
            ),
            fusdCurrencyType: Paths(
                /public/fusdReceiver,
                /private/fusdVault, // technically unknown standard
                /storage/fusdVault
            )
        }

        let asyncArtworkCollection <- AsyncArtwork.createEmptyCollection()
        self.account.save(<- asyncArtworkCollection, to: AsyncArtwork.collectionStoragePath)

        let asyncEscrowCollectionPrivateCap = self.account.link<&NonFungibleToken.Collection>(
            AsyncArtwork.collectionPrivatePath,
            target: AsyncArtwork.collectionStoragePath
        ) ?? panic("Coud not link private capability to async artwork collection")

        self.account.link<&AsyncArtwork.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, AsyncArtwork.AsyncCollectionPublic}>(
            AsyncArtwork.collectionPublicPath,
            target: AsyncArtwork.collectionStoragePath
        )

        let asyncEscrowCollectionPublicCap = self.account.link<&{MetadataViews.ResolverCollection}>(
            AsyncArtwork.collectionMetadataViewResolverPublicPath,
            target: AsyncArtwork.collectionStoragePath
        )

        let blueprintCollection <- Blueprints.createEmptyCollection()
        self.account.save(<- blueprintCollection, to: Blueprints.collectionStoragePath)

        let blueprintEscrowCollectionPrivateCap = self.account.link<&NonFungibleToken.Collection>(
            Blueprints.collectionPrivatePath,
            target: Blueprints.collectionStoragePath
        ) ?? panic("Could not link private capability to blueprint collection!")

        self.account.link<&Blueprints.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(
            Blueprints.collectionPublicPath,
            target: Blueprints.collectionStoragePath
        )

        let blueprintEscrowCollectionPublicCap = self.account.link<&{MetadataViews.ResolverCollection}>(
            Blueprints.collectionMetadataViewResolverPublicPath,
            target: Blueprints.collectionStoragePath
        )

        let escrow <- create escrowCollection(
            asyncArtworkNFTType: asyncArtworkNFTType,  
            blueprintNFTType: blueprintNFTType, 
            asyncArtworkEscrowCollectionPrivateCap: asyncEscrowCollectionPrivateCap, 
            blueprintEscrowCollectionPrivateCap: blueprintEscrowCollectionPrivateCap,
            asyncArtworkEscrowCollectionPublicCap: asyncEscrowCollectionPublicCap!, 
            blueprintEscrowCollectionPublicCap: blueprintEscrowCollectionPublicCap!
        )
        self.account.save(<- escrow, to: self.escrowCollectionStoragePath)

        self.escrowCollectionCap = self.account.link<&escrowCollection>(
            self.escrowCollectionPrivatePath,
            target: self.escrowCollectionStoragePath
        ) ?? panic("Failed to link private capability to NFT Collection escrow resource")

        self.account.link<&escrowCollection{escrowCollectionPublic}>(
            self.escrowCollectionPublicPath,
            target: self.escrowCollectionStoragePath
        )

        self.escrowVaults <- {
            flowTokenCurrencyType: <- FlowToken.createEmptyVault(),
            fusdCurrencyType: <- FUSD.createEmptyVault()
        }

        self.nftClaims = {
          asyncArtworkNFTType: {},
          blueprintNFTType: {}
        }

        self.payoutClaims = {
          flowTokenCurrencyType: {},
          fusdCurrencyType: {}
        }

        emit ContractInitialized()
	}
}