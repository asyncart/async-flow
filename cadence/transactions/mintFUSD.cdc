import FungibleToken from "../contracts/FungibleToken.cdc"
import FUSD from "../contracts/FUSD.cdc"

// Lets the holder of the FUSD minter resource mint more FUSD
transaction(amount: UFix64, receiver: Address) {
    let fusdAdmin: &FUSD.Administrator
    let fusdReceiver: &{FungibleToken.Receiver}

    prepare(acct: AuthAccount) {
        self.fusdAdmin = acct.borrow<&FUSD.Administrator>(from: /storage/fusdAdmin) ?? panic("Signer is not an FUSD Admin")

        self.fusdReceiver = getAccount(receiver).getCapability(/public/fusdReceiver).borrow<&{FungibleToken.Receiver}>() ?? panic("Cannot borrow reference to receiver's FUSD FT receiver")
    }

    execute {
        let fusdMinter <- self.fusdAdmin.createNewMinter()
        let mintedVault <- fusdMinter.mintTokens(amount: amount)
        self.fusdReceiver.deposit(from: <-mintedVault)
        destroy fusdMinter
    }
}