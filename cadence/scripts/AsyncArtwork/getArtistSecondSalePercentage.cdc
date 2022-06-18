import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// return second sale percentage
pub fun main(): UFix64 {
  return AsyncArtwork.artistSecondSalePercentage
}