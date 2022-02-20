import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

pub fun main(id: UInt64): {UInt64: AsyncArtwork.ControlLever} {
    return AsyncArtwork.getNFTMetadata(tokenId: id).getLevers()
}