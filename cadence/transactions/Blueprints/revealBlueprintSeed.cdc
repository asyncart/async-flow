import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for the minter to reveal the seed of a given blueprint (via an event emitted by the contract iff the provided seed matches an existing seed on contract)
transaction(
    blueprintID: UInt64,
    randomSeed: String
) {

    prepare(acct: AuthAccount) {
        let senderMinterRef: &Blueprints.Minter = acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath)
        if senderMinterRef == nil {
            panic("Coulf not borrow reference to blueprints minter resource")
        }

        senderMinterRef.revealBlueprintSeed(
            blueprintID: blueprintID,
            randomSeed: randomSeed
        )
    }
}