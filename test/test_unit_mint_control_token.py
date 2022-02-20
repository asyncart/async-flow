from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction
from script_handler import send_async_artwork_script_and_return_result
from event_handler import check_for_event
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_user import setup_async_user
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token 

# expected args: [id, tokenUri, leverMinValues, leverMaxValues, leverStartValues, numAllowedUpdates, additionalCollaborators]

def mint_control_token(args, signer, should_succeed, expected_control_mint_reservation, expected_metadata="", assert_metadata=False):
  lever_min_vals = [["Int64", val] for val in args[2]]
  lever_max_vals = [["Int64", val] for val in args[3]]
  lever_start_vals = [["Int64", val] for val in args[4]]
  additional_collaborators = [["Address", address(user)] for user in args[6]]
  mint_args = [
    ["UInt64", args[0]], 
    ["String", args[1]], 
    ["Array", lever_min_vals], 
    ["Array", lever_max_vals],
    ["Array", lever_start_vals],
    ["Int64", args[5]],
    ["Array", additional_collaborators]
  ]

  if should_succeed:
    assert send_async_artwork_transaction("mintControlToken", args=mint_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.Deposit'
    assert check_for_event(event)
    assert expected_control_mint_reservation == send_async_artwork_script_and_return_result("getControlMintReservation", args=[["Address", address(signer)]])
    metadata = send_async_artwork_script_and_return_result("getMetadata", args=[["UInt64", args[0]]])
    print(metadata)
    if assert_metadata:
      assert metadata == expected_metadata
    
    print("Successfully Minted Control Token")
  else:
    assert not send_async_artwork_transaction("mintControlToken", args=mint_args, signer=signer)
    print("Minting Control Token Failed as Expected")


@pytest.mark.core
def test_mint_control():
  # Deploy contracts
  main()

  setup_async_user("User1")
  setup_async_user("User2")
  setup_async_user("User3")

  whitelist(
    ["User1", "1", "2", "5.0", "1.0"],
    "AsyncArtAccount",
    True,
    "{1: 2}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))

  mint_master_token(
    ["1", "<uri>", ["User2", "User3"], ["User2"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 3), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 18)}}".format(contract=address("AsyncArtwork")[2:])
  uniqueTokenCreators = f'{address("User1")}, {address("User3")}'
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  expected_metadata2 = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 3, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 5.00000000, platformSecondSalePercentage: 1.00000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [])'.format(contract=address("AsyncArtwork")[2:], owner=address("User3"), levers='{}')

  # Check that wrong user cannot mint control token not allocated to them
  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User1",
    False,
    "{}"
  )

  # Check that user cannot mint control token not allocated to them
  mint_control_token(
    ["3", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    False,
    "{}"
  )

  # Check that user cannot specify different lengths of min, max, curVal levers
  mint_control_token(
    ["2", "<uri>", ["1", "1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    False,
    "{}"
  )

  # Check that user cannot specify more than 500 levers
  mint_control_token(
    ["2", "<uri>", ['1' for i in range(501)], ['100' for i in range(501)], ['50' for i in range(501)], "5", ["User1", "User3"]],
    "User2",
    False,
    "{}"
  )

  # Check that user can mint control token
  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # Check that user can mint control token without any levers or collaborators
  mint_control_token(
    ["3", "<uri>", [], [], [], "5", []],
    "User3",
    True,
    "{}",
    expected_metadata=expected_metadata2,
    assert_metadata=True
  )

  # Check that user cannot mint control token again
  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    False,
    "{}"
  )

if __name__ == '__main__':
    test_mint_control()