import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import AsyncArtwork from "./AsyncArtwork.cdc"

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

    pub resource MarketPlaceClient {
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
        )

        // createSale
        // makeBid
        // makeCustomBid
        // settleAuction
        // withdrawAuction
        // withdrawBid
        // updateWhitelistedBuyer
        // updateMinimumPrice
        // updateBuyNowPrice
        // takeHighestBid
    }

    pub struct Auction {
        // If this isn't passed on instantiation let's just make this the default value
        // the eth contract sets this to zero, and does a check for zero every time to see if it should instead use the current default
        // we could do that, but seems weird?
        pub var bidIncreasePercentage: UFix64
        pub var auctionBidPeriod: UFix64
        pub var auctionEnd: UFix64
        pub var minPrice: UFix64
        pub var buyNowPrice: UFix64
        pub var nftHighestBid: UFix64
        pub var nftHighestBidder: Address
        pub var nftHighestBidderIdCap: Capability<&MarketUser>
        pub var nftSeller: Address
        pub var nftSellerIdCap: Capability<&MarketUser>

        // I think we might need to ditch the MarketUser authentication capability because of this
        // we need a random user to be able to restrict bidding to an arbitrary account without msg.sender
        // We could do this via the same method that we use with collections
        pub var whitelistedBuyer: Address?
        pub var nftRecipient: Address
        pub var biddingCurrency: String
        pub var feeRecipients: [Address]
        pub var feePercentages: [UFix64]

        // Keep the NFT on the Auction itself?
        // Or define a seperate EscrowCollection?
        access(self) NFT: @NonFungibleToken.NFT?

        init() {
            // init the stuff, waiting to see if there's any extra stuff we need on Auction
            // pull defaults if not specified

        }
    }

    // A mapping of NFT type identifiers (analog of NFT contract addresses on ETH) to {nftIds -> Auctions}
    access(self) let auctions: {String: {UInt64: Auction}}

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

    event SaleCreated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftSeller: Address,
        currency: String,
        buyNowPrice: UFix64,
        whitelistedBuyer: Address,
        feeRecipients: [Address],
        feePercentages: [UFix64]
    );

    event BidMade(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        bidder: Address,
        flowTokenAmount: UFix64,
        currency: Address,
        tokenAmount: UFix64
    );

    event AuctionPeriodUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        auctionEndPeriod: UFix64
    );

    event NFTTransferredAndSellerPaid(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftSeller: Address,
        nftHighestBid: UFix64,
        nftHighestBidder: Address,
        nftRecipient: Address
    );

    event AuctionSettled(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        auctionSettler: Address
    );

    event AuctionWithdrawn(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        nftOwner: Address
    );

    event BidWithdrawn(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        highestBidder: Address
    );

    event WhitelistedBuyerUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newWhitelistedBuyer: Address
    );

    event MinimumPriceUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newMinPrice: UFix64
    );

    event BuyNowPriceUpdated(
        nftTypeIdentifier: String,
        tokenId: UInt64,
        newBuyNowPrice: UFix64
    );

    event HighestBidTaken(
        nftTypeIdentifier: String,
        tokenId: UInt64
    );

    pub event ContractInitialized()

    // skipped isAuctionNotStartedByOwner -> weird name seems obscure, hopefully we can do something better

    access(self) doesAuctionExist(_ nftTypeIdentifier: String, _ tokenId: UInt64): Bool {
        return auctions.containsKey(nftTypeIdentifier) && auctions[nftTypeIdentifier]!.containsKey(tokenId)
    }

    access(self) isAuctionOngoing(_ nftTypeIdentifier: String, _ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }
        let endTime: UFix64 = auctions[nftTypeIdentifier]![tokenId]!.auctionEnd

        // For some reason endTime == 0 means that people are bidding, but the minimum price hasn't been met yet
        // this isn't great. Why not an explicit flag?
        return endTime == 0.0 || endTime > getCurrentBlock().timestamp
    }

    // skipped priceGreaterThanZero -> doesn't seem useful

    access(self) minPriceDoesNotExceedLimit(buyNowPrice: UFix64, minPrice: UFix64): Bool {
        return buyNowPrice == 0.0 || buyNowPrice * (self.maximumMinPricePercentage/100) >= minPrice
    }

    // skipped notNFTSeller, onlyNFTSeller tbd on how we will authenticate stuff

    // @notice: A bid DOES NOT have to meet the "minPrice" to be a valid bid...idk why... but it's true!
    access(self) doesBidMeetRequirements(nftTypeIdentifier: String, tokenId: UFix64, tokenAmount: UFix64): Bool {
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
    access(self) minimumBidMade(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
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

    access(self) areFeePercentagesLessThanMaximumm(feePercentages: [UFix64]) {
        var sum: UFix64 = 0.0
        for percentage in feePercentages {
            sum = sum + percentage
        }
        return sum <= 100
    }

    access(self) isASale(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.buyNowPrice > 0.0 && auction.minPrice == 0.0
    }

    access(self) isWhitelistedSale(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.whitelistedBuyer != nil
    }

    access(self) bidMade(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.nftHighestBid > 0.0
    }

    access(self) isBuyNowPriceMet(_ nftTypeIdentifier: String,_ tokenId: UInt64): Bool {
        pre {
            self.doesAuctionExist(nftTypeIdentifier, tokenId): "Auction does not exist for nft type + tokenId specified"
        }

        let auction: Auction = self.auctions[nftTypeIdentifier]![tokenId]!
        return auction.buyNowPrice > 0.0 && auction.nftHighestBid >= auction.buyNowPrice
    }

    // Getters (waiting to see on platformm default behaviour)

	init() {
        self.defaultBidIncreasePercentage = 0.1
        self.defaultAuctionBidPeriod = 86400.0
        self.minimumSettableIncreasePercentage = 0.1
        self.maximumMinPricePercentage = 80
        emit ContractInitialized()
	}
}