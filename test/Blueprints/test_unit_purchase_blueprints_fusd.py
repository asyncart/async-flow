from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction, send_transaction
from script_handler import send_blueprints_script_and_return_result, send_script_and_return_result
from event_handler import check_for_event, check_for_n_event_occurences_over_x_blocks
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_begin_sale import begin_sale
from test_unit_purchase_blueprints import purchase_blueprints

@pytest.mark.core
def test_purchase_blueprints_fusd():
  # Deploy contracts
  main()
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.f8d6e0586b0a20c7.FUSD.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.f8d6e0586b0a20c7.FUSD.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  assert send_transaction("initializeAccount", signer="User1")
  assert send_transaction("initializeAccount", signer="User2")
  assert send_transaction("initializeAccount", signer="User3")
  assert send_transaction("initializeAccount", signer="AsyncArtAccount")
  assert send_transaction("mintFUSD", args=[["UFix64", "100.0"], ["Address", address("User2")]])
  assert send_transaction("mintFUSD", args=[["UFix64", "100.0"], ["Address", address("User3")]])
  setup_blueprints_user("User2")
  setup_blueprints_user("User3")

  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  # assert on User2's ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User2")], ["UInt64", "0"]])
  
  # assert on User2's balance
  assert "90.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User2")]])
  
  # assert on Async's balance
  assert "2.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("AsyncArtAccount")]])

  # assert on User1's balace
  assert "8.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])

  # User2 cannot purchase anymore as they were whitelisted, and have claimed their spot via the whitelist
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    False
  )

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

  # assert on User2's ownership of the NFTs
  assert "id: 1" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User3")], ["UInt64", "1"]])
  
  # assert on User3's balance
  assert "90.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User3")]])
  
  # assert on Async's balance
  assert "4.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("AsyncArtAccount")]])

  # assert on User1's balace
  assert "16.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])

  # User cannot purchase more than the max purchase amount
  purchase_blueprints(
    ["0", "3", "User2"],
    "User2",
    False
  )

  # Cannot purchase tokens after capacity runs out
  purchase_blueprints(
    ["0", "2", "User2"],
    "User2",
    True
  )

  purchase_blueprints(
    ["0", "2", "User2"],
    "User2",
    False
  )

if __name__ == '__main__':
  test_purchase_blueprints_fusd()