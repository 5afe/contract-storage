// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.21;

interface IContractStorage {
    function contractStorageValue() external view returns (uint256 value);
}
