import AsyncArtworkV2 from "../contracts/AsyncArtworkV2.cdc"

transaction() {
    prepare(acct: AuthAccount) {}

    execute {
        AsyncArtworkV2.increment()
        log("Incremented counter")
    }
}
