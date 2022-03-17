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

# arg is currency identifier to unwhitelist
def unwhitelist_currency_safe(arg, signer, should_succeed):
  formatted_args = [["String", arg]]

  if should_succeed:
    assert send_transaction("unwhitelistCurrencySafe", args=formatted_args, signer=signer)
    event = f'A.{address("AsyncArtwork")[2:]}.Blueprints.CurrencyUnwhitelisted'
    assert check_for_event(event)
    print("Successfully Unwhitelisted Currency")
  else:
    assert not send_transaction("unwhitelistCurrencySafe", args=formatted_args, signer=signer)
    print("Failed to Unwhitelist Currency As Expected")

@pytest.mark.core
def test_prepare_blueprint():
  # Deploy contracts
  main()

  # Randomuser should not be able to unwhitelist currency
  unwhitelist_currency_safe("A.f8d6e0586b0a20c7.FUSD.Vault", "User1", False)

  setup_blueprints_user("User1")

  # Async user should not be able to unwhitelist currency
  unwhitelist_currency_safe("A.f8d6e0586b0a20c7.FUSD.Vault", "User1", False)

  # AsyncArtworkAccount (Platform) should be able to unwhitelist currency
  unwhitelist_currency_safe("A.f8d6e0586b0a20c7.FUSD.Vault", "AsyncArtAccount", True)

  assert "false" == send_blueprints_script_and_return_result("isCurrencySupported", args=[["String", "A.f8d6e0586b0a20c7.FUSD.Vault"]])

if __name__ == '__main__':
  test_prepare_blueprint()