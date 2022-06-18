import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Get an AsyncArtwork NFT's metadata
pub fun main(id: UInt64): AsyncArtwork.NFTMetadata{AsyncArtwork.NFTMetadataPublic} {
    return AsyncArtwork.getNFTMetadata(tokenId: id)
}