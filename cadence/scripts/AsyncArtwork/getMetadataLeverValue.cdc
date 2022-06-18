import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Get an AsyncArtwork NFT's lever value for a specific lever
pub fun main(tokenId: UInt64, leverId: UInt64): Int64 {
    return AsyncArtwork.getNFTMetadata(tokenId: tokenId).getLeverValue(id: leverId)
}