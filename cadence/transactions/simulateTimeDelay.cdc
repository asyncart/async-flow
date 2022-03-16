transaction() {
    prepare(acct: AuthAccount) {}

    execute {
        var x = 0
        while x < 300 {
            x = x + 1
        }
    }
}