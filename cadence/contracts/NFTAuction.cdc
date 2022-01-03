import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import FUSD from "./FUSD.cdc"
import AsyncArtwork from "./AsyncArtwork.cdc"
import Blueprint from "./Blueprint.cdc"

pub contract NFTAuction {
    pub var marketplaceClientPublicPath: PublicPath
    pub var marketplaceClientPrivatePath: PrivatePath
    pub var marketplaceClientStoragePath: StoragePath

    pub var flowTokenCurrencyType: String

    pub var defaultBidIncreasePercentage: UFix64
    pub var minimumSettableIncreasePercentage: UFix64

    // The maximum allowable value for the "minPrice" as a percentage of the buyNowPrice
    // i.e. if this is 80, then if a given NFT has a buyNowPrice of 200, it's minPrice <= 160
    pub var maximumMinPricePercentage: UFix64
    pub var defaultAuctionBidPeriod: UFix64

    // A mapping of NFT type identifiers (analog of NFT contract addresses on ETH) to {nftIds -> Auctions}
    access(self) let auctions: {String: {UInt64: Auction}}

    // A mapping of NFT type identifiers to escrow collections
    access(self) let escrowCollections: @{String: NonFungibleToken.Collection}

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

    pub event BidMade(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        bidder: Address,
        currency: String,
        tokenAmount: UFix64
    );

    pub event AuctionPeriodUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        auctionEndPeriod: UFix64
    );

    pub event NFTTransferredAndSellerPaid(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftSeller: Address,
        nftHighestBid: UFix64,
        nftHighestBidder: Address,
        nftRecipient: Address
    );

    pub event AuctionSettled(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        auctionSettler: Address
    );

    pub event AuctionWithdrawn(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftOwner: Address
    );

    pub event BidWithdrawn(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        highestBidder: Address
    );

    pub event WhitelistedBuyerUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newWhitelistedBuyer: Address
    );

    pub event MinimumPriceUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newMinPrice: UFix64
    );

    pub event BuyNowPriceUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newBuyNowPrice: UFix64
    );

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
        let contractEscrow <- self.escrowCollections.remove(key: nftTypeIdentifier)!
        contractEscrow.deposit(token: <- nft)
        destroy <- self.escrowCollections.insert(key: nftTypeIdentifier, <- contractEscrow)
    }

    access(self) fun _transferNftAndPaySeller(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

        let vault <- self.escrowVaults.remove(key: auction.biddingCurrency)!
        let bid <- vault.withdraw(amount: auction.nftHighestBid!)

        self.auctions[nftTypeIdentifier]![tokenId]!.resetBids()

        self._payFeesAndSeller(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            seller: auction.nftSeller!, 
            bid: <- bid
        )

        destroy <- self.escrowVaults.insert(key: auction.biddingCurrency, <- vault)

        let receiverPath = self.nftTypePaths[nftTypeIdentifier]!.public
        let collection = getAccount(auction.getNFTRecipient()).getCapability<&{NonFungibleToken.CollectionPublic}>(receiverPath).borrow()

        let escrow <- self.escrowCollections.remove(key: nftTypeIdentifier)!

        let nft <- escrow.withdraw(withdrawID: tokenId)
        destroy <- self.escrowCollections.insert(key: nftTypeIdentifier, <- escrow)

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
      
      let escrow <- self.escrowCollections.remove(key: type)!
      escrow.deposit(token: <-  nft)
      destroy <- self.escrowCollections.insert(key: type, <- escrow)
    }

    access(self) fun _payFeesAndSeller(
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
    
    access(self) fun _updateOngoingAuction(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

        if auction.nftHighestBid != nil {
            if auction.buyNowPrice != nil {
                if auction.nftHighestBid! > auction.buyNowPrice! {
                    self._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    self._transferNftAndPaySeller(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    return
                }
            }

            if auction.minPrice != nil {
                if auction.nftHighestBid! >= auction.minPrice! {
                    self._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
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

    // This method seems obscure, also not the biggest fan of returning a copy of the struct (make void?)
    access(self) fun _resolveAuctionForBid(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        sender: Address
    ): Auction {
        var auction: Auction? = nil

        if NFTAuction.auctions[nftTypeIdentifier]![tokenId] == nil {
            // early bid

            // TODO: update this with the nft's fee recipients and fee percentages!
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
            // TODO: exploit here is if it is early bid, then nftSeller is null
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

        self._updateOngoingAuction(
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
        auctionBidPeriod: UFix64, // this is the time that the auction lasts until another bid occurs
        bidIncreasePercentage: UFix64
    ) {
        pre {
            self.minPriceDoesNotExceedLimit(buyNowPrice: buyNowPrice, minPrice: minPrice) : "MinPrice > 80% of buyNowPrice"
            feeRecipients.length == feeRecipients.length : "Recipients length != percentages length"
            self.sumPercentages(percentages: feePercentages) <= 10000.0 : "Fee percentages exceed maximum"
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
         //   let currentCurrency = self.auctions[nftTypeIdentifier]![tokenId]!.biddingCurrency 
          //  let prevHighestBidder = self.auctions[nftTypeIdentifier]![tokenId]!.nftHighestBidder

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

        self._updateOngoingAuction(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
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
            self.sumPercentages(percentages: feePercentages) <= 10000.0 : "Fee percentages exceed maximum"
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

            // assume feeRecipients and feePercentages remain the same since its set per nft
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

    pub resource MarketplaceClient {
        // createDefaultNftAuction
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

        // createNewNftAuction
        pub fun createNewNftAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            minPrice: UFix64,
            buyNowPrice: UFix64,
            auctionBidPeriod: UFix64, // this is the time that the auction lasts until another bid occurs
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

        // createSale
        pub fun createSale(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            minPrice: UFix64,
            buyNowPrice: UFix64,
            whitelistedBuyer: Address,
            auctionBidPeriod: UFix64,
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

        // makeBid
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

        // makeCustomBid
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

            // make sure nftRecipient can receive the nft being bidded on

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

        // settleAuction
        pub fun settleAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
                self.owner != nil : "Cannot perform operation while client in transit"
            }
            let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

            if auction.auctionEnd == nil {
                panic("Auction's end date should have been set by now")
            } else {
                if getCurrentBlock().timestamp < auction.auctionEnd! {
                    panic("Auction has not ended yet")
                }
            }

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

        // withdrawAuction
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

            let nft = collection.borrowNFT(id: tokenId) // this should revert if NFT is not in this resource's owner's collection
            
            NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.reset()

            emit AuctionWithdrawn(
              nftTypeIdentifier: nftTypeIdentifier,
              tokenId: tokenId,
              nftOwner: self.owner!.address
            )
        }

        // withdrawBid
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

        // updateWhitelistedBuyer
        pub fun updateWhitelistedBuyer(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newWhitelistedBuyer: Address
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

          if auction.buyNowPrice == nil || auction.minPrice != nil {
            panic("Not a sale")
          }

          NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.setWhitelistedBuyer(newWhitelistedBuyer: newWhitelistedBuyer)

          if auction.nftHighestBid != nil {
            // if an underbid is by a non whitelisted buyer, reverse that bid
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

        // updateMinimumPrice
        pub fun updateMinimumPrice(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newMinPrice: UFix64
        ) {
          pre {
            NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
            NFTAuction.auctions[nftTypeIdentifier]![tokenId] != nil : "Auction doesn't exist"
            self.owner != nil : "Cannot perform operation while client in transit"
            newMinPrice > 0.0 : "New min price has to be greater than 0"
          }

          let auction: Auction = NFTAuction.auctions[nftTypeIdentifier]![tokenId]!

          if auction.nftSeller == nil {
            panic("NFT seller must be set")
          } else if auction.nftSeller! != self.owner!.address {
            panic("Only NFT seller")
          }

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
              NFTAuction._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
              NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.setAuctionEnd()

              emit AuctionPeriodUpdated(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                auctionEndPeriod: NFTAuction.auctions[nftTypeIdentifier]![tokenId]!.auctionEnd!
              )
            }
          }
        }

        // updateBuyNowPrice
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

          // I believe we can assume minPrice is set here because at this point, the auction must be one that was instantiated through auction creation or sale creation, NOT through an early bid
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
              NFTAuction._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
              NFTAuction._transferNftAndPaySeller(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
            }
          }
        }

        // takeHighestBid
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
          NFTAuction._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
          NFTAuction._transferNftAndPaySeller(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)

          emit HighestBidTaken(
            nftTypeIdentifier: nftTypeIdentifier, 
            tokenId: tokenId
          )
        }

        pub fun claimNFTs(nftTypeIdentifier: String): @[NonFungibleToken.NFT] {
            pre {
                self.owner != nil : "Cannot perform operation while client in transit"
                NFTAuction.nftClaims[nftTypeIdentifier] != nil : "NFT type is not supported"
                NFTAuction.nftClaims[nftTypeIdentifier]![self.owner!.address] != nil : "Sender does not have any NFTs to claim for this NFT type"
            }

            let nfts: @[NonFungibleToken.NFT] <- []
            let ids = NFTAuction.nftClaims[nftTypeIdentifier]![self.owner!.address]!
            let escrowCollection <- NFTAuction.escrowCollections.remove(key: nftTypeIdentifier)!

            for id in ids {
              nfts.append(<- escrowCollection.withdraw(withdrawID: id))
            }

            destroy <- NFTAuction.escrowCollections.insert(key: nftTypeIdentifier, <- escrowCollection)

            return <- nfts
        }

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

    pub fun createMarketplaceClient(): @MarketplaceClient {
        return <- create MarketplaceClient()
    }

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

    // Public getter for auction information
    pub fun getAuction(_ nftTypeIdentifier: String,_ tokenId: UInt64): Auction{AuctionPublic}? {
        if !self.auctions.containsKey(nftTypeIdentifier) {
            return nil
        }
        return self.auctions[nftTypeIdentifier]![tokenId]
    }

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

    // skipped isAuctionNotStartedByOwner -> weird name seems obscure, hopefully we can do something better
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
                if collection.borrowNFT(id: tokenId) == nil {
                    panic("Sender doesn't own NFT")
                }

                self.auctions[nftTypeIdentifier]![tokenId]!.reset()
            }
        }
    }

    access(self) fun minPriceDoesNotExceedLimit(buyNowPrice: UFix64?, minPrice: UFix64): Bool {
        return buyNowPrice == nil || buyNowPrice! * (self.maximumMinPricePercentage/100.0) >= minPrice
    }

    // minPrice is minimum bid needed to inititate auction with end date
    access(self) fun doesBidMeetRequirements(auction: Auction, amount: UFix64): Bool {
        pre {
            amount > 0.0 : "Cannot bid nothing"
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

    // Getters (waiting to see on platformm default behaviour)

	init() {
        // TODO: Investigate how to pass args for contract deployment (and is it possible to do with project deploy)
        let asyncArtworkNFTType = "A.01cf0e2f2f715450.AsyncArtwork.NFT"
        let blueprintNFTType = "A.01cf0e2f2f715450.Blueprint.NFT"
        let flowTokenCurrencyType = "A.0ae53cb6e3f42a79.FlowToken.Vault"
        let fusdCurrencyType = "A.f8d6e0586b0a20c7.FUSD.Vault"

        self.defaultBidIncreasePercentage = 0.1
        self.defaultAuctionBidPeriod = 86400.0
        self.minimumSettableIncreasePercentage = 0.1
        self.maximumMinPricePercentage = 80.0
        self.marketplaceClientPublicPath = /public/MarketplaceClient
        self.marketplaceClientPrivatePath = /private/MarketplaceClient
        self.marketplaceClientStoragePath = /storage/MarketplaceClient
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
                Blueprint.collectionPublicPath, 
                Blueprint.collectionPrivatePath, 
                Blueprint.collectionStoragePath
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

        self.escrowCollections <- {
            asyncArtworkNFTType: <- AsyncArtwork.createEmptyCollection(),
            blueprintNFTType: <- Blueprint.createEmptyCollection()
        }

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