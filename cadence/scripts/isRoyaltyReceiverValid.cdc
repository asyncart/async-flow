import FungibleToken from "../contracts/FungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"

pub fun main(user: Address): Bool {
    let account = getAccount(user)
    return account.getCapability<&{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath()).check()
}