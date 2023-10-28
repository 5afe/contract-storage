# Contract Storage

This repository implements a contract-based storage mechanism. Specifically, it
uses `CREATE2` to deploy contracts to well known addresses whose code contains
the actual stored values.

This makes use of two things:
- `CREATE2` to deploy contracts to deterministic addresses. Additionally the
  value being stored per contract is read using `SLOAD` in the caller, meaning
  that the storage contract ends up at the same address regardless of the
  stored value.
- `SELFDESTRUCT` to remove a contract code. Critically, this allows a new
  contract to be deployed at the same address using `CREATE2` which a
  potentially different stored value.

## Stability

In general **it it not recommended to use this module**. `SELFDESTRUCT` has been
officially deprecated, and this code relies on it to updating values.
