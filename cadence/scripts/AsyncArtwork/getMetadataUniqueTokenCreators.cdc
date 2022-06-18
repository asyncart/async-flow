import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Get the unique token creators on an AsyncArtwork NFT's metadata
pub fun main(id: UInt64): [Address] {
    return AsyncArtwork.getNFTMetadata(tokenId: id).getUniqueTokenCreators()
}