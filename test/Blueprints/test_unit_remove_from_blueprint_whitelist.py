from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint

# arg:
# blueprintID
# array of addresses to add
def remove_from_whitelist(blueprintID, args, signer, should_succeed):
  formatted_args = [["Array",[["Address", address(user)] for user in args]]]
  formatted_args.insert(0, ["UInt64", blueprintID])
  
  if should_succeed:
    assert send_blueprints_transaction("removeBlueprintWhitelist", args=formatted_args, signer=signer)
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

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  remove_from_whitelist(
    "0",
    ["User2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state has changed after update
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

if __name__ == '__main__':
  test_remove_from_whitelist()