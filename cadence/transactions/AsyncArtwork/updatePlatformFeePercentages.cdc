import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"

// Update the default second sale percentage going to the platform on AsyncArtwork
transaction(
    platformSecondPercentage: UFix64
) {
    var asyncAdminCap: Capability<&AsyncArtwork.Admin>

    prepare(acct: AuthAccount) {
        self.asyncAdminCap = acct.getCapability<&AsyncArtwork.Admin>(AsyncArtwork.adminPrivatePath)
    }

    execute {
        let asyncAdmin = self.asyncAdminCap.borrow() ?? panic("Could not borrow reference to admin")
        asyncAdmin.updateDefaultPlatformSalesPercentage(
            platformSecondSalePercentage: platformSecondPercentage
        )
    }
}
