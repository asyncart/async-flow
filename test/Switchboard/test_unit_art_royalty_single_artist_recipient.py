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
def test_switchboard_art_royalty_single():
  # Deploy contracts
  main()

  setup_async_resources("User1")
  setup_async_resources("User2")
  setup_async_resources("User3")
  setup_async_resources("AsyncArtAccount")
  setup_async_resources("emulator-account")
  assert send_transaction("mintFUSD", args=[["UFix64", "100.0"], ["Address", "0xf8d6e0586b0a20c7"]])

  whitelist(
    ["User1", "1", "2", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 2}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformSecondSalePercentage: 0.01000000, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))
  mint_master_token(
    ["1", "<uri>", ["User2", "User3"], ["User2"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # Assert on standard behaviour (user with cut has royalty receiver)
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "1"]])
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0xf3fcd2c1a78f5eee, path: /public/GenericFTReceiver), cut: 0.10000000, description: \"Unique token creator cut\")" in royalty_result
  assert "A.f8d6e0586b0a20c7.MetadataViews.Royalty(receiver: Capability<&AnyResource{A.ee82856bf20e2aa6.FungibleToken.Receiver}>(address: 0x1cf0e2f2f715450, path: /public/GenericFTReceiver), cut: 0.01000000, description: \"Platform (asyncSaleFeesRecipient) cut\")" in royalty_result

  # Attempt Mock Sale in FlowToken using the Switchboard to pay royalties
  # Assert on balances before mock sale with mock marketplace
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0xf3fcd2c1a78f5eee"]])
  assert "0.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0x01cf0e2f2f715450"]])
  
  assert send_transaction("mockMarketplaceTokenSale", args=[["Address", address("User1")], ["String", "A.01cf0e2f2f715450.AsyncArtwork.NFT"], ["UInt64", "1"], ["UFix64", "10.0"], ["String", "A.0ae53cb6e3f42a79.FlowToken.Vault"]])

  # Assert on balances after mock sale with mock marketplace
  assert "8.90000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", address("User1")]])
  assert "1.00000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0xf3fcd2c1a78f5eee"]])
  assert "0.10000000" == send_script_and_return_result("getUsersFlowTokenBalance", args=[["Address", "0x01cf0e2f2f715450"]])

  # Attempt Mock Sale in FUSD using the Switchboard to pay royalties
  # Assert on balances before mock sale with mock marketplace
  assert "0.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])
  assert "0.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", "0xf3fcd2c1a78f5eee"]])
  assert "0.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", "0x01cf0e2f2f715450"]])
  
  assert send_transaction("mockMarketplaceTokenSale", args=[["Address", address("User1")], ["String", "A.01cf0e2f2f715450.AsyncArtwork.NFT"], ["UInt64", "1"], ["UFix64", "10.0"], ["String", "A.f8d6e0586b0a20c7.FUSD.Vault"]], show=True)

  # Assert on balances after mock sale with mock marketplace
  assert "8.90000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", address("User1")]])
  assert "1.00000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", "0xf3fcd2c1a78f5eee"]])
  assert "0.10000000" == send_script_and_return_result("getUsersFUSDBalance", args=[["Address", "0x01cf0e2f2f715450"]])

if __name__ == '__main__':
    test_switchboard_art_royalty_single()