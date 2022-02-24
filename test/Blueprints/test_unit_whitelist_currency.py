from initialize_testing_environment import main
from transaction_handler import send_blueprints_transaction, send_transaction
from script_handler import send_blueprints_script_and_return_result
from event_handler import check_for_event
from utils import address
import pytest

from test_unit_setup_blueprints_user import setup_blueprints_user
from test_unit_acquire_minter import acquire_minter
from test_unit_prepare_blueprint import prepare_blueprint
from test_unit_presale_mint import presale_mint
from test_unit_begin_sale import begin_sale 
from test_unit_update_blueprint_settings import update_blueprint_settings

def whitelist_example_token(signer, should_succeed):
  if should_succeed:
    assert send_blueprints_transaction("whitelistExampleToken", signer=signer)
    print("Successfully Whitelisted Example Token")
  else:
    assert not send_blueprints_transaction("whitelistExampleToken", signer=signer)
    print("Failed to Whitelist Example Token As Expected")

@pytest.mark.core
def test_whitelist_example_token():
  # Deploy contracts
  main()

  # Randomuser should not be able to whitelist currency
  whitelist_example_token("User1", False)

  setup_blueprints_user("User1")

  # Async user should not be able to whitelist currency
  whitelist_example_token("User1", False)

  # AsyncArtworkAccount acquires example token vault
  assert send_transaction("acquireExampleTokenVault", signer="AsyncArtAccount")

  # AsyncArtworkAccount should be able to whitelist currency
  whitelist_example_token("AsyncArtAccount", True)

  assert "true" == send_blueprints_script_and_return_result("isCurrencySupported", args=[["String", "A.f8d6e0586b0a20c7.ExampleToken.Vault"]])
  
  # Confirm that designated minter (by default the async art account) can prepare blueprint
  prepare_blueprint(
    ["User1", "5", "10.0", "A.f8d6e0586b0a20c7.ExampleToken.Vault", "metadata", "https://token-uri.com", ["User2"], "1", "2", "2"],
    "AsyncArtAccount",
    True
  )

if __name__ == '__main__':
  test_whitelist_example_token()