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

    access(self) fun _createNewNftAuction(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        currency: String,
        minPrice: UFix64,
        buyNowPrice: UFix64,
        feeRecipients: Address,
        feePercentages: UFix64
    ) {}

    pub resource MarketplaceClient {
        // createDefaultNftAuction
        pub fun createDefaultNftAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            minPrice: UFix64,
            buyNowPrice: UFix64,
            feeRecipients: Address,
            feePercentages: UFix64
        ) {
            pre {
                NFTAuction.auctions[nftTypeIdentifier] != nil : "Type identifier invalid"
                minPrice > 0.0 : "Price not greater than 0"
                self.owner != nil : "Cannot perform operation while client in transit"
            }

            let sender: Address = self.owner!.address 
            NFTAuction.manageAuctionStarted(nftTypeIdentifier, tokenId, sender)

            NFTAuction._createNewNftAuction(
                nftTypeIdentifier: nftTypeIdentifier,
                tokenId: tokenId,
                currency: currency,
                minPrice: minPrice,
                buyNowPrice: buyNowPrice,
                feeRecipients: feeRecipients,
                feePercentages: feePercentages
            )
        }

        // createNewNftAuction
        pub fun createNewNftAuction(
            nftTypeIdentifier: String,
            tokenId: UInt64,
            currency: String,
            minPrice: UFix64,
            buyNowPrice: UFix64,
            auctionBidPeriod: UFix64,
            feeRecipients: Address,
            feePercentages: UFix64
        ) {}

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
            feePercentages: [UFix64]
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
        // non-optionals
        pub var nftHighestBid: UFix64
        pub var nftHighestBidder: Address
        pub var nftRecipient: Address
        pub var feeRecipients: [Address]
        pub var feePercentages: [UFix64]

        // optionals
        pub var auctionBidPeriod: UFix64?
        pub var auctionEnd: UFix64?
        pub var minPrice: UFix64?
        pub var buyNowPrice: UFix64?
        pub var biddingCurrency: String?
        pub var whitelistedBuyer: Address?
        pub var nftSeller: Address?

        // If this isn't passed on instantiation let's just make this the default value
        // the eth contract sets this to zero, and does a check for zero every time to see if it should instead use the current default
        // we could do that, but seems weird?
        pub var bidIncreasePercentage: UFix64?

        init(
            nftHighestBid: UFix64,
            nftHighestBidder: Address,
            nftRecipient: Address,
            feeRecipients: [Address],
            feePercentages: [UFix64],
            auctionBidPeriod: UFix64?,
            auctionEnd: UFix64?,
            minPrice: UFix64?,
            buyNowPrice: UFix64?,
            biddingCurrency: String?,
            whitelistedBuyer: Address?,
            nftSeller: Address?,
            bidIncreasePercentage: UFix64?
        ) {
            // init the stuff, waiting to see if there's any extra stuff we need on Auction
            // pull defaults if not specified
            self.nftHighestBid = nftHighestBid
            self.nftHighestBidder = nftHighestBidder
            self.nftRecipient = nftRecipient 
            self.feeRecipients = feeRecipients
            self.feePercentages = feePercentages

            self.auctionBidPeriod = auctionBidPeriod
            self.auctionEnd = auctionEnd
            self.minPrice = minPrice
            self.buyNowPrice = buyNowPrice
            self.biddingCurrency = biddingCurrency
            self.whitelistedBuyer = whitelistedBuyer
            self.nftSeller = nftSeller
            self.bidIncreasePercentage = bidIncreasePercentage
        }
    }

    // skipped isAuctionNotStartedByOwner -> weird name seems obscure, hopefully we can do something better
    access(self) fun manageAuctionStarted(_ nftTypeIdentifier: String, _ tokenId: UInt64, _ sender: Address) {
        let auction: Auction? = self.auctions[nftTypeIdentifier]![tokenId]
        if auction != nil {
            // auction exists
            if auction!.nftSeller == sender {
                panic("Auction already started by owner")
            }

            let path: PublicPath = self.nftTypePaths[nftTypeIdentifier]!.public

            let collection = getAccount(sender).getCapability<&{NonFungibleToken.CollectionPublic}>(path).borrow() ?? panic("Could not borrow reference to sender's collection")
            if collection.borrowNFT(id: tokenId) == nil {
                panic("Sender doesn't own NFT")
            }

            self.auctions[nftTypeIdentifier]!.remove(key: tokenId)
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

    access(self) fun areFeePercentagesLessThanMaximumm(feePercentages: [UFix64]) {
        var sum: UFix64 = 0.0
        for percentage in feePercentages {
            sum = sum + percentage
        }
        return sum <= 100
    }

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

        self.auctions = {
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