// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.21;

import {IContractStorage} from "./IContractStorage.sol";

contract Storage {
    address private immutable CONTEXT;
    uint256 private immutable VALUE;
    uint256 private immutable SEQUENCE;

    constructor() {
        CONTEXT = msg.sender;

        (uint256 value, uint256 sequence) = IContractStorage(msg.sender).contractStorageValue();
        VALUE = value;
        SEQUENCE = sequence;
    }

    function reset() external {
        require(msg.sender == CONTEXT);
        selfdestruct(payable(address(0)));
    }

    fallback() external {
        uint256 value = VALUE;
        uint256 sequence = SEQUENCE;
        assembly ("memory-safe") {
            mstore(0, value)
            mstore(32, sequence)
            return(0, 64)
        }
    }
}
