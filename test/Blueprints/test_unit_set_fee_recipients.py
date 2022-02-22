from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint

# args is an array with the following elements (types not included just for clarity):
# _blueprintID: UInt64,
# _primaryFeeRecipients: [Address],
# _primaryFeePercentages: [UFix64],
# _secondaryFeeRecipients: [Address],
# _secondaryFeePercentages: [UFix64]
def set_fee_recipients(args, signer, should_succeed):
  formatted_args = [["UInt64", args[0]], ["Array", [["Address", address(val)] for val in args[1]]], ["Array",[["UFix64", val] for val in args[2]]], ["Array", [["Address", address(val)] for val in args[3]]], ["Array",[["UFix64", val] for val in args[4]]]]
  
  if should_succeed:
    assert send_blueprints_transaction("setFeeRecipients", args=formatted_args, signer=signer)
    print("Successfully Set Fee Recipients for Blueprint")
  else:
    assert not send_blueprints_transaction("setFeeRecipients", args=formatted_args, signer=signer)
    print("Failed to Set Fee Recipients for Blueprint As Expected")

@pytest.mark.core
def test_set_fee_recipients():
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

  set_fee_recipients(
    ["0", ["User3"], ["5.0"], ["User4"], ["3.0"]],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state has changed after update
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [5.00000000], secondaryFeePercentages: [3.00000000], primaryFeeRecipients: [0xe03daebed8ca0615], secondaryFeeRecipients: [0x45a1763c93006ca], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

if __name__ == '__main__':
  test_set_fee_recipients()