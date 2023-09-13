// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./IOracle.sol";

contract Resolver {
    IOracle public oracle;

    constructor(IOracle _oracle) {
        oracle = _oracle;
    }

    function setMetadata(bytes32 node, string calldata did, address owenr, string calldata nodeType) external {
        
    }
}
