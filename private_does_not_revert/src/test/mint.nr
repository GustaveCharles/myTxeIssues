use crate::test::utils;
use dep::aztec::{test::helpers::cheatcodes, oracle::unsafe_rand::unsafe_rand};
use dep::authwit::cheatcodes as authwit_cheatcodes;
use crate::Token;


#[test]
unconstrained fn mint_t() {
    let (env, token_contract_address, owner, user, mint_amount) = utils::setup(/* with_account_contracts */ false);

    env.impersonate(user);
    let mint_amount = 1000;
    let mint_call_interface = Token::at(token_contract_address).privately_mint_private_note(mint_amount);
    env.call_private_void(mint_call_interface);

    env.advance_block_by(1);

    let total_supply_call_interface = Token::at(token_contract_address).total_supply();
    let total_supply = env.call_public(total_supply_call_interface);

    assert(total_supply == 0);

    utils::check_private_balance(token_contract_address, user, mint_amount);
}