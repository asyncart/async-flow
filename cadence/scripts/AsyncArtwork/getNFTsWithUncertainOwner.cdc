import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

// Get AsyncArtwork nfts held by a user
pub fun main(): [UInt64] {
  let allNFTs = AsyncArtwork.getAllNFTs()
  let nftIdsWithUncertainOwner: [UInt64] = []
  for nft in allNFTs {
    if nft.owner != nil {
      let metadataOwner = nft.owner!
      let metadataOwnerAccount = getAccount(metadataOwner)
      let metadataOwnerAsyncCollectionPublic = metadataOwnerAccount.getCapability<&{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() ?? panic("Could not borrow reference to user's collection")
      if !metadataOwnerAsyncCollectionPublic.getIDs().contains(nft.id) || metadataOwnerAsyncCollectionPublic.borrowNFT(id: nft.id).id != nft.id {
        nftIdsWithUncertainOwner.append(nft.id)
      }
    }
  }
  return nftIdsWithUncertainOwner
}