use crate::test::utils;
use dep::aztec::{test::helpers::cheatcodes, oracle::unsafe_rand::unsafe_rand};
use dep::authwit::cheatcodes as authwit_cheatcodes;
use crate::Token;


#[test(should_fail_with="Error: caller is not minter")]
unconstrained fn mint_fails_wrong_error() {
    let (env, token_contract_address, owner, user, mint_amount) = utils::setup(/* with_account_contracts */ false);

    env.impersonate(user);
    let mint_amount = 1000;


    let mint_call_interface = Token::at(token_contract_address).mint(user,mint_amount);
    env.call_private_void(mint_call_interface);
}

#[test]
unconstrained fn mint_passes() {
    let (env, token_contract_address, owner, user, mint_amount) = utils::setup(/* with_account_contracts */ false);

    env.impersonate(user);
    let mint_amount = 1000;

    let set_minter_call_interface = Token::at(token_contract_address).set_minter(user, true);
    env.call_public(set_minter_call_interface);

    let mint_call_interface = Token::at(token_contract_address).mint(user,mint_amount);
    env.call_private_void(mint_call_interface);
}