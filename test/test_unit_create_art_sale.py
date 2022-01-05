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

# expected args: tokenId, currency, buyNowPrice, whitelistedBuyer, feeRecipients, feePercentages

def create_new_art_sale(args, signer, should_succeed, expected_auction_result=None):
  fee_recipients = [["Address", address(user)] for user in args[4]]
  fee_percentages = [["UFix64", percentage] for percentage in args[5]]
  auction_args = [["UInt64", args[0]], ["String", args[1]], ["UFix64", args[2]], ["Address", args[3]], ["Array", fee_recipients], ["Array", fee_percentages]]

  if should_succeed:
    assert send_transaction("createArtSale", args=auction_args, signer=signer)
    event = f'A.{address("NFTAuction")[2:]}.NFTAuction.SaleCreated'
    assert check_for_event(event)
    auction_result = send_script_and_return_result("getAuction", args=[["String", "A.01cf0e2f2f715450.AsyncArtwork.NFT"], ["UInt64", args[0]]])
    print(auction_result)
    if expected_auction_result != None:
      assert expected_auction_result == auction_result
    print("Successfuly Created AsyncArtwork Sale")
  else:
    assert not send_transaction("createArtSale", args=auction_args, signer=signer)
    print("Failed to Create AsyncArtwork Sale as expected")

@pytest.mark.core
def test_make_new_art_sale():
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

  # We might want to refactor the contract to make "auctionBidPeriod" and "bidIncreasePercentage" optional, nil seems more appropriate here than the default values
  res = "A.120e725050340cab.NFTAuction.Auction(feeRecipients: [], feePercentages: [], nftHighestBid: nil, nftHighestBidder: nil, nftRecipient: nil, auctionBidPeriod: 86400.00000000, auctionEnd: nil, minPrice: nil, buyNowPrice: 10.00000000, biddingCurrency: \"A.0ae53cb6e3f42a79.FlowToken.Vault\", whitelistedBuyer: 0xf3fcd2c1a78f5eee, nftSeller: 0x179b6b1cb6755e31, nftProviderCapability: Capability<&AnyResource{A.f8d6e0586b0a20c7.NonFungibleToken.Provider}>(address: 0x179b6b1cb6755e31, path: /private/AsyncArtworkCollection), bidIncreasePercentage: 0.10000000)"

  # Good to note that we currenctly support whitelisting a buyer who is not an async user, I think that's what we want
  # but we might want to bubble up a warning to the frontend if someone tries to do this
  create_new_art_sale(
    ["1", "A.0ae53cb6e3f42a79.FlowToken.Vault", "10.0", "0xf3fcd2c1a78f5eee", [], []],
    "User1",
    True,
    expected_auction_result = res
  )

if __name__ == '__main__':
  test_make_new_art_sale()