// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ContractStorage, Slot} from "../src/ContractStorage.sol";

contract ContractStorageTest is Test, ContractStorage {
    Slot private constant MY_SLOT = Slot.wrap(0);

    function setUp() public {}

    function test_WriteSlot() public {
        assertEq(read(MY_SLOT), 0);
        write(MY_SLOT, 42);
        assertEq(read(MY_SLOT), 42);
    }

    function test_ReadEmptySlot() public {
        Slot emptySlot = Slot.wrap(uint256(keccak256("empty slot")));
        assertEq(read(emptySlot), 0);
    }

    function test_ResetSlot() public {
        write(MY_SLOT, 42);
        write(MY_SLOT, 0);
    }
}
