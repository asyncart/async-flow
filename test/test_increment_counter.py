from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
import pytest

@pytest.mark.core

def test_answer():
  main()
  assert send_transaction("incrementCounter", signer='AsyncArtAccount')
  assert send_transaction("incrementCounter", signer='AsyncArtAccount')
  assert int(send_script_and_return_result("getCounter")) == 2

if __name__ == '__main__':
    test_answer()