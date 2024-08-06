mod types;
mod test;

// Minimal token implementation that supports `AuthWit` accounts.
// The auth message follows a similar pattern to the cross-chain message and includes a designated caller.
// The designated caller is ALWAYS used here, and not based on a flag as cross-chain.
// message hash = H([caller, contract, selector, ...args])
// To be read as `caller` calls function at `contract` defined by `selector` with `args`
// Including a nonce in the message hash ensures that the message can only be used once.

contract Token {
    // Libs

    use dep::compressed_string::FieldCompressedString;

    use dep::aztec::{
        hash::compute_secret_hash,
        prelude::{NoteGetterOptions, Map, PublicMutable, SharedImmutable, PrivateSet, AztecAddress},
        encrypted_logs::{
        encrypted_note_emission::{
        encode_and_encrypt_note, encode_and_encrypt_note_with_keys,
        encode_and_encrypt_note_with_keys_unconstrained
    },
        encrypted_event_emission::{encode_and_encrypt_event, encode_and_encrypt_event_with_keys_unconstrained}
    }
    };

    // docs:start:import_authwit
    use dep::authwit::auth::{assert_current_call_valid_authwit, assert_current_call_valid_authwit_public, compute_authwit_nullifier};
    // docs:end:import_authwit

    use crate::types::{token_note::{TokenNote, TOKEN_NOTE_LEN}, balances_map::BalancesMap};
    // docs:end::imports

    #[aztec(event)]
    struct Transfer {
        from: AztecAddress,
        to: AztecAddress,
        amount: Field,
    }

    // docs:start:storage_struct
    #[aztec(storage)]
    struct Storage {
        admin: PublicMutable<AztecAddress>,
        minters: Map<AztecAddress, PublicMutable<bool>>,
        balances: BalancesMap<TokenNote>,
        total_supply: PublicMutable<U128>,

        symbol: SharedImmutable<FieldCompressedString>,
        name: SharedImmutable<FieldCompressedString>,
        decimals: SharedImmutable<u8>,
    }
    // docs:end:storage_struct

    // docs:start:constructor
    #[aztec(public)]
    #[aztec(initializer)]
    fn constructor(admin: AztecAddress, name: str<31>, symbol: str<31>, decimals: u8) {
        assert(!admin.is_zero(), "invalid admin");
        storage.admin.write(admin);
        storage.minters.at(admin).write(true);
        storage.name.initialize(FieldCompressedString::from_string(name));
        storage.symbol.initialize(FieldCompressedString::from_string(symbol));
        // docs:start:initialize_decimals
        storage.decimals.initialize(decimals);
        // docs:end:initialize_decimals
    }
    // docs:end:constructor

    // docs:start:set_admin
    #[aztec(public)]
    fn set_admin(new_admin: AztecAddress) {
        assert(storage.admin.read().eq(context.msg_sender()), "caller is not admin");
        // docs:start:write_admin
        storage.admin.write(new_admin);
        // docs:end:write_admin
    }
    // docs:end:set_admin

    #[aztec(public)]
    #[aztec(view)]
    fn public_get_name() -> pub FieldCompressedString {
        storage.name.read_public()
    }

    #[aztec(private)]
    #[aztec(view)]
    fn private_get_name() -> pub FieldCompressedString {
        storage.name.read_private()
    }

    #[aztec(public)]
    #[aztec(view)]
    fn public_get_symbol() -> pub FieldCompressedString {
        storage.symbol.read_public()
    }

    #[aztec(private)]
    #[aztec(view)]
    fn private_get_symbol() -> pub FieldCompressedString {
        storage.symbol.read_private()
    }

    #[aztec(public)]
    #[aztec(view)]
    fn public_get_decimals() -> pub u8 {
        // docs:start:read_decimals_public
        storage.decimals.read_public()
        // docs:end:read_decimals_public
    }

    #[aztec(private)]
    #[aztec(view)]
    fn private_get_decimals() -> pub u8 {
        // docs:start:read_decimals_private
        storage.decimals.read_private()
        // docs:end:read_decimals_private
    }

    // docs:start:admin
    #[aztec(public)]
    #[aztec(view)]
    fn admin() -> Field {
        storage.admin.read().to_field()
    }
    // docs:end:admin

    // docs:start:is_minter
    #[aztec(public)]
    #[aztec(view)]
    fn is_minter(minter: AztecAddress) -> bool {
        storage.minters.at(minter).read()
    }
    // docs:end:is_minter

    // docs:start:total_supply
    #[aztec(public)]
    #[aztec(view)]
    fn total_supply() -> Field {
        storage.total_supply.read().to_integer()
    }
    // docs:end:total_supply


    // docs:start:set_minter
    #[aztec(public)]
    fn set_minter(minter: AztecAddress, approve: bool) {
        // docs:start:read_admin
        assert(storage.admin.read().eq(context.msg_sender()), "caller is not admin");
        // docs:end:read_admin
        // docs:start:write_minter
        storage.minters.at(minter).write(approve);
        // docs:end:write_minter
    }
    // docs:end:set_minter


    #[aztec(private)]
    fn privately_mint_private_note(amount: Field) {
        let caller = context.msg_sender();
        storage.balances.add(caller, U128::from_integer(amount)).emit(encode_and_encrypt_note(&mut context, caller, caller));

        Token::at(context.this_address()).assert_minter_and_mint(context.msg_sender(), amount).enqueue(&mut context);
    }

    #[aztec(public)]
    #[aztec(internal)]
    fn assert_minter_and_mint(minter: AztecAddress, amount: Field) {
        assert(storage.minters.at(minter).read(), "caller is not minter");
        let supply = storage.total_supply.read() + U128::from_integer(amount);
        storage.total_supply.write(supply);
    }


    // docs:start:transfer
    #[aztec(private)]
    fn transfer(to: AztecAddress, amount: Field) {
        let from = context.msg_sender();

        // By fetching the keys here, we can avoid doing an extra read from the storage, since from_ovpk would
        // be needed twice.
        let header = context.get_header();
        let from_ovpk = header.get_ovpk_m(&mut context, from);
        let from_ivpk = header.get_ivpk_m(&mut context, from);
        let to_ivpk = header.get_ivpk_m(&mut context, to);

        let amount = U128::from_integer(amount);
        storage.balances.sub(from, amount).emit(encode_and_encrypt_note_with_keys_unconstrained(&mut context, from_ovpk, from_ivpk, from));
        storage.balances.add(to, amount).emit(encode_and_encrypt_note_with_keys_unconstrained(&mut context, from_ovpk, to_ivpk, to));

        Transfer { from, to, amount: amount.to_field() }.emit(encode_and_encrypt_event_with_keys_unconstrained(&mut context, from_ovpk, to_ivpk, to));
    }
    // docs:end:transfer

    /**
     * Cancel a private authentication witness.
     * @param inner_hash The inner hash of the authwit to cancel.
     */
    // docs:start:cancel_authwit
    #[aztec(private)]
    fn cancel_authwit(inner_hash: Field) {
        let on_behalf_of = context.msg_sender();
        let nullifier = compute_authwit_nullifier(on_behalf_of, inner_hash);
        context.push_nullifier(nullifier, 0);
    }
    // docs:end:cancel_authwit

    // docs:start:transfer_from
    #[aztec(private)]
    fn transfer_from(from: AztecAddress, to: AztecAddress, amount: Field, nonce: Field) {
        // docs:start:assert_current_call_valid_authwit
        if (!from.eq(context.msg_sender())) {
            assert_current_call_valid_authwit(&mut context, from);
        } else {
            assert(nonce == 0, "invalid nonce");
        }
        // docs:end:assert_current_call_valid_authwit

        // By fetching the keys here, we can avoid doing an extra read from the storage, since from_ovpk would
        // be needed twice.
        let header = context.get_header();
        let from_ovpk = header.get_ovpk_m(&mut context, from);
        let from_ivpk = header.get_ivpk_m(&mut context, from);
        let to_ivpk = header.get_ivpk_m(&mut context, to);

        let amount = U128::from_integer(amount);
        // docs:start:increase_private_balance
        // docs:start:encrypted
        storage.balances.sub(from, amount).emit(encode_and_encrypt_note_with_keys(&mut context, from_ovpk, from_ivpk, from));
        // docs:end:encrypted
        // docs:end:increase_private_balance
        storage.balances.add(to, amount).emit(encode_and_encrypt_note_with_keys(&mut context, from_ovpk, to_ivpk, to));
    }
    // docs:end:transfer_from

    // docs:start:burn
    #[aztec(private)]
    fn burn(from: AztecAddress, amount: Field, nonce: Field) {
        if (!from.eq(context.msg_sender())) {
            assert_current_call_valid_authwit(&mut context, from);
        } else {
            assert(nonce == 0, "invalid nonce");
        }
        storage.balances.sub(from, U128::from_integer(amount)).emit(encode_and_encrypt_note(&mut context, from, from));

        Token::at(context.this_address())._reduce_total_supply(amount).enqueue(&mut context);
    }
    // docs:end:burn

    /// Internal ///


    // docs:start:reduce_total_supply
    #[aztec(public)]
    #[aztec(internal)]
    fn _reduce_total_supply(amount: Field) {
        // Only to be called from burn.
        let new_supply = storage.total_supply.read().sub(U128::from_integer(amount));
        storage.total_supply.write(new_supply);
    }
    // docs:end:reduce_total_supply

    /// Unconstrained ///

    // docs:start:balance_of_private
    unconstrained fn balance_of_private(owner: AztecAddress) -> pub Field {
        storage.balances.balance_of(owner).to_field()
    }
    // docs:end:balance_of_private
}
// docs:end:token_all
