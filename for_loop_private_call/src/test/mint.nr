use crate::test::utils;
use dep::aztec::{test::helpers::cheatcodes, oracle::unsafe_rand::unsafe_rand};
use dep::authwit::cheatcodes as authwit_cheatcodes;
use crate::Token;


// #[test]
// unconstrained fn mint_t() {
//     let (env, token_contract_address, owner, user, mint_amount) = utils::setup(/* with_account_contracts */ false);

//     env.impersonate(user);
//     let mint_amount = 1000;
//     let mint_call_interface = Token::at(token_contract_address).privately_mint_private_note(user,mint_amount);
//     env.call_private_void(mint_call_interface);

//     env.advance_block_by(1);

//     let total_supply_call_interface = Token::at(token_contract_address).total_supply();
//     let total_supply = env.call_public(total_supply_call_interface);

//     assert(total_supply == 0);

//     utils::check_private_balance(token_contract_address, user, mint_amount);
// }

#[test]
unconstrained fn mint_private_batch_success() {
    // Setup without account contracts. We are not using authwits here, so dummy accounts are enough
    let (env, token_contract_address, issuer, user1) = utils::setup(/* with_account_contracts */ false);

    let mint_amount = [10000,1000,0,0,0,0,0,0,0,0];
    let addresses = [issuer, user1,user1,user1,user1,user1,user1,user1,user1,user1];

    let mint_private_call_interface = Token::at(token_contract_address).mint_batch(addresses, mint_amount);
    env.call_private_void(mint_private_call_interface);

    utils::check_private_balance(token_contract_address, addresses[0], mint_amount[0]);
    utils::check_private_balance(token_contract_address, addresses[1], mint_amount[1]);

    let total_supply_call_interface = Token::at(token_contract_address).total_supply();
    let total_supply = env.call_public(total_supply_call_interface);

    let mut total_mint_amount = 0;
    for i in 0..10 {
        total_mint_amount += mint_amount[i];
    }

    assert(total_supply == total_mint_amount);
}