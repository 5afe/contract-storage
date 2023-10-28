// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.21;

import {IContractStorage} from "./internal/IContractStorage.sol";
import {Storage} from "./internal/Storage.sol";

type Slot is uint256;

library ContractStorageLib {
    function map(Slot slot, bytes32 key) internal pure returns (Slot value) {
        assembly ("memory-safe") {
            mstore(0, key)
            mstore(32, slot)
            value := keccak256(0, 64)
        }
    }

    function arrayLength(Slot slot) internal pure returns (Slot length) {
        length = slot;
    }

    function arrayIndex(Slot slot, uint256 index) internal pure returns (Slot value) {
        assembly ("memory-safe") {
            mstore(0, slot)
            value := add(keccak256(0, 32), index)
        }
    }

    function offset(Slot slot, uint256 index) internal pure returns (Slot value) {
        value = Slot.wrap(Slot.unwrap(slot) + index);
    }
}

struct DynamicSlot {
    Slot start;
    uint256 arrity;
}

abstract contract ContractStorage is IContractStorage {
    using ContractStorageLib for Slot;

    uint256 private constant VALUESLOT = uint256(keccak256("ContractStorage.value")) - 1;
    uint256 private constant SEQUENCESLOT = uint256(keccak256("ContractStorage.sequence")) - 1;

    Slot private constant DYNAMICSLOT = Slot.wrap(uint256(keccak256("ContractStorage.DynamicSlot")) - 1);

    bytes32 private constant CODEHASH = keccak256(type(Storage).creationCode);

    error SlotFull();
    error DynamicSlotFull();

    function contractStorageValue() external view returns (uint256 value, uint256 sequence) {
        uint256 valueSlot = VALUESLOT;
        uint256 sequenceSlot = SEQUENCESLOT;
        assembly ("memory-safe") {
            value := sload(valueSlot)
            sequence := sload(sequenceSlot)
        }
    }

    function setContractStorageValue(uint256 value, uint256 sequence) private {
        uint256 valueSlot = VALUESLOT;
        uint256 sequenceSlot = SEQUENCESLOT;
        assembly ("memory-safe") {
            sstore(valueSlot, value)
            sstore(sequenceSlot, sequence)
        }
    }

    function cload(Slot slot) internal view returns (uint256 value) {
        address instance = getSlotAddress(slot);
        assembly ("memory-safe") {
            mstore(0, 0)
            pop(staticcall(gas(), instance, 0, 0, 0, 32))
            value := mload(0)
        }
    }

    function cstore(Slot slot, uint256 value) internal {
        address instance = getSlotAddress(slot);
        uint256 codeSize;
        assembly ("memory-safe") {
            codeSize := extcodesize(instance)
        }

        if (codeSize != 0) {
            revert SlotFull();
        }

        setContractStorageValue(value, 0);
        new Storage{salt: bytes32(Slot.unwrap(slot))}();
        setContractStorageValue(0, 0);
    }

    function creset(Slot slot) internal {
        address instance = getSlotAddress(slot);
        bytes4 selector = Storage.reset.selector;
        assembly ("memory-safe") {
            mstore(0, selector)
            pop(call(gas(), instance, 0, 0, 4, 0, 0))
        }
    }

    function dynamicSlotOffset(DynamicSlot memory slot, uint256 index) private pure returns (Slot offset) {
        offset = DYNAMICSLOT.map(bytes32(Slot.unwrap(slot.start))).offset(index);
    }

    function cload(DynamicSlot memory slot) internal view returns (uint256 value) {
        unchecked {
            uint256 sequence;

            for (uint256 i = 0; i < slot.arrity; i++) {
                Slot offset = dynamicSlotOffset(slot, i);

                address instance = getSlotAddress(offset);
                uint256 offsetValue;
                uint256 offsetSequence;
                assembly ("memory-safe") {
                    mstore(0, 0)
                    mstore(32, 0)
                    pop(staticcall(gas(), instance, 0, 0, 0, 64))
                    offsetValue := mload(0)
                    offsetSequence := mload(32)
                }

                if (offsetSequence > sequence) {
                    value = offsetValue;
                    sequence = offsetSequence;
                }
            }
        }
    }

    function cstore(DynamicSlot memory slot, uint256 value) internal {
        unchecked {
            uint256 firstSequence;
            uint256 lastIndex;
            uint256 sequence;
            for (uint256 i = 0; i < slot.arrity; i++) {
                Slot offset = dynamicSlotOffset(slot, i);

                address instance = getSlotAddress(offset);
                uint256 offsetSequence;
                assembly ("memory-safe") {
                    mstore(0, 0)
                    mstore(32, 0)
                    pop(staticcall(gas(), instance, 0, 0, 0, 64))
                    offsetSequence := mload(32)
                }

                if (i == 0) {
                    firstSequence = offsetSequence;
                }
                if (offsetSequence > sequence) {
                    lastIndex = i;
                    sequence = offsetSequence;
                }
            }

            if (sequence == 0) {
                setContractStorageValue(value, 1);
                new Storage{salt: bytes32(Slot.unwrap(dynamicSlotOffset(slot, 0)))}();
                setContractStorageValue(0, 0);
            } else {
                uint256 nextIndex = (lastIndex + 1) % slot.arrity;
                uint256 nextSequence = sequence + 1;
                if (nextIndex == 0 && firstSequence != 0) {
                    revert DynamicSlotFull();
                }

                creset(dynamicSlotOffset(slot, lastIndex));
                setContractStorageValue(value, nextSequence);
                new Storage{salt: bytes32(Slot.unwrap(dynamicSlotOffset(slot, nextIndex)))}();
                setContractStorageValue(0, 0);
            }
        }
    }

    function getSlotAddress(Slot slot) internal view returns (address instance) {
        instance = address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", this, slot, CODEHASH)))));
    }
}
