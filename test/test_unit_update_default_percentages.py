from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

@pytest.mark.core

# expected args: [platformFirstPercentage, platformSecondPercentage]
def test_update_platform_default_sales_percentages(args, signer, should_succeed):
  # Deploy contracts
  main()

  newPlatformFeePercentages = [["UFix64", args[0]], ["UFix64", args[1]]]
  assert send_transaction("updatePlatformFeePercentages", args=newPlatformFeePercentages, signer=signer)
  assert float(args[0]) == float(send_script_and_return_result("getDefaultPlatformFirstSalePercentage"))
  assert float(args[1])== float(send_script_and_return_result("getDefaultPlatformSecondSalePercentage"))
  assert check_for_event(f'A.{address("AsyncArtwork")[2:]}.AsyncArtwork.DefaultPlatformSalePercentageUpdated')
  print("Successfully Updated Default Platform Sales Percentages")

if __name__ == '__main__':
    test_update_platform_default_sales_percentages(["2.0", "1.0"], "AsyncArtAccount", True)