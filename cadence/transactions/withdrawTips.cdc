import AsyncArtwork from "../contracts/AsyncArtwork.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"

transaction(recipient: Address) {
    let admin: &AsyncArtwork.Admin
    let vault: &{FungibleToken.Receiver}

    prepare(acct: AuthAccount) {
        self.admin = acct.borrow<&AsyncArtwork.Admin>(from: AsyncArtwork.adminStoragePath) ?? panic("Could not borrow Admin resource")
        
        let recipientAccount = getAccount(recipient)
        self.vault = recipientAccount.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver).borrow() 
            ?? panic("Could not borrow reference to recipient vault")
    }

    execute {
        self.vault.deposit(from: <- self.admin.withdrawTips())
    }
}