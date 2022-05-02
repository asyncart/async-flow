import MetadataViews from "../contracts/MetadataViews.cdc"

transaction() {

    prepare(acct: AuthAccount) {
        acct.unlink(MetadataViews.getRoyaltyReceiverPublicPath())
    }
}