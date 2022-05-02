from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_purchase_blueprints import purchase_blueprints

# arg:
# blueprintID
# array of addresses to add
def add_to_whitelist(blueprintID, args, signer, should_succeed):
  formatted_args = [["Array",[["Address", address(user)] for user in args]]]
  formatted_args.insert(0, ["UInt64", blueprintID])
  
  if should_succeed:
    assert send_blueprints_transaction("addToBlueprintWhitelist", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.BlueprintWhitelistUpdated'
    assert check_for_event(event)
    print("Successfully Added Addresses to Whitelist for Blueprint")
  else:
    assert not send_blueprints_transaction("addToBlueprintWhitelist", args=formatted_args, signer=signer)
    print("Failed to Add Addresses to Whitelist As Expected")

@pytest.mark.core
def test_add_to_whitelist():
  # Deploy contracts
  main()
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  # User3 and User4 acquire tokens to purchase blueprints
  transfer_flow_token("User3", "100.0", "emulator-account")
  transfer_flow_token("User4", "100.0", "emulator-account")

  # Setup blueprints users
  setup_async_resources("User3")
  setup_async_resources("User4")

  # User3 should not be able to purchase blueprints
  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    False
  )

  # User4 should not be able to purchase blueprints
  purchase_blueprints(
    ["0", "1", "User4"],
    "User4",
    False
  )

  add_to_whitelist(
    "0",
    ["User3", "User4"],
    "AsyncArtAccount",
    True
  )

  # User3 should be able to purchase blueprints
  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    True
  )

  # User4 should be able to purchase blueprints
  purchase_blueprints(
    ["0", "1", "User4"],
    "User4",
    True
  )

  # should fail since blueprint doesn't exist
  add_to_whitelist(
    "1",
    ["User3", "User4"],
    "AsyncArtAccount",
    False
  )

  acquire_minter("User1")

  # should fail since signer is not designated minter
  add_to_whitelist(
    "0",
    ["AsyncMarketplaceAccount"],
    "User1",
    False
  )


if __name__ == '__main__':
  test_add_to_whitelist()