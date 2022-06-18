import NFTAuction from "../../contracts/NFTAuction.cdc"

// Get an NFTAuction auction
pub fun main(nftTypeIdentifier: String, id: UInt64): NFTAuction.Auction{NFTAuction.AuctionPublic}? {
    return NFTAuction.getAuction(nftTypeIdentifier, id)
}