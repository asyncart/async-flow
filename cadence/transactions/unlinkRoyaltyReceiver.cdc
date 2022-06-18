import MetadataViews from "../contracts/MetadataViews.cdc"

// Unlink a user's public capability to their royalty receiver resource
transaction() {

    prepare(acct: AuthAccount) {
        acct.unlink(MetadataViews.getRoyaltyReceiverPublicPath())
    }
}