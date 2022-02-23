import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to update the uri associated with a given blueprint
transaction(
    blueprintID: UInt64,
    newBaseTokenUri: String
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath) ?? panic("Could not borrow minter resource")

        senderMinterRef!.updateBlueprintTokenUri(
            blueprintID: blueprintID,
            newBaseTokenUri: newBaseTokenUri
        )
    }
}