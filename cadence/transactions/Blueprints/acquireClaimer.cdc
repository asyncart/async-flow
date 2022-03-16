import TokenRegistry from "../../contracts/TokenRegistry.cdc"

// A transaction to enable any user to acquire the claimer resource
transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&TokenRegistry.Claimer>(from: TokenRegistry.claimerStoragePath) == nil {
            let claimer <- TokenRegistry.createClaimer()
            acct.save(<- claimer, to: TokenRegistry.claimerStoragePath)
        }
    }
}