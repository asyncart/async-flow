import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Get the AsyncArtwork contract's default second sale cut that goes to the platform
pub fun main(): UFix64 {
  return AsyncArtwork.defaultPlatformSecondSalePercentage
}