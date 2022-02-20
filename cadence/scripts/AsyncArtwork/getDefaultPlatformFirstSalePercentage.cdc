import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

pub fun main(): UFix64 {
  return AsyncArtwork.defaultPlatformFirstSalePercentage
}