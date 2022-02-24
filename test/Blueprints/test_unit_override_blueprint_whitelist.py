from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_purchase_blueprints import purchase_blueprints

# arg:
# blueprintID
# array of addresses to add
def override_whitelist(blueprintID, args, signer, should_succeed):
  formatted_args = [["Array",[["Address", address(user)] for user in args]]]
  formatted_args.insert(0, ["UInt64", blueprintID])
  
  if should_succeed:
    assert send_blueprints_transaction("overrideBlueprintWhitelist", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.BlueprintWhitelistUpdated'
    assert check_for_event(event)
    print("Successfully overrided Addresses from Whitelist for Blueprint")
  else:
    assert not send_blueprints_transaction("overrideBlueprintWhitelist", args=formatted_args, signer=signer)
    print("Failed to override Addresses from Whitelist As Expected")

@pytest.mark.core
def test_override_whitelist():
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

  # User2 and User3 acquire tokens to purchase blueprints
  transfer_flow_token("User2", "100.0", "emulator-account")
  transfer_flow_token("User3", "100.0", "emulator-account")

  # Setup blueprints users
  setup_blueprints_user("User2")
  setup_blueprints_user("User3")

  # User 2 can purchase blueprints
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  # User3 cannot purchase blueprints 
  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    False
  )

  # override whitelist to only include user3
  override_whitelist(
    "0",
    ["User3"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state has changed after update
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 4, nftIndex: 1, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xe03daebed8ca0615: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  # User2 should not be able to purchase blueprints anymore
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    False
  )

  # User3 can purchase blueprints 
  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    True
  )

  override_whitelist(
    "0",
    ["User3"],
    "AsyncArtAccount",
    True
  )

  # User3 can purchase again, even though User3 had claimed before, because we overwrote whitelist
  purchase_blueprints(
    ["0", "1", "User3"],
    "User3",
    True
  )

if __name__ == '__main__':
  test_override_whitelist()