from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint

# args:
# blueprintID: UInt64, quantity: UInt64, recipient: Address
def purchase_blueprints(args, signer, should_succeed):
  formatted_args = [["UInt64", args[0]], ["UInt64", args[1]], ["Address", address(args[2])]]
  
  if should_succeed:
    assert send_blueprints_transaction("purchaseBlueprints", args=formatted_args, signer=signer)
    print("Successfully Purchased Blueprints")
  else:
    assert not send_blueprints_transaction("purchaseBlueprints", args=formatted_args, signer=signer)
    print("Failed to Purchase Blueprints As Expected")

@pytest.mark.core
def test_purchase_blueprints():
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

  # User2 acquires tokens to purchase blueprints
  transfer_flow_token("User2", "100.0", "emulator-account")

  setup_blueprints_user("User2")

  purchase_blueprints(
    ["0", "1", "User2"],
    "User2",
    True
  )

  # assert on User2's ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("User2")], ["UInt64", "0"]])

if __name__ == '__main__':
  test_purchase_blueprints()