// Simulate a time delay on the network for testing purposes
transaction() {
    prepare(acct: AuthAccount) {}

    execute {
        var x = 0
        while x < 300 {
            x = x + 1
        }
    }
}