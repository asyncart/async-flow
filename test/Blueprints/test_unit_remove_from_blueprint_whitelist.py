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
from test_unit_add_to_blueprint_whitelist import add_to_whitelist

# arg:
# blueprintID
# array of addresses to add
def remove_from_whitelist(blueprintID, args, signer, should_succeed):
  formatted_args = [["Array",[["Address", address(user)] for user in args]]]
  formatted_args.insert(0, ["UInt64", blueprintID])
  
  if should_succeed:
    assert send_blueprints_transaction("removeBlueprintWhitelist", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.BlueprintWhitelistUpdated'
    assert check_for_event(event)
    print("Successfully Removed Addresses from Whitelist for Blueprint")
  else:
    assert not send_blueprints_transaction("removeBlueprintWhitelist", args=formatted_args, signer=signer)
    print("Failed to Remove Addresses from Whitelist As Expected")

@pytest.mark.core
def test_remove_from_whitelist():
  # Deploy contracts
  main()
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # Setup User2 to purchase tokens
  setup_async_resources("User2")
  transfer_flow_token("User2", "100.0", "emulator-account")

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  # User2 can purchase blueprints
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  remove_from_whitelist(
    "0",
    ["User2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state has changed after update
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 4, nftIndex: 1, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  # User2 cannot purchase blueprints anymore, after being removed from whitelist
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    False
  )

  # User2 can purchase blueprints if removed from whitelist, then added back even if they had already claimed
  add_to_whitelist(
    "0",
    ["User2"],
    "AsyncArtAccount",
    True
  )

  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

if __name__ == '__main__':
  test_remove_from_whitelist()