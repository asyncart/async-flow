from initialize_testing_environment import main
from transaction_handler import send_transaction
from script_handler import send_script, send_script_and_return_result
from event_handler import check_for_event, check_for_n_event_occurences_over_x_blocks
import pytest

@pytest.mark.core

def test_answer():
  main()
  assert send_transaction("incrementCounter", signer='AsyncArtAccount')
  assert send_transaction("incrementCounter", signer='AsyncArtAccount')
  assert int(send_script_and_return_result("getCounter")) == 2
  assert check_for_n_event_occurences_over_x_blocks("4", 2, "A.01cf0e2f2f715450.AsyncArtworkV2.CounterIncremented")

if __name__ == '__main__':
    test_answer()