from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result, send_async_artwork_script_and_return_result, send_nft_auction_script_and_return_result
from event_handler import check_for_event
from utils import address, transfer_flow_token
import pytest

def setup_async_resources(signer):
  assert send_transaction("setupAsyncResources", signer=signer)
  print(f'Successfully Setup All Async Resources for {signer}')

@pytest.mark.core
def test_setup_async_resources():
  # Deploy contracts
  main()

  setup_async_resources("User1")

if __name__ == '__main__':
  test_setup_async_resources()