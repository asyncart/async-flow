import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

pub fun main(id: UInt64): AsyncArtwork.NFTMetadata{AsyncArtwork.NFTMetadataPublic} {
    return AsyncArtwork.getNFTMetadata(tokenId: id)
}