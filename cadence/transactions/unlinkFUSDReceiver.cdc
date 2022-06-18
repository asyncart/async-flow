// Unlink a user's public capability to their FUSD vault
transaction() {

    prepare(acct: AuthAccount) {
        acct.unlink(/public/fusdReceiver)
    }
}