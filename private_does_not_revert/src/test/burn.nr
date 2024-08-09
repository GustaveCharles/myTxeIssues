use crate::test::utils;
use dep::aztec::{test::helpers::cheatcodes, oracle::unsafe_rand::unsafe_rand};
use dep::authwit::cheatcodes as authwit_cheatcodes;
use crate::Token;


#[test]
unconstrained fn burn_private_on_behalf_of_self() {
    let (env, token_contract_address, owner, _, mint_amount) = utils::setup_and_mint(/* with_account_contracts */ false);
    let burn_amount = mint_amount / 10;

    // Burn less than balance 
    let burn_call_interface = Token::at(token_contract_address).burn(owner, burn_amount, 0);
    env.call_private_void(burn_call_interface);
    utils::check_private_balance(token_contract_address, owner, mint_amount - burn_amount);
}

#[test(should_fail)]
unconstrained fn burn_private_on_behalf_of_other() {
    let (env, token_contract_address, owner, recipient, mint_amount) = utils::setup_and_mint(/* with_account_contracts */ true);
    let burn_amount = mint_amount / 10;

    // Burn on behalf of other
    let burn_call_interface = Token::at(token_contract_address).burn(owner, burn_amount, unsafe_rand());
    // Impersonate recipient to perform the call
    env.impersonate(recipient);
    // Burn tokens
    env.call_private_void(burn_call_interface);
    utils::check_private_balance(token_contract_address, owner, mint_amount - burn_amount);
}
