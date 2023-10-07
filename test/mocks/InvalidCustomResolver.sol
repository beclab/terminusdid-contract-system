// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IResolverWithParse} from "../../src/resolvers/IResolver.sol";

contract InvalidCustomResolver is IResolverWithParse {
    uint32 private constant _PUBLIC_KEY_LIMIT = 0xffff;

    function validate(uint32 key, bytes calldata value) external pure returns (uint256 status) {
        if (key > _PUBLIC_KEY_LIMIT) {
            return 1;
        }

        if (value.length == 0) {
            return 10;
        }

        return 0;
    }

    function parse(uint32 key, bytes calldata value) external pure returns (uint256 status, bytes memory parsed) {
        if (key > _PUBLIC_KEY_LIMIT) {
            return (1, "");
        }

        if (value.length == 0) {
            return (10, "");
        }

        parsed = abi.encode(string(value));
        return (0, parsed);
    }
}
