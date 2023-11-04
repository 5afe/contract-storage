# Contract Storage

This repository implements a contract-based storage mechanism. Specifically, it
uses `CREATE2` to deploy contracts to well known addresses whose code contains
the actual stored values.

This makes use of two things:

- `CREATE2` to deploy contracts to deterministic addresses. Additionally the
  value being stored per contract is read using `SLOAD` in the caller, meaning
  that the storage contract ends up at the same address regardless of the stored
  value.
- `SELFDESTRUCT` to remove a contract code. Critically, this allows a new
  contract to be deployed at the same address using `CREATE2` which a
  potentially different stored value.

This repository provides a `ContractStorage` abstract class with `cload`,
`cstore` functions (analogous to `{m,s,t}{load,store}` op-codes) for reading and
writing to and from contract storage. It comes in two flavours: `Slot` and
`DynamicSlot`.

## `Slot` Storage

The basic kind of contract storage is the `Slot`. It works by deploying a
contract using `CREATE2` whose address is salted with the slot value. In order
to change the value, **two** transactions are needed:

1. A first transaction that `creset`s the `Slot`.
2. A second transaction that `cstore`s the new value.

Unfortunately, both steps cannot be incuded in the same EVM transaction. This is
because `SELFDESTRUCT` _schedules a contract for deletion, but does not delete
it right away_. This means that the contract will act as if it has code even
after `SELFDESTRUCT` is called until the end of the transaction. Namely, this
prevents:

- Calling `CREATE2` where the code would end on the same address as the
  `SELFDESTRUCT`-ed contract
- Reading the value from the contract will return as if it is still set

## `DynamicSlot` Storage

This is a system with a "`Slot` queue" which allows for values to be updated
within a transaction. It allows specifying an arrity, or the maximum number of
updates that the `DynamicSlot` can do within a given EVM transaction (because of
the same `SELFDESTRUCT` limitations that exist for `Slot`).

This does not work in ERC-4337 `validateUserOp` calls, as it potentially reads
from contracts with empty code (the empty `Slot`s in the queue).

## Stability

In general **it it not recommended to use this module**. `SELFDESTRUCT` has been
officially deprecated, and this code relies on it to updating values.

## Potential Uses

One potential usage of this mechanism is for storing whether or not a module is
enabled in the Safe Core Protocol registry. The use of contract storage over
more conventional storage (i.e. `S{LOAD,STORE`) would allow registry checks in
`validateUserOp` without requiring a staked _paymaster_.

The being said, because of the stability concerns, I'm not sure I recommend
using it, especially since `SELFDESTRUCT` is officially deprecated, but it is a
fun thought experiment and potential solution to the ERC-4337 storage
restrictions.
