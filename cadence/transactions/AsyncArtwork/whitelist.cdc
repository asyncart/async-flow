import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

// This is the transaction the platform (AsyncArtwork) runs to let creators mint a master token and reserve layers for control tokens
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