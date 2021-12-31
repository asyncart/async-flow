import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import FUSD from "./FUSD.cdc"
import AsyncArtwork from "./AsyncArtwork.cdc"
import Blueprint from "./Blueprint.cdc"

// KNOWN VULNERABILITIES

// Letting other people bid without checking that they have the funds to support their bid
// allows a malicious actor to spamm bid very high amounts, forcing the auctioner to spin up
// new auctions

// Async Discussion:
// Arbitrary whitelisting
// Defaults (at Auction create time or platformm defaults at getter call time)

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
    access(self) let escrows: @{String: NonFungibleToken.Collection}

    // A mapping of NFT type identifiers to {nftIds -> bids for an auction}
    access(self) let bidVaults: @{String: {UInt64: FungibleToken.Vault}}

    // A mapping of NFT type identifiers to expected paths
    access(self) let nftTypePaths: {String: Paths}

    // A mapping of currency type identifiers to expected paths
    access(self) let currencyPaths: {String: Paths}

    // A mapping of NFT type identifiers to {nftIds -> Capabilities to grab an nft}
    access(self) let nftProviderCapabilities: {String: {UInt64: Capability<&NonFungibleToken.Collection>}}

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
        flowTokenAmount: UFix64,
        currency: Address,
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
        let provider = self.nftProviderCapabilities[nftTypeIdentifier]![tokenId]!.borrow() ?? panic("Could not find reference to nft collection provider")
        
        let nft <- provider.withdraw(withdrawID: tokenId)
        let contractEscrow <- self.escrows.remove(key: nftTypeIdentifier)!
        contractEscrow.deposit(token: <- nft)
        let old <- self.escrows.insert(key: nftTypeIdentifier, <- contractEscrow)
        destroy old
    }

    access(self) fun _transferNftAndPaySeller(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

        self.auctions[nftTypeIdentifier]![tokenId]!.resetBids()

        let contractBidVaults <- self.bidVaults.remove(key: nftTypeIdentifier)!
        let bid <- contractBidVaults.remove(key: tokenId)!

        self._payFeesAndSeller(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            seller: auction.nftSeller!, 
            bid: <- bid
        )

        let oldVault <- self.bidVaults.insert(key: nftTypeIdentifier, <- contractBidVaults)
        destroy oldVault

        let receiverPath = self.nftTypePaths[nftTypeIdentifier]!.public
        let collection = getAccount(auction.nftHighestBidder!).getCapability<&{NonFungibleToken.CollectionPublic}>(receiverPath).borrow()

        let escrow <- self.escrows.remove(key: nftTypeIdentifier)!

        let nft <- escrow.withdraw(withdrawID: tokenId)
        let oldCollection <- self.escrows.insert(key: nftTypeIdentifier, <- escrow)
        destroy oldCollection

     //   if collection != nil {

      //  } else {
            // send to claims
      //  }

        collection!.deposit(token: <- nft)

        self.auctions[nftTypeIdentifier]![tokenId]!.reset()
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
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                recipient: auction.feeRecipients[i], 
                amount: <- amount
            )

            i = i + 1
        }

        self._payout(
            nftTypeIdentifier: nftTypeIdentifier,
            tokenId: tokenId,
            recipient: seller, 
            amount: <- bid
        )
    }

    access(self) fun _payout(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        recipient: Address, 
        amount: @FungibleToken.Vault
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        let receiverPath = self.currencyPaths[auction.biddingCurrency!]!.public
        let vaultReceiver = getAccount(recipient).getCapability<&{FungibleToken.Receiver}>(receiverPath).borrow()

     //   if vaultReceiver != nil {

     //   } else {
            // send to claims
     //   }
        vaultReceiver!.deposit(from: <- amount)
    }
    
    access(self) fun _updateOngoingAuction(
        nftTypeIdentifier: String,
        tokenId: UInt64
    ) {
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

        if auction.nftHighestBid != nil {
            if auction.buyNowPrice != nil {
                if auction.buyNowPrice! > 0.0 && auction.nftHighestBid! > auction.buyNowPrice! {
                    self._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    self._transferNftAndPaySeller(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    return
                }
            }

            if auction.minPrice != nil {
                if auction.minPrice! > 0.0 && auction.nftHighestBid! >= auction.minPrice! {
                    self._transferNftToAuctionContract(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
                    self.auctions[nftTypeIdentifier]![tokenId]!.setAuctionEnd()
                }
            }
        }
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
        nftProviderCapability: Capability<&NonFungibleToken.Collection>,
        auctionBidPeriod: UFix64?, // this is the time that the auction lasts until another bid occurs
        bidIncreasePercentage: UFix64?,
    ) {
        pre {
            buyNowPrice == 0.0 || self.getPortionOfBid(totalBid: buyNowPrice, percentage: self.maximumMinPricePercentage) >= minPrice : "MinPrice > 80% of buyNowPrice"
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
                auctionBidPeriod: auctionBidPeriod,
                minPrice: minPrice,
                buyNowPrice: buyNowPrice,
                biddingCurrency: currency,
                whitelistedBuyer: nil,
                nftSeller: sender,
                bidIncreasePercentage: bidIncreasePercentage,
                nftProviderCapability: nftProviderCapability
            )
            self.auctions[nftTypeIdentifier]!.insert(key: tokenId, auction)
        } else {
            let currentCurrency = self.auctions[nftTypeIdentifier]![tokenId]!.biddingCurrency 
            let prevHighestBidder = self.auctions[nftTypeIdentifier]![tokenId]!.nftHighestBidder

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

            if currentCurrency != nil && currency != currentCurrency {
                let contractBidVaults <- self.bidVaults.remove(key: nftTypeIdentifier)!
                let vault: @FungibleToken.Vault? <- contractBidVaults.remove(key: tokenId)

                if vault != nil {
                    if prevHighestBidder == nil {
                        panic("Previous highest bidder can't be non existent as vault wasn't nil")
                    }

                    let receiverPath = self.currencyPaths[currentCurrency!]!.public
                    let receiverVault = getAccount(prevHighestBidder!).getCapability<&{FungibleToken.Receiver}>(receiverPath).borrow()
                //   if receiverVault == nil {
                        // send to claims
                //   } else {
                        
                //   }
                    receiverVault!.deposit(from: <- vault!)
                } else {
                    destroy vault
                }

                let old <- self.bidVaults.insert(key: nftTypeIdentifier, <- contractBidVaults)
                destroy old
            }
        }

        self._updateOngoingAuction(nftTypeIdentifier: nftTypeIdentifier, tokenId: tokenId)
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
            nftProviderCapability: Capability<&NonFungibleToken.Collection>,
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                minPrice > 0.0 : "Price not greater than 0"
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
                auctionBidPeriod: nil,
                bidIncreasePercentage: nil
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
            nftProviderCapability: Capability<&NonFungibleToken.Collection>,
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                minPrice > 0.0 : "Price not greater than 0"
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
            nftProviderCapability: Capability<&NonFungibleToken.Collection>
        ) {}

        // makeBid
        pub fun makeBid(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            tokenAmount: UFix64
        ) {}

        // makeCustomBid
        pub fun makeCustomBid(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            tokenAmount: UFix64,
            nftRecipient: Address 
        ) {}

        // settleAuction
        pub fun settleAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {}

        // withdrawAuction
        pub fun withdrawAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {}

        // withdrawBid
        pub fun withdrawBid(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {}

        // updateWhitelistedBuyer
        pub fun updateWhitelistedBuyer(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newWhitelistedBuyer: Address
        ) {}

        // updateMinimumPrice
        pub fun updateMinimumPrice(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newMinPrice: UFix64
        ) {}

        // updateBuyNowPrice
        pub fun updateBuyNowPrice(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            newBuyNowPrice: UFix64
        ) {}

        // takeHighestBid
        pub fun takeHighestBid(
            nftTypeIdentifier: String,
            tokenId: UInt64
        ) {}
    }

    pub struct Auction {
        pub var feeRecipients: [Address]
        pub var feePercentages: [UFix64]
        pub var nftHighestBid: UFix64?
        pub var nftHighestBidder: Address?
        pub var nftRecipient: Address?
        pub var auctionBidPeriod: UFix64?
        pub var auctionEnd: UFix64?
        pub var minPrice: UFix64?
        pub var buyNowPrice: UFix64?
        pub var biddingCurrency: String?
        pub var whitelistedBuyer: Address?
        pub var nftSeller: Address?
        
        pub var nftProviderCapability: Capability<&NonFungibleToken.Collection>

        // If this isn't passed on instantiation let's just make this the default value
        // the eth contract sets this to zero, and does a check for zero every time to see if it should instead use the current default
        // we could do that, but seems weird?
        pub var bidIncreasePercentage: UFix64?

        pub fun reset() {
            self.nftRecipient = nil
            self.auctionBidPeriod = nil
            self.auctionEnd = nil
            self.minPrice = nil
            self.buyNowPrice = nil
            self.biddingCurrency = nil
            self.whitelistedBuyer = nil
            self.nftSeller = nil
            self.bidIncreasePercentage = nil
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
            self.auctionBidPeriod = auctionBidPeriod
            self.minPrice = minPrice
            self.buyNowPrice = buyNowPrice
            self.biddingCurrency = biddingCurrency
            self.whitelistedBuyer = whitelistedBuyer
            self.nftSeller = nftSeller
            self.bidIncreasePercentage = bidIncreasePercentage
        }

        pub fun setNFTRecipient(nftRecipient: Address) {
            self.nftRecipient = nftRecipient
        }

        pub fun setHigherBid(nftHighestBid: UFix64, nftHighestBidder: Address) {
            self.nftHighestBid = nftHighestBid
            self.nftHighestBidder = nftHighestBidder
        }

        pub fun setAuctionEnd() {
            let bidPeriod: UFix64 = self.auctionBidPeriod != nil ? self.auctionBidPeriod! : NFTAuction.defaultAuctionBidPeriod
            self.auctionEnd = bidPeriod + getCurrentBlock().timestamp
        }

        pub fun setNFTProviderCapability(nftProviderCapability: Capability<&NonFungibleToken.Collection>) {
            self.nftProviderCapability = nftProviderCapability
        }

        pub fun getNFTRecipient(): Address {
            return self.nftRecipient != nil ? self.nftRecipient! : self.nftHighestBidder!
        }

        init(
            feeRecipients: [Address],
            feePercentages: [UFix64],
            nftHighestBid: UFix64?,
            nftHighestBidder: Address?,
            nftRecipient: Address?,
            auctionBidPeriod: UFix64?,
            minPrice: UFix64?,
            buyNowPrice: UFix64?,
            biddingCurrency: String?,
            whitelistedBuyer: Address?,
            nftSeller: Address?,
            bidIncreasePercentage: UFix64?,
            nftProviderCapability: Capability<&NonFungibleToken.Collection>
        ) {
            // init the stuff, waiting to see if there's any extra stuff we need on Auction
            // pull defaults if not specified
            self.nftHighestBid = nftHighestBid
            self.nftHighestBidder = nftHighestBidder 
            self.feeRecipients = feeRecipients
            self.feePercentages = feePercentages

            self.nftRecipient = nftRecipient
            self.auctionBidPeriod = auctionBidPeriod
            self.auctionEnd = nil
            self.minPrice = minPrice
            self.buyNowPrice = buyNowPrice
            self.biddingCurrency = biddingCurrency
            self.whitelistedBuyer = whitelistedBuyer
            self.nftSeller = nftSeller
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

    access(self) fun doesAuctionExist(_ nftTypeIdentifier: String, _ tokenId: UInt64): Bool {
        return self.auctions.containsKey(nftTypeIdentifier) && self.auctions[nftTypeIdentifier]!.containsKey(tokenId)
    }

    access(self) fun isAuctionOngoing(_ nftTypeIdentifier: String, _ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }
        let endTime: UFix64 = auctions[nftTypeIdentifier]![tokenId]!.auctionEnd

        // For some reason endTime == 0 means that people are bidding, but the minimum price hasn't been met yet
        // this isn't great. Why not an explicit flag?
        return endTime == 0.0 || endTime > getCurrentBlock().timestamp
    }

    // skipped priceGreaterThanZero -> doesn't seem useful

    access(self) fun minPriceDoesNotExceedLimit(buyNowPrice: UFix64, minPrice: UFix64): Bool {
        return buyNowPrice == 0.0 || buyNowPrice * (self.maximumMinPricePercentage/100) >= minPrice
    }

    // skipped notNFTSeller, onlyNFTSeller tbd on how we will authenticate stuff

    // @notice: A bid DOES NOT have to meet the "minPrice" to be a valid bid...idk why... but it's true!
    access(self) fun doesBidMeetRequirements(nftTypeIdentifier: String, tokenId: UFix64, tokenAmount: UFix64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!

        let buyNowPrice: UFix64 = auction.buyNowPrice
        if buyNowPrice > 0.0 && tokenAmount >= buyNowPrice {
            return true
        }

        let minimumAbsoluteNextBid: UFix64 = auction.nftHighestBid * (1+ (auction.bidIncreasePercentage/100))
        return tokenAmount >= minimumAbsoluteNextBid
    }

    // skipped onlyApplicableBuyer -> auth soln needed
    access(self) fun minimumBidMade(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }
        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        let minPrice: UFix64 = auction.minPrice

        return auction.minPrice > 0.0 && auction.nftHighestBid >= auction.minPrice
    }

    // paymentAccepted seemms pretty useless

    // isAuctionOver is just the not of auctionOngoing

    // increasePercentageAboveMinimum also needless

    access(self) fun isASale(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.buyNowPrice > 0.0 && auction.minPrice == 0.0
    }

    access(self) fun isWhitelistedSale(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.whitelistedBuyer != nil
    }

    access(self) fun bidMade(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.nftHighestBid > 0.0
    }

    access(self) fun isBuyNowPriceMet(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.buyNowPrice > 0.0 && auction.nftHighestBid >= auction.buyNowPrice
    }

    // Getters (waiting to see on platformm default behaviour)

	init(asyncArtworkNFTType: String, blueprintNFTType: String, flowTokenCurrencyType: String, fusdCurrencyType: String) {
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

        self.escrows <- {
            asyncArtworkNFTType: <- AsyncArtwork.createEmptyCollection(),
            blueprintNFTType: <- Blueprint.createEmptyCollection()
        }

        self.bidVaults <- {
            asyncArtworkNFTType: <- {
                (0 as UInt64): <- FlowToken.createEmptyVault() // NFT with id 0 doesn't exist, initializer
            },
            blueprintNFTType: <- {
                (0 as UInt64): <- FlowToken.createEmptyVault() // NFT with id 0 doesn't exist, initializer
            }
        }

        emit ContractInitialized()
	}
}