from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_async_user import setup_async_user
from test_unit_setup_marketplace_client import setup_marketplace_client
from test_unit_whitelist import whitelist
from test_unit_mint_master_token import mint_master_token 

# expected args: tokenId, currency, minPrice, buyNowPrice, auctionBidPeriod, bidIncreasePercentage, feeRecipients, feePercentages

def create_new_nft_art_auction(args, signer, should_succeed, expected_auction_result=None):
  fee_recipients = [["Address", address(user)] for user in args[6]]
  fee_percentages = [["UFix64", percentage] for percentage in args[7]]
  auction_args = [["UInt64", args[0]], ["String", args[1]], ["UFix64", args[2]], ["UFix64", args[3]], ["UFix64", args[4]], ["UFix64", args[5]], ["Array", fee_recipients], ["Array", fee_percentages]]

  if should_succeed:
    assert send_transaction("createNewArtAuction", args=auction_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.NftAuctionCreated'
    assert check_for_event(event)
    auction_result = send_script_and_return_result("getAuction", args=[["String", "A.01cf0e2f2f715450.AsyncArtwork.NFT"], ["UInt64", args[0]]])
    print(auction_result)
    if expected_auction_result != None:
      assert expected_auction_result == auction_result
    print("Successfuly Created NFT Auction")
  else:
    assert not send_transaction("createNewArtAuction", args=auction_args, signer=signer)
    print("Failed to Create NFT Auction as expected")

@pytest.mark.core
def test_make_new_nft_art_auction():
  # Deploy contracts
  main()

  setup_marketplace_client("User1")

  setup_async_user("User1")

  whitelist(
    ["User1", "1", "0", "5.0", "1.0"],
    "AsyncArtAccount",
    True,
    "{1: 0}"
  )

  mint_master_token(
    ["1", "<uri>", [], []],
    "User1",
    True,
    "{}"
  )

  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 50000.00000000, auctionEnd: nil, minPrice: 2.00000000, buyNowPrice: 5.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: nil, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 5.00000000)"

  create_new_nft_art_auction(
    ["1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "2.0", "5.0", "50000.0", "5.0", [], []],
    "User1",
    True,
    expected_auction_result = res
  )

if __name__ == '__main__':
  test_make_new_nft_art_auction()