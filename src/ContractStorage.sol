// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.21;

import {IContractStorage} from "./interfaces/IContractStorage.sol";
import {Storage} from "./internal/Storage.sol";

type Slot is uint256;

struct DynamicSlot {
    Slot slot;
    uint256 arrity;
}

abstract contract ContractStorage is IContractStorage {
    uint256 private constant VALUESLOT = uint256(keccak256("ContractStorage.value")) - 1;
    bytes32 private constant CODEHASH = keccak256(type(Storage).creationCode);

    function contractStorageValue() external view returns (uint256 value) {
        uint256 valueSlot = VALUESLOT;
        assembly ("memory-safe") {
            value := sload(valueSlot)
        }
    }

    function setContractStorageValue(uint256 value) private {
        uint256 valueSlot = VALUESLOT;
        assembly ("memory-safe") {
            sstore(valueSlot, value)
        }
    }

    function read(Slot slot) internal view returns (uint256 value) {
        address instance = getAddress(slot);
        assembly ("memory-safe") {
            pop(staticcall(gas(), instance, 0, 0, 0, 32))
            value := mload(0)
        }
    }

    function write(Slot slot, uint256 value) internal {
        if (value == 0) {
            address instance = getAddress(slot);
            bytes4 selector = Storage.reset.selector;
            assembly ("memory-safe") {
                mstore(0, selector)
                pop(call(gas(), instance, 0, 0, 4, 0, 0))
            }
        } else {
            setContractStorageValue(value);
            new Storage{salt: bytes32(Slot.unwrap(slot))}();
            setContractStorageValue(0);
        }
    }

    function getAddress(Slot slot) internal view returns (address instance) {
        instance = address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", this, slot, CODEHASH)))));
    }
}

library ContractStorageLib {}
