from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_async_resources import setup_async_resources
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint

# args is an array with the following elements (types not included just for clarity):
# _blueprintID: UInt64,
# _price: UFix64,
# _mintAmountArtist: UInt64,
# _mintAmountPlatform: UInt64,
# _newSaleState: UInt8,
# _newMaxPurchaseAmount: UInt64 
def update_blueprint_settings(args, signer, should_succeed):
  formatted_args = [["UInt64", args[0]], ["UFix64", args[1]], ["UInt64", args[2]], ["UInt64", args[3]], ["UInt8", args[4]], ["UInt64", args[5]]]
  
  if should_succeed:
    assert send_blueprints_transaction("updateBlueprintSettings", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.BlueprintSettingsUpdated'
    assert check_for_event(event)
    print("Successfully Updated Blueprint Settings")
  else:
    assert not send_blueprints_transaction("updateBlueprintSettings", args=formatted_args, signer=signer)
    print("Failed to Update Blueprint Settings As Expected")

@pytest.mark.core
def test_update_blueprint_settings():
  # Deploy contracts
  main()
  
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  update_blueprint_settings(
    ["0", "11.0", "3", "1", "1", "3"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state has changed after update
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 3, mintAmountPlatform: 1, capacity: 5, nftIndex: 0, maxPurchaseAmount: 3, price: 11.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 1), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  # Non-minter account cannot update blueprint settings
  update_blueprint_settings(
    ["0", "11.0", "3", "1", "1", "3"],
    "User1",
    False
  )

  # Cannot update settings for a non-existent blueprint
  update_blueprint_settings(
    ["1", "11.0", "3", "1", "1", "3"],
    "AsyncArtAccount",
    False
  )


if __name__ == '__main__':
  test_update_blueprint_settings()