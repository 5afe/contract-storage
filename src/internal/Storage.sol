// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.21;

import {IContractStorage} from "../interfaces/IContractStorage.sol";

contract Storage {
    address private immutable CONTEXT;
    uint256 private immutable VALUE;

    constructor() {
        CONTEXT = msg.sender;
        VALUE = IContractStorage(msg.sender).contractStorageValue();
    }

    function reset() external {
        require(msg.sender == CONTEXT);
        selfdestruct(payable(address(0)));
    }

    fallback() external {
        uint256 value = VALUE;
        assembly ("memory-safe") {
            mstore(0, value)
            return(0, 32)
        }
    }
}
