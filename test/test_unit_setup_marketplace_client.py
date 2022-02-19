from initialize_testing_environment import main
from transaction_handler import send_nft_auction_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
import pytest

from test_unit_setup_async_user import setup_async_user

def setup_marketplace_client(signer):
  assert send_nft_auction_transaction("setupMarketplaceClient", signer=signer)
  print("Successfully Created Marketplace Client")

@pytest.mark.core
def test_setup_client_resources():
  # Deploy contracts
  main()

  setup_marketplace_client("User1")

if __name__ == '__main__':
  test_setup_client_resources()