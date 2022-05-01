import Blueprints from "../../contracts/Blueprints.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import MetadataViews from "../../contracts/MetadataViews.cdc"
import FungibleTokenSwitchboard from "../../contracts/FungibleTokenSwitchboard.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
import FUSD from "../../contracts/FUSD.cdc"

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

        // also setup generic FT receiver switchboard
        let switchboardReceiver = acct.getCapability<&{FungibleToken.Receiver, FungibleTokenSwitchboard.SwitchboardPublic}>(MetadataViews.getRoyaltyReceiverPublicPath())
        if switchboardReceiver == nil || !switchboardReceiver.check() {
            if acct.borrow<&FungibleTokenSwitchboard.Switchboard>(from: FungibleTokenSwitchboard.SwitchboardStoragePath) == nil {
                let switchboard <- FungibleTokenSwitchboard.createNewSwitchboard()
                acct.save(<- switchboard, to: FungibleTokenSwitchboard.SwitchboardStoragePath)
            }

            // link public interface to switchboard at expected path
            acct.link<&{FungibleTokenSwitchboard.SwitchboardPublic}>(
                FungibleTokenSwitchboard.SwitchboardPublicPath,
                target: FungibleTokenSwitchboard.SwitchboardStoragePath
            )

            // link public receiver interface at generic FT receiver path
            acct.link<&{FungibleToken.Receiver}>(
                MetadataViews.getRoyaltyReceiverPublicPath(),
                target: FungibleTokenSwitchboard.SwitchboardStoragePath
            )

            // link private switchboard interface at expected path
            acct.link<&{FungibleTokenSwitchboard.SwitchboardAdmin}>(
                FungibleTokenSwitchboard.SwitchboardPrivatePath,
                target: FungibleTokenSwitchboard.SwitchboardStoragePath
            )

            // initialize switchboard with FUSDToken and FUSD support
            let switchboardRef = acct.getCapability<&{FungibleTokenSwitchboard.SwitchboardAdmin}>(FungibleTokenSwitchboard.SwitchboardPrivatePath).borrow() 
                ?? panic("Somehow did not save private capability to switchboard")
            
            var FlowTokenReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            if !FlowTokenReceiver.check() {
                // user did not have FlowToken receiver at expected path, handle by giving them vault / receiver
                if acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
                    acct.save(<- FlowToken.createEmptyVault(), to: /storage/flowTokenVault)
                }

                acct.link<&FlowToken.Vault{FungibleToken.Receiver}>(
                    /public/flowTokenReceiver,
                    target: /storage/flowTokenVault
                )
                
                FlowTokenReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            } 
            switchboardRef.setVaultRecipient(FlowTokenReceiver, vaultType: FlowTokenReceiver.borrow()!.getType())
            
            var FUSDTokenReceiver = acct.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
            if !FUSDTokenReceiver.check() {
                // user did not have FUSD receiver at expected path, handle by giving them vault / receiver
                if acct.borrow<&FUSD.Vault>(from: /storage/fusdVault) == nil {
                    acct.save(<- FUSD.createEmptyVault(), to: /storage/fusdVault)
                }

                acct.link<&FUSD.Vault{FungibleToken.Receiver}>(
                    /public/fusdReceiver,
                    target: /storage/fusdVault
                )
                
                FUSDTokenReceiver = acct.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
            }
            switchboardRef.setVaultRecipient(FUSDTokenReceiver, vaultType: FUSDTokenReceiver.borrow()!.getType())
        }
    }
}