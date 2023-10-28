// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ContractStorage, ContractStorageLib, DynamicSlot, Slot} from "../src/ContractStorage.sol";
import {Storage} from "../src/internal/Storage.sol";

contract ContractStorageTest is Test, ContractStorage {
    using ContractStorageLib for Slot;

    Slot private constant TEST_SLOT = Slot.wrap(0);

    function setUp() public {}

    function test_WriteSlot() public {
        assertEq(cload(TEST_SLOT), 0);
        cstore(TEST_SLOT, 42);
        assertEq(cload(TEST_SLOT), 42);
    }

    function test_ReadEmptySlot() public {
        Slot emptySlot = Slot.wrap(uint256(keccak256("empty slot")));
        assertEq(cload(emptySlot), 0);
    }

    function test_ResetSlot() public {
        creset(TEST_SLOT);

        cstore(TEST_SLOT, 42);
        creset(TEST_SLOT);
    }

    function test_OverwriteSlot() public {
        cstore(TEST_SLOT, 1);
        assertEq(cload(TEST_SLOT), 1);

        creset(TEST_SLOT);

        // TODO: Currently doesn't work, as `SELFDESTRUCT` just schedules a
        // contract for deletion, but it only actually gets deleted at the end
        // of the transaction, and not at the end of the inner call. AFAICT,
        // there is no way to trigger a "transaction boundary" within a Forge
        // test, which would be required between the `creset` and the following
        // `cstore` for the target contract to actually be empty.
        //     cstore(TEST_SLOT, 42);
        //     assertEq(cload(TEST_SLOT), 42);
    }

    function testFail_SlotFull() public {
        cstore(TEST_SLOT, 1);
        cstore(TEST_SLOT, 2);
    }

    function test_DynamicSlotReadcstore() public {
        DynamicSlot memory slot = DynamicSlot({start: TEST_SLOT, arrity: 4});
        assertEq(cload(slot), 0);

        for (uint256 i = 1; i <= slot.arrity; i++) {
            cstore(slot, i);
            assertEq(cload(slot), i);
        }
    }

    function test_DynamicSlotNextSequence() public {
        uint256 valueSlot = uint256(keccak256("ContractStorage.value")) - 1;
        uint256 sequenceSlot = uint256(keccak256("ContractStorage.sequence")) - 1;
        Slot dynamicSlot = Slot.wrap(uint256(keccak256("ContractStorage.DynamicSlot")) - 1);

        uint256 arrity = 3;
        for (uint256 i = 0; i < arrity; i++) {
            assembly ("memory-safe") {
                sstore(valueSlot, 1)
                sstore(sequenceSlot, 1336)
            }
            Slot lastOffset = dynamicSlot.map(bytes32(i)).offset(i);
            new Storage{salt: bytes32(Slot.unwrap(lastOffset))}();
            assembly ("memory-safe") {
                sstore(valueSlot, 0)
                sstore(sequenceSlot, 0)
            }

            DynamicSlot memory slot = DynamicSlot({start: Slot.wrap(i), arrity: arrity});
            cstore(slot, 42);
            assertEq(cload(slot), 42);

            address instance = getSlotAddress(dynamicSlot.map(bytes32(i)).offset((i + 1) % arrity));
            uint256 value;
            uint256 sequence;
            assembly ("memory-safe") {
                mstore(0, 0)
                mstore(32, 0)
                pop(staticcall(gas(), instance, 0, 0, 0, 64))
                value := mload(0)
                sequence := mload(32)
            }

            assertEq(value, 42);
            assertEq(sequence, 1337);
        }
    }

    function testFail_DynamicSlotFull() public {
        DynamicSlot memory slot = DynamicSlot({start: TEST_SLOT, arrity: 3});
        for (uint256 i = 0; i < slot.arrity; i++) {
            cstore(slot, i);
        }

        // TODO: Doesn't work because this expects a revert on the next call and
        // not from the test contract itself.
        //     vm.expectRevert(ContractStorage.DynamicSlotFull.selector);
        cstore(slot, slot.arrity);
    }
}
