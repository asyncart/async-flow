from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result, send_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_purchase_blueprints import purchase_blueprints

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

  # User2 acquires tokens to purchase blueprints
  transfer_flow_token("User2", "100.0", "emulator-account")
  setup_blueprints_user("User2")
  
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  set_fee_recipients(
    ["0", ["User3"], ["0.05"], ["User4"], ["0.03"]],
    "AsyncArtAccount",
    True
  )

  # User3 should receive the expected fee from the sale of the token
  originalUserBalance = float(send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]]))
  
  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )
  
  newUserBalance = float(send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User3")]]))

  assert newUserBalance - originalUserBalance == 10.0 * 0.05

  # TODO: validate that secondary fees are received as well, on marketplace sell

  # TODO: optimize by extracting addresses based on flow.json etc.
  # Check that state has changed after update
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 4, nftIndex: 1, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [0.05000000], secondaryFeePercentages: [0.03000000], primaryFeeRecipients: [0xe03daebed8ca0615], secondaryFeeRecipients: [0x45a1763c93006ca], whitelist: {0xf3fcd2c1a78f5eee: true}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

if __name__ == '__main__':
  test_set_fee_recipients()