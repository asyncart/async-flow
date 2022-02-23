import Blueprints from "../../contracts/Blueprints.cdc"

// Mint a certain number of NFTs corresponding to a certain blueprint before it's sale starts
// Will only succeed for the minter or designated whitelisted users for the blueprint
// failure occurs at the contract level
transaction(blueprintID: UInt64, quantity: UInt64) {

    prepare(acct: AuthAccount) {
        let senderClientRef: &Blueprints.BlueprintsClient = acct.borrow<&Blueprints.BlueprintsClient>(from: Blueprints.blueprintsClientStoragePath) ?? panic("Could not borrow client resource")

        senderClientRef.presaleMint(
            blueprintID: blueprintID,
            quantity: quantity
        )
    }
}