import AsyncArtwork from "../contracts/AsyncArtwork.cdc"
import Blueprints from "../contracts/Blueprints.cdc"
import NFTAuction from "../contracts/NFTAuction.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import FungibleTokenSwitchboard from "../contracts/FungibleTokenSwitchboard.cdc"
import FlowToken from "../contracts/FlowToken.cdc"
import FUSD from "../contracts/FUSD.cdc"

// This transaction validates if a user has all the capabilities required to facilitate interaction with the AsyncArtwork protocols
transaction() {
    prepare(acct: AuthAccount) {
        if !acct.getCapability<&AsyncArtwork.Collection{NonFungibleToken.Provider}>(AsyncArtwork.collectionPrivatePath).check() {
            panic("AsyncArtwork.Collection{NonFungibleToken.Provider}>(AsyncArtwork.collectionPrivatePath) unexpectedly not found")
        }

        if !acct.getCapability<&AsyncArtwork.Collection{AsyncArtwork.AsyncCollectionPrivate}>(AsyncArtwork.collectionPrivatePath).check() {
            panic("AsyncArtwork.Collection{AsyncArtwork.AsyncCollectionPrivate}>(AsyncArtwork.collectionPrivatePath) unexpectedly not found")
        }

        if !acct.getCapability<&AsyncArtwork.Collection{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath).check() {
            panic("AsyncArtwork.Collection{NonFungibleToken.CollectionPublic}>(AsyncArtwork.collectionPublicPath) unexpectedly not found")
        }

        if !acct.getCapability<&AsyncArtwork.Collection{NonFungibleToken.Receiver}>(AsyncArtwork.collectionPublicPath).check() {
            panic("AsyncArtwork.Collection{NonFungibleToken.Receiver}>(AsyncArtwork.collectionPublicPath) unexpectedly not found")
        }

        if !acct.getCapability<&AsyncArtwork.Collection{AsyncArtwork.AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath).check() {
            panic("AsyncArtwork.Collection{AsyncArtwork.AsyncCollectionPublic}>(AsyncArtwork.collectionPublicPath) unexpectedly not found")
        }

        if !acct.getCapability<&AsyncArtwork.Collection{MetadataViews.ResolverCollection}>(AsyncArtwork.collectionPublicPath).check() {
            panic("AsyncArtwork.Collection{MetadataViews.ResolverCollection}>(AsyncArtwork.collectionPublicPath) unexpectedly not found")
        }

        if !acct.getCapability<&Blueprints.Collection{NonFungibleToken.Provider}>(Blueprints.collectionPrivatePath).check() {
            panic("Blueprints.Collection{NonFungibleToken.Provider}>(Blueprints.collectionPrivatePath) unexpectedly not found")
        }

        if !acct.getCapability<&Blueprints.Collection{NonFungibleToken.CollectionPublic}>(Blueprints.collectionPublicPath).check() {
            panic("Blueprints.Collection{NonFungibleToken.CollectionPublic}>(Blueprints.collectionPublicPath) unexpectedly not found")
        }

        if !acct.getCapability<&Blueprints.Collection{NonFungibleToken.Receiver}>(Blueprints.collectionPublicPath).check() {
            panic("Blueprints.Collection{NonFungibleToken.Receiver}>(Blueprints.collectionPublicPath) unexpectedly not found")
        }

        if !acct.getCapability<&Blueprints.Collection{MetadataViews.ResolverCollection}>(Blueprints.collectionPublicPath).check() {
            panic("Blueprints.Collection{MetadataViews.ResolverCollection}>(Blueprints.collectionPublicPath) unexpectedly not found")
        }

        if !acct.getCapability<&NFTAuction.MarketplaceClient>(NFTAuction.marketplaceClientPrivatePath).check() {
            panic("NFTAuction.MarketplaceClient>(NFTAuction.marketplaceClientPrivatePath) unexpectedly not found")
        }

        if !acct.getCapability<&NFTAuction.MarketplaceClient>(NFTAuction.marketplaceClientPublicPath).check() {
            panic("NFTAuction.MarketplaceClient>(NFTAuction.marketplaceClientPublicPath) unexpectedly not found")
        }
    }
}