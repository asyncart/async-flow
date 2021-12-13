import AsyncArtwork from "../contracts/AsyncArtwork.cdc"

pub fun main(accountAddress: Address, expectedId: UInt64): Bool {
    let user = getAccount(accountAddress).getCapability<&AsyncArtwork.AsyncUser>(AsyncArtwork.asyncUserPublicPath).borrow() ?? panic("Could not borrow reference to Async user")
    return user.id == expectedId
}