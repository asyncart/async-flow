from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_begin_sale import begin_sale
from test_unit_purchase_blueprints import purchase_blueprints

# arg:
# blueprintID: UInt64
def pause_sale(arg, signer, should_succeed):
  formatted_args = [["UInt64", arg]]
  
  if should_succeed:
    assert send_blueprints_transaction("pauseSale", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.SalePaused'
    assert check_for_event(event)
    print("Successfully Paused Sale for Blueprint")
  else:
    assert not send_blueprints_transaction("pauseSale", args=formatted_args, signer=signer)
    print("Failed to Pause Sale for Blueprint As Expected")

@pytest.mark.core
def test_pause_sale():
  # Deploy contracts
  main()

  # User3 and User4 acquire tokens to purchase blueprints
  transfer_flow_token("User3", "100.0", "emulator-account")
  transfer_flow_token("User4", "100.0", "emulator-account")

  # Setup blueprints users
  setup_async_resources("User3")
  setup_async_resources("User4")
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", [], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  # User3 cannot purchase blueprints before sale has started 
  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    False
  )

  begin_sale(
    "0",
    "AsyncArtAccount",
    True
  )

  # User3 can purchase blueprints after sale has started
  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    True
  )

  # Undesignated account cannot pause sale
  pause_sale(
    "0",
    "User1",
    False
  )

  pause_sale(
    "0",
    "AsyncArtAccount",
    True
  )

  # User4 cannot purchase blueprints after sale is paused
  purchase_blueprints(
    ["0", "1", "User4"],
    "User4",
    False
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state has changed after update
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 4, nftIndex: 1, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 2), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

if __name__ == '__main__':
  test_pause_sale()