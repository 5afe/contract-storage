// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.21;

import {IContractStorage} from "../interfaces/IContractStorage.sol";

contract Storage {
    address private immutable CONTEXT;
    uint256 private immutable VALUE;
    uint256 private immutable SEQUENCE;

    constructor(uint256 sequence) {
        CONTEXT = msg.sender;
        VALUE = IContractStorage(msg.sender).contractStorageValue();
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
