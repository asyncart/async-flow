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
from test_unit_pause_sale import pause_sale
from test_unit_purchase_blueprints import purchase_blueprints

# arg:
# blueprintID: UInt64
def unpause_sale(arg, signer, should_succeed):
  formatted_args = [["UInt64", arg]]
  
  if should_succeed:
    assert send_blueprints_transaction("unpauseSale", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.SaleUnpaused'
    assert check_for_event(event)
    print("Successfully Unpaused Sale for Blueprint")
  else:
    assert not send_blueprints_transaction("unpauseSale", args=formatted_args, signer=signer)
    print("Failed to Unpause Sale for Blueprint As Expected")

@pytest.mark.core
def test_unpause_sale():
  # Deploy contracts
  main()
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", [], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # Setup User2 to purchase tokens
  setup_async_resources("User2")
  transfer_flow_token("User2", "100.0", "emulator-account")

  begin_sale(
    "0",
    "AsyncArtAccount",
    True
  )

  # User2 can purchase token after sale begins
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  pause_sale(
    "0",
    "AsyncArtAccount",
    True
  )

  # User2 cannot purchase token after sale is paused
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    False
  )

  unpause_sale(
    "0",
    "AsyncArtAccount",
    True
  )

  # User2 can purchase token after sale is unpaused
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  # Cannot unpause a sale for a non-existent blueprint
  unpause_sale(
    "1",
    "AsyncArtAccount",
    False
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state is set back to sale started
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 3, nftIndex: 2, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 1), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

if __name__ == '__main__':
  test_unpause_sale()