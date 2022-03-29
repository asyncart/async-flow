import Blueprints from "../../contracts/Blueprints.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import MetadataViews from "../../contracts/MetadataViews.cdc"

transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&Blueprints.Collection>(from: Blueprints.collectionStoragePath) == nil {
            let collection <- Blueprints.createEmptyCollection()
            acct.save(<- collection, to: Blueprints.collectionStoragePath)

            acct.link<&Blueprints.Collection{NonFungibleToken.Provider}>(
                Blueprints.collectionPrivatePath,
                target: Blueprints.collectionStoragePath
            )

            acct.link<&Blueprints.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(
                Blueprints.collectionPublicPath,
                target: Blueprints.collectionStoragePath
            )
        }

        if acct.borrow<&Blueprints.BlueprintsClient>(from: Blueprints.blueprintsClientStoragePath) == nil {
            let clientResource <- Blueprints.createBlueprintsClient()
            acct.save(<- clientResource, to: Blueprints.blueprintsClientStoragePath)
        }
    }
}