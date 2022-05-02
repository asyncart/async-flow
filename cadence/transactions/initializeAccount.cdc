import FungibleToken from "../contracts/FungibleToken.cdc"
import FUSD from "../contracts/FUSD.cdc"


transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&FUSD.Vault>(from: /storage/fusdVault) == nil {
            acct.save(<- FUSD.createEmptyVault(), to: /storage/fusdVault)

            acct.link<&FUSD.Vault{FungibleToken.Receiver}>(
                /public/fusdReceiver,
                target: /storage/fusdVault 
            ) ?? panic("Could not link public capability to FUSD receiver")

            acct.link<&FUSD.Vault{FungibleToken.Balance}>(
                /public/fusdBalance,
                target: /storage/fusdVault 
            ) ?? panic("Could not create public capability to FUSD balance")
        }
    }
}