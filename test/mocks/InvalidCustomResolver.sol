// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IResolver} from "../../src/resolvers/IResolver.sol";

contract InvalidCustomResolver is IResolver {
    function supportsTag(uint256 key) public pure returns (bool) {
        return key == 0xffff;
    }
}
