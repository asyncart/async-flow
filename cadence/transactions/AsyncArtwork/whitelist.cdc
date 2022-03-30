import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

transaction(
    creatorAddress: Address,
    masterTokenId: UInt64,
    layerCount: UInt64,
    platformSecondSalePercentage: UFix64?
) {
    let minter: &AsyncArtwork.Minter

    prepare(acct: AuthAccount) {
        self.minter = acct.borrow<&AsyncArtwork.Minter>(from: AsyncArtwork.minterStoragePath) ?? panic("Could not borrow Minter resource")
    }

    execute {
        self.minter.whitelistTokenForCreator(
            creatorAddress: creatorAddress,
            masterTokenId: masterTokenId,
            layerCount: layerCount,
            platformSecondSalePercentage: platformSecondSalePercentage
        )
    }
}