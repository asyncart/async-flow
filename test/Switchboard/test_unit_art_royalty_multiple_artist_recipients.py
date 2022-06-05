from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction, send_transaction
from script_handler import send_async_artwork_script_and_return_result, send_script_and_return_result
from event_handler import check_for_event
from metadata_handler import result_equals_expected_metadata
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token


@pytest.mark.core
def test_switchboard_art_royalty_multiple():
  # Deploy contracts
  main()

  setup_async_resources("User1")
  setup_async_resources("User2")
  setup_async_resources("User3")
  setup_async_resources("AsyncArtAccount")
  setup_async_resources("emulator-account")
  assert send_transaction("mintFUSD", args=[["UFix64", "100.0"], ["Address", "0xf8d6e0586b0a20c7"]])

  whitelist(
    ["User1", "1", "1", None],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  mint_master_token(
    ["1", "<uri>", ["User3"], ["User2", "User1"]],
    "User1",
    True
  )

  # Assert on standard behaviour (user with cut has royalty receiver)
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "1"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0xf3fcd2c1a78f5eee, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x179b6b1cb6755e31, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x01cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.05000000, description: \"Platform (asyncSaleFeesRecipient) cut\")" in royalty_result

  # Attempt Mock Sale in FlowToken using the Switchboard to pay royalties
  # Assert on balances before mock sale with mock marketplace
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0xf3fcd2c1a78f5eee"]])
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0x01cf0e2f2f715450"]])
  
  assert send_transaction("mockMarketplaceTokenSale", args=[["Address", address("User1")], ["String", "A.01cf0e2f2f715450.AsyncArtwork.NFT"], ["UInt64", "1"], ["UFix64", "10.0"], ["String", "A.0ae53cb6e3f42a79.FlowToken.Vault"]])

  # Assert on balances after mock sale with mock marketplace
  assert "9.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "0.50000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0xf3fcd2c1a78f5eee"]])
  assert "0.50000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0x01cf0e2f2f715450"]])

if __name__ == '__main__':
    test_switchboard_art_royalty_multiple()