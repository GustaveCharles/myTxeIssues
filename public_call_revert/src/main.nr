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
    },
    keys::getters::get_current_public_keys
    };

    // docs:start:import_authwit
    use dep::authwit::auth::{assert_current_call_valid_authwit, assert_current_call_valid_authwit_public, compute_authwit_nullifier};
    // docs:end:import_authwit

    use crate::types::{token_note::{TokenNote, TOKEN_NOTE_LEN}, balances_map::BalancesMap};
    // docs:end::imports
    global MAX_ADDR_PER_CALL = 10;

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

    // docs:start:set_minter
    #[aztec(public)]
    fn set_minter(minter: AztecAddress, approve: bool) {
        // docs:start:read_admin
        // docs:end:read_admin
        // docs:start:write_minter
        storage.minters.at(minter).write(approve);
        // docs:end:write_minter
    }
    // docs:end:set_minter


    #[aztec(private)]
    fn mint(to: AztecAddress, amount: Field) {
        let from = context.msg_sender();

        let from_keys = get_current_public_keys(&mut context, from);

        let note = storage.balances.add(to, from_keys.npk_m , U128::from_integer(amount)).emit(encode_and_encrypt_note(&mut context,to,to));

        Token::at(context.this_address()).assert_minter_and_mint(context.msg_sender(), amount).enqueue(&mut context);
    }
    
    #[aztec(public)]
    #[aztec(internal)]
    fn assert_minter_and_mint(minter: AztecAddress, amount: Field) {
        assert(storage.minters.at(minter).read(), "caller is not minter");
        let supply = storage.total_supply.read() + U128::from_integer(amount);
        storage.total_supply.write(supply);
    }


    /// Unconstrained ///

    // docs:start:balance_of_private
    unconstrained fn balance_of_private(owner: AztecAddress) -> pub Field {
        storage.balances.balance_of(owner).to_field()
    }
    // docs:end:balance_of_private
}
// docs:end:token_all
