from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction, send_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event, check_for_n_event_occurences_over_x_blocks
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_begin_sale import begin_sale
from test_unit_purchase_blueprints import purchase_blueprints

@pytest.mark.core
def test_consume_blueprint_royalties():
  # Deploy contracts
  main()
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # User2 acquires tokens to purchase blueprints
  transfer_flow_token("User2", "100.0", "emulator-account")
  transfer_flow_token("User3", "100.0", "emulator-account")
  setup_async_resources("User2")
  setup_async_resources("User3")

  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  # assert on User2's ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User2")], ["UInt64", "0"]])
  
  # asset that the royalty is as expected
  # expected_royalty_result = "\"0x1cf0e2f2f715450: 2.50000000%,0x179b6b1cb6755e31: 7.50000000%\""
  royalty_result = send_blueprints_script_and_return_result("getNFTRoyalty", args=[["Address", address("User2")], ["UInt64", "0"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/flowTokenReceiver), cut: 0.02500000, description: \"Platform cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/flowTokenReceiver), cut: 0.07500000, description: \"Artist cut\")" in royalty_result

  # After sale has started User2 can purchase again after having claimed
  begin_sale(
    "0",
    "AsyncArtAccount",
    True
  )

  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    True
  )

  setup_async_resources("User1")
  setup_async_resources("AsyncArtAccount")

  # asset that the royalty is as expected
  royalty_result = send_blueprints_script_and_return_result("getNFTRoyalty", args=[["Address", address("User3")], ["UInt64", "1"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.02500000, description: \"Platform cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/GenericFTReceiver), cut: 0.07500000, description: \"Artist cut\")" in royalty_result

  # Assert on behaviour when user with cut does not have royalty receiver but does have FlowToken receiver
  assert send_transaction("unlinkRoyaltyReceiver", signer="User1")
  royalty_result = send_blueprints_script_and_return_result("getNFTRoyalty", args=[["Address", address("User3")], ["UInt64", "1"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.02500000, description: \"Platform cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/flowTokenReceiver), cut: 0.07500000, description: \"Artist cut\")" in royalty_result

  # Assert on behaviour when user with cut does not have royalty receiver or FlowToken receiver
  assert send_transaction("unlinkFlowTokenReceiver", signer="User1")
  royalty_result = send_blueprints_script_and_return_result("getNFTRoyalty", args=[["Address", address("User3")], ["UInt64", "1"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.02500000, description: \"Platform cut\")" in royalty_result
  # this is still returned, but now it can't be used
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/flowTokenReceiver), cut: 0.07500000, description: \"Artist cut\")" in royalty_result
if __name__ == '__main__':
  test_consume_blueprint_royalties()