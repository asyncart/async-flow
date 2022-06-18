// Unlink a user's public capability to their FlowToken vault
transaction() {

    prepare(acct: AuthAccount) {
        acct.unlink(/public/flowTokenReceiver)
    }
}