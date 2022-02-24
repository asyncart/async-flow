from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter

### Args is an array representing the following values in order (types just for info)
# artist: Address,
# capacity: UInt64,
# price: UFix64,
# currency: String,
# blueprintMetadata: String,
# baseTokenUri: String,
# initialWhitelist: [Address],
# mintAmountArtist: UInt64,
# mintAmountPlatform: UInt64,
# maxPurchaseAmount: UInt64
def prepare_blueprint(args, signer, should_succeed):
  initialWhitelist = args[6]
  initialWhitelist = map(lambda user : ["Address", address(user)], initialWhitelist)
  formatted_args = [["Address", address(args[0])], ["UInt64", args[1]], ["UFix64", args[2]], ["String", args[3]], 
                      ["String", args[4]], ["String", args[5]], ["Array", initialWhitelist], ["UInt64", args[7]], 
                      ["UInt64", args[8]], ["UInt64", args[9]]]
  
  if should_succeed:
    assert send_blueprints_transaction("prepareBlueprint", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.BlueprintPrepared'
    assert check_for_event(event)
    print("Successfully Prepared Blueprint As Expected")
  else:
    assert not send_blueprints_transaction("prepareBlueprint", args=formatted_args, signer=signer)
    print("Failed to Prepare Blueprint As Expected")

@pytest.mark.core
def test_prepare_blueprint():
  # Deploy contracts
  main()

  # Confirm that non-user cannot prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "User2",
    False
  )

  setup_blueprints_user("User2")

  # Confirm that non-minter cannot prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "User2",
    False
  )

  acquire_minter("User2")

  # Confirm that user with minter resource but not designated minter cannot prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "User2",
    False
  )

  # Cannot pass in an invalid currency 
  prepare_blueprint(
    ["User1", "5", "10.0", "B.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "User2",
    False
  )

  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "User2",
    False
  )
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'

  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

if __name__ == '__main__':
  test_prepare_blueprint()