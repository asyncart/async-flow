transaction() {

    prepare(acct: AuthAccount) {
        acct.unlink(/public/fusdReceiver)
    }
}