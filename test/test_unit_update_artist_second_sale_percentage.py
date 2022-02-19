from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

# expected args: [newArtistSecondSalePercentage]

def update_artist_second_sale_percentage(args, signer, should_succeed):
  newArtistSecondSalePercentage = [["UFix64", args[0]]]

  if should_succeed:
    assert send_async_artwork_transaction("updateArtistSecondSalePercentage", args=newArtistSecondSalePercentage, signer=signer)
    assert float(args[0]) == float(send_script_and_return_result("getArtistSecondSalePercentage"))
    assert check_for_event(f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.ArtistSecondSalePercentUpdated')
    print("Successfully Updated Artist Second Sale Percentage")
  else:
    assert not send_async_artwork_transaction("updateArtistSecondSalePercentage", args=newArtistSecondSalePercentage, signer=signer)
    print("Updating Artist Second Sale Percentage Failed as Expected")


@pytest.mark.core
def test_update_artist_second_sale_percentage():
  # Deploy contracts
  main()
  
  # Check Admin Can Update Percentage to Valid Value
  update_artist_second_sale_percentage(["2.0"], "AsyncArtAccount", True)

  # Check Admin Can't Update Percentage to Invalid Value
  update_artist_second_sale_percentage(["100.5"], "AsyncArtAccount", False)

  # Check Non-admin Can't Update Percentage
  update_artist_second_sale_percentage(["1.0"], "User1", False)
 
if __name__ == '__main__':
  test_update_artist_second_sale_percentage()