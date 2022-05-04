import FUSD from "../contracts/FUSD.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"

transaction() {

    prepare(acct: AuthAccount) {
        acct.link<&FUSD.Vault{FungibleToken.Receiver}>(
            /public/fusdReceiver,
            target: /storage/fusdVault
        )
    }
}