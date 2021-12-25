from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
import pytest

@pytest.mark.core

def test_setup_control_token():
  # Deploy contracts
  main()

  newPlatformFeePercentages = [["UFix64", "2.0"]]
  assert send_transaction("updateArtistSecondSalePercentage", args=newPlatformFeePercentages, signer="AsyncArtAccount")
  assert 2.0 == float(send_script_and_return_result("getArtistSecondSalePercentage"))
  assert check_for_event("A.01cf0e2f2f715450.AsyncArtwork.ArtistSecondSalePercentUpdated")
  print("Successfully Updated Default Platform Sales Percentages")

if __name__ == '__main__':
    test_setup_control_token()