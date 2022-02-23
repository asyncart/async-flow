transaction() {

    prepare(acct: AuthAccount) {
        acct.unlink(/public/flowTokenReceiver)
    }
}