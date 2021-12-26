import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

transaction(
    newArtistSecondSalePercentage: UFix64, 
) {
    var asyncAdminCap: Capability<&AsyncArtwork.Admin>

    prepare(acct: AuthAccount) {
        self.asyncAdminCap = acct.getCapability<&AsyncArtwork.Admin>(AsyncArtwork.adminPrivatePath)
    }

    execute {
        let asyncAdmin = self.asyncAdminCap.borrow() ?? panic("Could not borrow reference to admin")
        asyncAdmin.updateArtistSecondSalePercentage(
            artistSecondSalePercentage: newArtistSecondSalePercentage
        )
    }
}
