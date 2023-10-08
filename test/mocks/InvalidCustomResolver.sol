// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IResolver} from "../../src/resolvers/IResolver.sol";

contract InvalidCustomResolver is IResolver {
    function tagGetter(uint256 key) public pure returns (bytes4) {
        if (key == 0xffff) {
            return 0xffffffff;
        }
        return 0;
    }
}
