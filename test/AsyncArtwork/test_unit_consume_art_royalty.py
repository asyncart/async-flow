from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction
from script_handler import send_async_artwork_script_and_return_result
from event_handler import check_for_event
from metadata_handler import result_equals_expected_metadata
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_user import setup_async_user
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token


@pytest.mark.core
def test_consume_art_royalty():
  # Deploy contracts
  main()

  setup_async_user("User1")
  setup_async_user("User2")
  setup_async_user("User3")

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

  expected_royalty_result = "\"0xf3fcd2c1a78f5eee: 10.00000000%,0x1cf0e2f2f715450: 1.00000000%\""
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "1"]])
  assert expected_royalty_result == royalty_result

  whitelist(
    ["User1", "4", "1", None],
    "AsyncArtAccount",
    True,
    "{4: 1}"
  )

  mint_master_token(
    ["4", "<uri>", ["User3"], ["User2", "User1"]],
    "User1",
    True
  )

  expected_royalty_result = "\"0xf3fcd2c1a78f5eee: 5.00000000%,0x179b6b1cb6755e31: 5.00000000%,0x1cf0e2f2f715450: 5.00000000%\""
  royalty_result = send_async_artwork_script_and_return_result("getNFTRoyalty", args=[["Address", address("User1")], ["UInt64", "4"]])
  assert expected_royalty_result == royalty_result

if __name__ == '__main__':
    test_consume_art_royalty()