import NFTAuction from "../../contracts/NFTAuction.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import MetadataViews from "../../contracts/MetadataViews.cdc"
import FungibleTokenSwitchboard from "../../contracts/FungibleTokenSwitchboard.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
import FUSD from "../../contracts/FUSD.cdc"

transaction() {
    prepare(acct: AuthAccount) {
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

        // also setup generic FT receiver switchboard
        let switchboardReceiver = acct.getCapability<&{FungibleToken.Receiver, FungibleTokenSwitchboard.SwitchboardPublic}>(MetadataViews.getRoyaltyReceiverPublicPath())
        if switchboardReceiver == nil || !switchboardReceiver.check() {
            let switchboard <- FungibleTokenSwitchboard.createNewSwitchboard()
            acct.save(<- switchboard, to: FungibleTokenSwitchboard.SwitchboardStoragePath)

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
            let switchboard <- acct.getCapability<&{FungibleTokenSwitchboard.SwitchboardAdmin}>(FungibleTokenSwitchboard.SwitchboardPrivatePath).borrow() 
                ?? panic("Somehow did not save private capability to switchboard")
            
            let FlowTokenReceiver <- acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            if !FlowTokenReceiver.check() {
                // user did not have FlowToken receiver at expected path, handle by giving them vault / receiver
                if acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
                    acct.save(<- FlowToken.createEmptyVault())
                }

                acct.link<&FlowToken.Vault{FungibleToken.Receiver}>(
                    /public/flowTokenReceiver,
                    target: /storage/flowTokenVault
                )
                
                FlowTokenReceiver <- acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            } 
            switchboard.setVaultRecipient(FlowTokenReceiver, vaultType: FlowTokenReceiver.borrow()!.getType())
            
            let FUSDTokenReceiver <- acct.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
            if !FUSDTokenReceiver.check() {
                // user did not have FUSD receiver at expected path, handle by giving them vault / receiver
                if acct.borrow<&FUSD.Vault>(from: /storage/fusdVault) == nil {
                    acct.save(<- FUSD.createEmptyVault())
                }

                acct.link<&FUSD.Vault{FungibleToken.Receiver}>(
                    /public/fusdReceiver,
                    target: /storage/fusdVault
                )
                
                FlowTokenReceiver <- acct.getCapability<&FlowToken.Vault{FUSD.Receiver}>(/public/fusdReceiver)
            }
            switchboard.setVaultRecipient(FUSDTokenReceiver, vaultType: FUSDTokenReceiver.borrow()!.getType())
        }
    }
}