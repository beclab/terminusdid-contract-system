// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    function getRecord(bytes32) external view returns (bytes memory);
    function setRecord(bytes32, bytes calldata) external;
}
