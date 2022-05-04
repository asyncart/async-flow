from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction, send_transaction
from script_handler import send_blueprints_script_and_return_result, send_script_and_return_result
from event_handler import check_for_event, check_for_n_event_occurences_over_x_blocks
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_begin_sale import begin_sale
from test_unit_purchase_blueprints import purchase_blueprints

@pytest.mark.core
def test_switchboard_blueprint_royalty_single_artist():
  # Deploy contracts
  main()
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # User2 acquires tokens to purchase blueprints
  transfer_flow_token("User2", "110.0", "emulator-account")
  transfer_flow_token("User3", "100.0", "emulator-account")
  setup_async_resources("User1")
  setup_async_resources("User2")
  setup_async_resources("User3")
  setup_async_resources("AsyncArtAccount")
  setup_async_resources("emulator-account")
  assert send_transaction("mintFUSD", args=[["UFix64", "100.0"], ["Address", "0xf8d6e0586b0a20c7"]])

  assert "110.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  # assert on User2's ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User2")], ["UInt64", "0"]])

  # Assert on balances after purchase
  assert "100.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])
  assert "8.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "2.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  # assert that the royalty is as expected
  royalty_result = send_blueprints_script_and_return_result("getNFTRoyalty", args=[["Address", address("User2")], ["UInt64", "0"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x1cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.02500000, description: \"Platform cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/GenericFTReceiver), cut: 0.07500000, description: \"Artist cut\")" in royalty_result

  # Do a Mock secondary sale of User2's NFT on external marketplace in FlowToken
  assert send_transaction("mockMarketplaceTokenSale", args=[["Address", address("User2")], ["String", "A.01cf0e2f2f715450.Blueprints.NFT"], ["UInt64", "0"], ["UFix64", "10.0"], ["String", "A.0ae53cb6e3f42a79.FlowToken.Vault"]])

  # Assert on correct payouts using the switchboard after mock marketplace sale
  assert "109.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User2")]])
  assert "8.75000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "2.25000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("AsyncArtAccount")]])

  # Assert on correct FUSD balances before mock sale of User2's blueprint
  assert "0.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User2")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("AsyncArtAccount")]])

  # Do a Mock secondary sale of User2's NFT on external marketplace in FUSD
  assert send_transaction("mockMarketplaceTokenSale", args=[["Address", address("User2")], ["String", "A.01cf0e2f2f715450.Blueprints.NFT"], ["UInt64", "0"], ["UFix64", "10.0"], ["String", "A.f8d6e0586b0a20c7.FUSD.Vault"]])

   # Assert on correct FUSD balances after mock sale of User2's blueprint
  assert "9.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User2")]])
  assert "0.75000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])
  assert "0.25000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("AsyncArtAccount")]])

if __name__ == '__main__':
  test_switchboard_blueprint_royalty_single_artist()