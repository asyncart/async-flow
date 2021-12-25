from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
import pytest

@pytest.mark.core

def test_setup_control_token():
  main()
  firstControlToken = [["String", "<token URI>"], ["Array", [["Int64", "0"], ["Int64", "2"]]], ["Array", [["Int64", "10"], ["Int64", "20"]]], ["Array", [["Int64", "1"], ["Int64", "7"]]], ["Int64", "3"]]
  assert send_transaction("setupControlToken", args=firstControlToken, signer="AsyncArtAccount")
  print("Setup control token")

  secondControlToken = [["String", "<token URI>"], ["Array", [["Int64", "0"], ["Int64", "2"]]], ["Array", [["Int64", "10"], ["Int64", "20"]]], ["Array", [["Int64", "1"], ["Int64", "21"]]], ["Int64", "3"]]
  assert not send_transaction("setupControlToken", args=secondControlToken, signer='AsyncArtAccount')
  print("Could not setup control token as expected, since start lever value was invalid")

if __name__ == '__main__':
    test_setup_control_token()