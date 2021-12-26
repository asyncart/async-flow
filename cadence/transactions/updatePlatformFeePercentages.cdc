import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

transaction(
    platformFirstPercentage: UFix64, 
    platformSecondPercentage: UFix64,
) {
    var asyncAdminCap: Capability<&AsyncArtwork.Admin>

    prepare(acct: AuthAccount) {
        self.asyncAdminCap = acct.getCapability<&AsyncArtwork.Admin>(AsyncArtwork.adminPrivatePath)
    }

    execute {
        let asyncAdmin = self.asyncAdminCap.borrow() ?? panic("Could not borrow reference to admin")
        asyncAdmin.updateDefaultPlatformSalesPercentage(
            platformFirstSalePercentage: platformFirstPercentage,
            platformSecondSalePercentage: platformSecondPercentage
        )
    }
}
