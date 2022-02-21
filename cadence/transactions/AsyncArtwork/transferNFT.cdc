import AsyncArtwork from "../../contracts/AsyncArtwork.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

transaction(
    id: UInt64,
    recipient: Address
) {
    let sender: &AsyncArtwork.Collection
    let receiver: &{NonFungibleToken.CollectionPublic}

    prepare(acct: AuthAccount) {
        self.sender = acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) ?? panic("Could not borrow Collection resource")
        let receiverAccount = getAccount(recipient)
        self.receiver = receiverAccount.getCapability<&{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath).borrow() 
            ?? panic("Could not borrow reference to recipient collection")
    }

    execute {
        let token <- self.sender.withdraw(withdrawID: id)
        self.receiver.deposit(token: <- token)
    }
}