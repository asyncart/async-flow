import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Get tip balance on AsyncArtwork smart contract
pub fun main(): UFix64 {
    return AsyncArtwork.getTipBalance()
}