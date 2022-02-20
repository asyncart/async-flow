import FungibleToken from "../contracts/FungibleToken.cdc"

pub fun main(user: Address): UFix64 {
    let account = getAccount(user)
    let vault = account.getCapability<&{FungibleToken.Balance}>(/public/flowTokenBalance).borrow() ?? panic("Could not borrow reference to user's vault")
    return vault.balance
}