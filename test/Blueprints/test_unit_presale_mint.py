from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_begin_sale import begin_sale

# args:
# blueprintID: UInt64
# quantity: UInt64
def presale_mint(args, signer, should_succeed):
  formatted_args = [["UInt64", args[0]], ["UInt64", args[1]]]
  
  if should_succeed:
    assert send_blueprints_transaction("preSaleMint", args=formatted_args, signer=signer)
    print("Successfully Completed Pre-Sale Mint")
  else:
    assert not send_blueprints_transaction("preSaleMint", args=formatted_args, signer=signer)
    print("Failed to Execute Pre-Sale Mint As Expected")

@pytest.mark.core
def test_presale_mint():
  # Deploy contracts
  main()

  setup_blueprints_user("User1")
  setup_blueprints_user("User2")
  
  # Confirm that designated minter can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  # TODO: optimize by extracting addresses based on flow.json etc.
  expected_blueprint = 'A.01cf0e2f2f715450.Blueprints.Blueprint(tokenUriLocked: false, mintAmountArtist: 1, mintAmountPlatform: 2, capacity: 5, nftIndex: 0, maxPurchaseAmount: 2, price: 10.00000000, artist: 0x179b6b1cb6755e31, currency: "A.0ae53cb6e3f42a79.FlowToken.Vault", baseTokenUri: "https://token-uri.com", saleState: A.01cf0e2f2f715450.Blueprints.SaleState(rawValue: 0), primaryFeePercentages: [], secondaryFeePercentages: [], primaryFeeRecipients: [], secondaryFeeRecipients: [], whitelist: {0xf3fcd2c1a78f5eee: false}, blueprintMetadata: "metadata")'
  assert expected_blueprint == send_blueprints_script_and_return_result("getBlueprint", args=[["UInt64", "0"]])

  # Minter can presale mint
  presale_mint(
    ["0", "1"],
    "AsyncArtAccount",
    True
  )

  # assert on the platforms ownership of the NFTs
  assert "id: 0" in send_blueprints_script_and_return_result("getNFT", args=[["Address", address("AsyncArtAccount")], ["UInt64", "0"]])

  # User1 can presale mint as the artist
  presale_mint(
    ["0", "1"],
    "User1",
    True
  )

  # Unauthorized account cannot presale mint
  presale_mint(
    ["0", "1"],
    "User2",
    False
  )

  # Artist cannot presale mint after mintAmountArtist is 0
  presale_mint(
    ["0", "1"],
    "User1",
    False
  )

  # Minter cannot presale mint after mintAmountPlatform is 0
  presale_mint(
    ["0", "1"],
    "AsyncArtAccount",
    True
  )

  presale_mint(
    ["0", "1"],
    "AsyncArtAccount",
    False
  )

  # Cannot presale mint after sale has started

  prepare_blueprint(
    ["User1", "5", "10.0", "A.0ae53cb6e3f42a79.FlowToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

  begin_sale(
    "1",
    "AsyncArtAccount",
    True
  )

  presale_mint(
    ["0", "1"],
    "AsyncArtAccount",
    False
  )

  

if __name__ == '__main__':
  test_presale_mint()