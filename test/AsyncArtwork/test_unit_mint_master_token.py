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

# expected args: [id, artworkUri, controlTokenArtists, uniqueArtists]

def mint_master_token(args, signer, should_succeed, expected_master_mint_res=None, expected_metadata="", assert_metadata=False):
  control_token_artists = [["Address", address(user)] for user in args[2]]
  unique_artists = [["Address", address(user)] for user in args[3]]
  mint_args = [["UInt64", args[0]], ["String", args[1]], ["Array", control_token_artists], ["Array", unique_artists]]

  if should_succeed:
    assert send_async_artwork_transaction("mintMasterToken", args=mint_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.Deposit'
    assert check_for_event(event)
    if expected_master_mint_res != None:
      assert expected_master_mint_res == send_async_artwork_script_and_return_result("getMasterMintReservation", args=[["Address", address(signer)]])
    metadata = send_async_artwork_script_and_return_result("getMetadata", args=[["UInt64", args[0]]])
    print(metadata)
    print(expected_metadata)
    if assert_metadata:
      assert result_equals_expected_metadata(metadata, expected_metadata)
    # Maybe add an asertion about the on-contract metadata
    print("Successfuly Minted Master NFT to Creator")
  else:
    assert not send_async_artwork_transaction("mintMasterToken", args=mint_args, signer=signer)
    print("Minting Master Token Failed as Expected")

@pytest.mark.core
def test_mint_master_token():
  # Deploy contracts
  main()

  setup_async_user("User1")
  setup_async_user("User2")

  whitelist(
    ["User1", "1", "1", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformSecondSalePercentage: 0.01000000, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))

  # Check user cannot mint master token not allocated for them
  mint_master_token(
    ["2", "<uri>", ["User2"], ["User2"]],
    "User1",
    False,
    "{}",
    assert_metadata=False
  )

  # Check wrong user cannot mint master token
  mint_master_token(
    ["1", "<uri>", ["User2"], ["User2"]],
    "User2",
    False,
    "{}",
    assert_metadata=False
  )

  # Check that user cannot specify a different number of control token artists than layer count
  mint_master_token(
    ["1", "<uri>", [], []],
    "User1",
    False,
    "{}",
    assert_metadata=False
  )

  # Check wrong user cannot specify control token artist without AsyncCollection
  mint_master_token(
    ["1", "<uri>", ["User3"], ["User2"]],
    "User1",
    False,
    "{}",
    assert_metadata=False
  )

  # Check user can mint whitelisted token
  mint_master_token(
    ["1", "<uri>", ["User2"], ["User2"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # Check user cannot mint whitelisted token again
  mint_master_token(
    ["1", "<uri>", ["User2"], ["User2"]],
    "User1",
    False,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

if __name__ == '__main__':
  test_mint_master_token()