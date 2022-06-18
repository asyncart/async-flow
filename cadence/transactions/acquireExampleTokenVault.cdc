import FungibleToken from "../contracts/FungibleToken.cdc"
import ExampleToken from "../contracts/ExampleToken.cdc"

// The caller can receive an ExampleToken vault
transaction() {

    prepare(acct: AuthAccount) {
        if acct.borrow<&ExampleToken.Vault>(from: /storage/exampleTokenVault) == nil {

            acct.save(<-ExampleToken.createEmptyVault(), to: /storage/exampleTokenVault)
            
            acct.link<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver, target: /storage/exampleTokenVault) ?? panic("Linking receiver cap unexpectedly failed")

            acct.link<&ExampleToken.Vault{FungibleToken.Balance}>(/public/exampleTokenBalance, target: /storage/exampleTokenVault) ?? panic("Linking balance capability unexpectedly failed")
        }
    }
}