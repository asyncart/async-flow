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
from test_unit_mint_control_token import mint_control_token
from test_unit_grant_control_permission import grant_control_permission

# expected args: [id, leverIds, newLeverValues, tip]

def use_control_token(args, signer, should_succeed, expected_metadata="", assert_metadata=False):
  leverIds = [["UInt64", val] for val in args[1]]
  newLeverValues = [["Int64", val] for val in args[2]]
  use_args = [
    ["UInt64", args[0]], 
    ["Array", leverIds], 
    ["Array", newLeverValues], 
    ["UFix64", args[3]]
  ]

  if should_succeed:
    assert send_async_artwork_transaction("useControlToken", args=use_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.ControlLeverUpdated'
    assert check_for_event(event)
    metadata = send_async_artwork_script_and_return_result("getMetadata", args=[["UInt64", args[0]]])
    print("Updated METADATA")
    print(metadata)
    if assert_metadata:
      assert result_equals_expected_metadata(metadata, expected_metadata)
    
    print("Successfully Updated Control Token")
  else:
    assert not send_async_artwork_transaction("useControlToken", args=use_args, signer=signer)
    print("Updating Control Token Failed as Expected")

@pytest.mark.core
def test_use_control():
  # Deploy contracts
  main()

  setup_async_user("User1")
  setup_async_user("User2")
  setup_async_user("User3")

  whitelist(
    ["User1", "1", "1", "0.05", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))

  mint_master_token(
    ["1", "<uri>", ["User2"], ["User2"]],
    "User1",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 3), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 18)}}".format(contract=address("AsyncArtwork")[2:])
  uniqueTokenCreators = f'{address("User1")}, {address("User3")}'
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  grant_control_permission(
      ["2", "User3", True],
      "User2",
      True,
      "{2: 0}"
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 5), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 17)}}".format(contract=address("AsyncArtwork")[2:])
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 4, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # Check that non-permissioned controller cannot update token levers
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "0.0"],
      "User1",
      False
  )

  # Check that user cannot update control token they are not associated with
  use_control_token(
      ["3", ["0", "1"], ["5", "17"], "0.0"],
      "User2",
      False
  )

  # Check that permissioned controller can update token levers
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "0.0"],
      "User3",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 1), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 20)}}".format(contract=address("AsyncArtwork")[2:])
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 3, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # Check that owner can update token levers
  use_control_token(
      ["2", ["0", "1"], ["1", "20"], "0.0"],
      "User2",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  # Check that update to non-existent token id fails
  use_control_token(
      ["2", ["2"], ["1"], "0.0"],
      "User2",
      False
  )

  # Check that updating lever above max val fails
  use_control_token(
      ["2", ["0"], ["21"], "0.0"],
      "User2",
      False
  )

  # Check that updating lever below min val fails
  use_control_token(
      ["2", ["0"], ["-1"], "0.0"],
      "User2",
      False
  )

  levers = "{{0: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 10, currentValue: 9), 1: A.{contract}.AsyncArtwork.ControlLever(minValue: 1, maxValue: 20, currentValue: 20)}}".format(contract=address("AsyncArtwork")[2:])
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 2, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  # Check that owner can update only one lever
  use_control_token(
      ["2", ["0"], ["9"], "0.0"],
      "User2",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 1, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)
  # Check that owner can update only one lever
  use_control_token(
      ["2", ["0"], ["9"], "0.0"],
      "User2",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformFirstSalePercentage: 0.05000000, platformSecondSalePercentage: 0.01000000, tokenSoldOnce: false, numControlLevers: nil, numRemainingUpdates: 0, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)
  # Check that owner can update only one lever
  use_control_token(
      ["2", ["0"], ["9"], "0.0"],
      "User2",
      True,
      expected_metadata=expected_metadata,
      assert_metadata=True
  )

  # Check that control token cannot be updated more times than limit
  use_control_token(
      ["2", ["0"], ["9"], "0.0"],
      "User2",
      False
  )

if __name__ == '__main__':
    test_use_control()