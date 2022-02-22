import Blueprints from "../../contracts/Blueprints.cdc"

// Txn for Async to move the platform resource to another account
transaction() {
    prepare(mover: AuthAccount, receiver: AuthAccount) {
        let platform <- mover.load<@Blueprints.Platform>(from: Blueprints.platformStoragePath) ?? panic("Could not find Platform resource in mover account")

        receiver.save(<-platform, to: Blueprints.platformStoragePath)

        log("Moved Platform")
    }
}