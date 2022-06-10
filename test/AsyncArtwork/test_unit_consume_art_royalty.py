from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction, send_transaction
from script_handler import send_async_artwork_script_and_return_result
from event_handler import check_for_event
from metadata_handler import result_equals_expected_metadata
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token


@pytest.mark.core
def test_consume_art_royalty():
  # Deploy contracts
  main()

  setup_async_resources("User1")
  setup_async_resources("User2")
  setup_async_resources("User3")
  setup_async_resources("AsyncArtAccount")

  whitelist(
    ["User1", "1", "2", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 2}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformSecondSalePercentage: 0.01000000, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))
  mint_master_token(
    ["1", "<uri>", ["User2", "User3"], ["User2"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # Assert on standard behaviour (user with cut has royalty receiver)
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "1"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0xf3fcd2c1a78f5eee, path: /public/GenericFTReceiver), cut: 0.10000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.01000000, description: \"Platform (asyncSaleFeesRecipient) cut\")" in royalty_result

  whitelist(
    ["User1", "4", "1", None],
    "AsyncArtAccount",
    True,
    "{4: 1}"
  )

  mint_master_token(
    ["4", "<uri>", ["User3"], ["User2", "User1"]],
    "User1",
    True
  )

  # Assert on standard behaviour (user with cut has royalty receiver)
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "4"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0xf3fcd2c1a78f5eee, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Platform (asyncSaleFeesRecipient) cut\")" in royalty_result

  # Assert on behaviour when user with cut does not have royalty receiver but does have FlowToken receiver
  assert send_transaction("unlinkRoyaltyReceiver", signer="User2")
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "4"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0xf3fcd2c1a78f5eee, path: /public/flowTokenReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Platform (asyncSaleFeesRecipient) cut\")" in royalty_result

  # Assert on behaviour when user with cut does not have royalty receiver but does have FlowToken receiver
  assert send_transaction("unlinkFlowTokenReceiver", signer="User2")
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "4"]])
  # This capability is now invalid though, but it still is returned
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0xf3fcd2c1a78f5eee, path: /public/flowTokenReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Platform (asyncSaleFeesRecipient) cut\")" in royalty_result

  # Assert on behaviour when AsyncArtAccount unlinks switchboard
  assert send_transaction("unlinkRoyaltyReceiver", signer="AsyncArtAccount")
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "4"]])
  # This capability is now invalid though, but it still is returned
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0xf3fcd2c1a78f5eee, path: /public/flowTokenReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/flowTokenReceiver), cut: 0.05000000, description: \"Platform (asyncSaleFeesRecipient) cut\")" in royalty_result

if __name__ == '__main__':
    test_consume_art_royalty()