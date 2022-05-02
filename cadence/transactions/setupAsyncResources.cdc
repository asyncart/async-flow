import AsyncArtwork from "../contracts/AsyncArtwork.cdc"
import Blueprints from "../contracts/Blueprints.cdc"
import NFTAuction from "../contracts/NFTAuction.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import FungibleTokenSwitchboard from "../contracts/FungibleTokenSwitchboard.cdc"
import FlowToken from "../contracts/FlowToken.cdc"
import FUSD from "../contracts/FUSD.cdc"

transaction() {
    prepare(acct: AuthAccount) {

        // setup async artwork collection
        if acct.borrow<&AsyncArtwork.Collection>(from: AsyncArtwork.collectionStoragePath) == nil {
            let collection <- AsyncArtwork.createEmptyCollection()
            acct.save(<- collection, to: AsyncArtwork.collectionStoragePath)

            acct.link<&AsyncArtwork.Collection{NonFungibleToken.Provider, AsyncArtwork.AsyncCollectionPrivate}>(
                AsyncArtwork.collectionPrivatePath,
                target: AsyncArtwork.collectionStoragePath
            )

            acct.link<&AsyncArtwork.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, AsyncArtwork.AsyncCollectionPublic, MetadataViews.ResolverCollection}>(
                AsyncArtwork.collectionPublicPath,
                target: AsyncArtwork.collectionStoragePath
            )
        }

        // setup blueprints collection
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

        // setup blueprints client
        if acct.borrow<&Blueprints.BlueprintsClient>(from: Blueprints.blueprintsClientStoragePath) == nil {
            let clientResource <- Blueprints.createBlueprintsClient()
            acct.save(<- clientResource, to: Blueprints.blueprintsClientStoragePath)
        }

        // setup nft auction marketplace client
        if acct.borrow<&NFTAuction.MarketplaceClient>(from: NFTAuction.marketplaceClientStoragePath) == nil {
            let marketplaceClient <- NFTAuction.createMarketplaceClient()
            acct.save(<- marketplaceClient, to: NFTAuction.marketplaceClientStoragePath)

            acct.link<&NFTAuction.MarketplaceClient>(
                NFTAuction.marketplaceClientPrivatePath,
                target: NFTAuction.marketplaceClientStoragePath
            )

            acct.link<&NFTAuction.MarketplaceClient>(
                NFTAuction.marketplaceClientPublicPath,
                target: NFTAuction.marketplaceClientStoragePath
            )
        }
        
        // setup generic FT receiver switchboard
        if acct.borrow<&FungibleTokenSwitchboard.Switchboard>(from: FungibleTokenSwitchboard.SwitchboardStoragePath) == nil {
            acct.save(<- FungibleTokenSwitchboard.createNewSwitchboard(), to: FungibleTokenSwitchboard.SwitchboardStoragePath)
        }

        let switchboardPublic = acct.getCapability<&{FungibleTokenSwitchboard.SwitchboardPublic}>(MetadataViews.getRoyaltyReceiverPublicPath())
        if switchboardPublic == nil || !switchboardPublic.check() {
            // link public interface to switchboard at expected path
            acct.link<&{FungibleTokenSwitchboard.SwitchboardPublic}>(
                FungibleTokenSwitchboard.SwitchboardPublicPath,
                target: FungibleTokenSwitchboard.SwitchboardStoragePath
            )

            // link private switchboard interface at expected path
            acct.link<&{FungibleTokenSwitchboard.SwitchboardAdmin}>(
                FungibleTokenSwitchboard.SwitchboardPrivatePath,
                target: FungibleTokenSwitchboard.SwitchboardStoragePath
            )
        }

        let switchboardReceiver = acct.getCapability<&{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath())
        if switchboardReceiver == nil || !switchboardReceiver.check() {
            // link public receiver interface at generic FT receiver path
            acct.link<&{FungibleToken.Receiver}>(
                MetadataViews.getRoyaltyReceiverPublicPath(),
                target: FungibleTokenSwitchboard.SwitchboardStoragePath
            )

            // initialize switchboard with FUSDToken and FUSD support
            let switchboardRef = acct.getCapability<&{FungibleTokenSwitchboard.SwitchboardAdmin}>(FungibleTokenSwitchboard.SwitchboardPrivatePath).borrow() 
                ?? panic("Private capability to switchboard not found")
            
            var FlowTokenReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            if !FlowTokenReceiver.check() {
                // user did not have FlowToken receiver at expected path, handle by giving them vault / receiver
                if acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
                    acct.save(<- FlowToken.createEmptyVault(), to: /storage/flowTokenVault)
                }

                acct.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(
                    /public/flowTokenReceiver,
                    target: /storage/flowTokenVault
                )

                acct.link<&FlowToken.Vault{FungibleToken.Balance}>(
                    /public/flowTokenBalance,
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

                acct.link<&FUSD.Vault{FungibleToken.Balance}>(
                    /public/fusdBalance,
                    target: /storage/fusdVault
                )
                
                FUSDTokenReceiver = acct.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
            }
            switchboardRef.setVaultRecipient(FUSDTokenReceiver, vaultType: FUSDTokenReceiver.borrow()!.getType())
        }
    }
}