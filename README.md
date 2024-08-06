# PROBLEM 1 - shell killed

Error: `/usr/src/avm-transpiler/scripts/compile_then_transpile.sh: line 17:     8 Killed                  $NARGO $@ `

Reproduce: `aztec test` should start running 16 tests and then fail with the above error. Running the tests separately, `burn` and `transfer_private` separately, should pass all tests.

# PROBLEM 2 - users are able to burn other users notes in TXE without authwit

Running `aztec test` should pass the first test and fail the second. The second test mints tokens to `owner` and then `recipient` is able to burn them, which should not be allowed. 
