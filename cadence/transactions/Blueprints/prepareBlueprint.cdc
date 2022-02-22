import Blueprints from "../../contracts/Blueprints.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// Txn for the minter to establish a new blueprint by specifying its parameters but not minting any tokens
transaction(
    artist: Address,
    capacity: UInt64,
    price: UFix64,
    currency: String,
    blueprintMetadata: String,
    baseTokenUri: String,
    initialWhitelist: [Address],
    mintAmountArtist: UInt64,
    mintAmountPlatform: UInt64,
    maxPurchaseAmount: UInt64?
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath) ?? panic("Could not borrow minter!")

        senderMinterRef!
        .prepareBlueprint(
            _artist: artist,
            _capacity: capacity,
            _price: price,
            _currency: currency,
            _blueprintMetadata: blueprintMetadata,
            _baseTokenUri: baseTokenUri,
            _initialWhitelist: initialWhitelist,
            _mintAmountArtist: mintAmountArtist,
            _mintAmountPlatform: mintAmountPlatform,
            _maxPurchaseAmount: maxPurchaseAmount 
        )
    }
}