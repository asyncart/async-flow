from initialize_testing_environment import main
from transaction_handler import send_async_artwork_transaction
from script_handler import send_async_artwork_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

# expected args: [platformFirstPercentage, platformSecondPercentage]

def update_platform_default_sales_percentage(args, signer, should_succeed):
  newPlatformFeePercentages = [["UFix64", args[0]]]
  if should_succeed:
    assert send_async_artwork_transaction("updatePlatformFeePercentages", args=newPlatformFeePercentages, signer=signer)
    assert float(args[0])== float(send_async_artwork_script_and_return_result("getDefaultPlatformSecondSalePercentage"))
    assert check_for_event(f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.DefaultPlatformSalePercentageUpdated')
    print("Successfully Updated Default Platform Sales Percentage")
  else:
    assert not send_async_artwork_transaction("updatePlatformFeePercentages", args=newPlatformFeePercentages, signer=signer)
    print("Updating Default Platform Sales Percentage Failed As Expected")

@pytest.mark.core
def test_update_platform_default_sales_percentage():
  # Deploy contracts
  main()
  
  # Check success for Admin account
  update_platform_default_sales_percentage(["0.01"], "AsyncArtAccount", True)

  # Check failure for non-Admin account
  update_platform_default_sales_percentage(["0.05"], "User1", False)

  # Check failure for invalid percentage
  update_platform_default_sales_percentage(["110.04"], "AsyncArtAccount", False)

if __name__ == '__main__':
  test_update_platform_default_sales_percentage()