import Blueprints from "../../contracts/Blueprints.cdc"

// A transaction to enable any user to acquire the minter resource
transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&Blueprints.Minter>(from: Blueprints.minterStoragePath) == nil {
            let minter <- Blueprints.createMinter()
            acct.save(<- minter, to: Blueprints.minterStoragePath)
        }
    }
}