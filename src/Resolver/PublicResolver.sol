// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./MetaResolver.sol";

contract PublicResolver is MetaResolver {
    constructor(address _oracle) MetaResolver(_oracle) {}
}
