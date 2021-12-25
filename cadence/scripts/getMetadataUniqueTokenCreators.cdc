import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

pub fun main(id: UInt64): [Address] {
    return AsyncArtwork.getNFTMetadata(tokenId: id).getUniqueTokenCreators()
}