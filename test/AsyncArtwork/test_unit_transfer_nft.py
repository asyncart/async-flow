from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction
from script_handler import send_async_artwork_script_and_return_result
from event_handler import check_for_event
from utils import address
import json
import pytest

# Test specific setup functions
from test_unit_setup_async_resources import setup_async_resources
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token 
from test_unit_mint_control_token import mint_control_token
from test_unit_use_control_token import use_control_token

# expected args: [id, recipient]

def transfer_nft(args, signer, should_succeed):
  transfer_args = [["UInt64", args[0]], ["Address", address(args[1])]]

  assert send_async_artwork_script_and_return_result("getNFT", args=[["Address", address(signer)], ["UInt64", args[0]]])

  if should_succeed:
    assert send_async_artwork_transaction("transferNFT", args=transfer_args, signer=signer)
    assert send_async_artwork_script_and_return_result("getNFT", args=[["Address", address(args[1])], ["UInt64", args[0]]])
    event = f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.Deposit'
    assert check_for_event(event)
    
    print("Successfully Transferred NFT")
  else:
    assert not send_async_artwork_transaction("transferNFT", args=transfer_args, signer=signer)
    print("Transferring NFT Failed as Expected")

@pytest.mark.core
def test_transfer_nft():
  # Deploy contracts
  main()

  setup_async_resources("User1")
  setup_async_resources("User2")
  setup_async_resources("User3")

  whitelist(
    ["User1", "1", "1", "0.01"],
    "AsyncArtAccount",
    True,
    "{1: 1}"
  )

  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 1, isMaster: true, uri: "<uri>", isUriLocked: false, platformSecondSalePercentage: 0.01000000, numControlLevers: nil, numRemainingUpdates: nil, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreator}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User1"), levers="{}", uniqueTokenCreator=address("User2"))

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
  expected_metadata = 'A.{contract}.AsyncArtwork.NFTMetadata(id: 2, isMaster: false, uri: "<uri>", isUriLocked: false, platformSecondSalePercentage: 0.01000000, numControlLevers: nil, numRemainingUpdates: 5, owner: {owner}, levers: {levers}, uniqueTokenCreators: [{uniqueTokenCreators}])'.format(contract=address("AsyncArtwork")[2:], owner=address("User2"), levers=levers, uniqueTokenCreators=uniqueTokenCreators)

  mint_control_token(
    ["2", "<uri>", ["1", "1"], ["10", "20"], ["3", "18"], "5", ["User1", "User3"]],
    "User2",
    True,
    "{}",
    expected_metadata=expected_metadata,
    assert_metadata=True
  )

  # Check that user2 can update the NFT
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "0.0"],
      "User2",
      True
  )

  # Check that user3 cannot update the NFT
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "0.0"],
      "User3",
      False
  )

  transfer_nft(
      ["2", "User3"],
      "User2",
      True
  )

  # Check that user2 cannnot update the NFT after transferring it
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "0.0"],
      "User2",
      False
  )

  # Check that user3 can update the NFT after receiving it
  use_control_token(
      ["2", ["0", "1"], ["5", "17"], "0.0"],
      "User3",
      True
  )

if __name__ == '__main__':
    test_transfer_nft()