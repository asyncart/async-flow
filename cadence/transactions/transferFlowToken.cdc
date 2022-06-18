import FungibleToken from "../contracts/FungibleToken.cdc"

// Transfers FlowToken from the caller to a recipient
transaction(
    recipient: Address,
    amount: UFix64
) {
    let sender: &{FungibleToken.Provider}
    let receiver: &{FungibleToken.Receiver}

    prepare(acct: AuthAccount) {
        self.sender = acct.borrow<&{FungibleToken.Provider}>(from: /storage/flowTokenVault) ?? panic("Could not borrow Vault resource")
        let receiverAccount = getAccount(recipient)
        self.receiver = receiverAccount.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver).borrow() 
            ?? panic("Could not borrow reference to recipient vault")
    }

    execute {
        self.receiver.deposit(from: <- self.sender.withdraw(amount: amount))
    }
}