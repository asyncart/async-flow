import FungibleToken from "../contracts/FungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"

// Checks if a royalty receiver from MetadataViews is valid
pub fun main(user: Address): Bool {
    let account = getAccount(user)
    return account.getCapability<&{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath()).check()
}