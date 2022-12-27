// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IResolverWithParse} from "../IResolver.sol";

contract CustomResolver is IResolverWithParse {
    uint256 private constant _PUBLIC_KEY_LIMIT = 0xffff;

    // only if the key is beyond 0xffff and any non-empty data can be viewed as valid string
    function validate(uint256 key, bytes calldata value) external pure returns (uint256 status) {
        if (key <= _PUBLIC_KEY_LIMIT) {
            return 1;
        }

        if (value.length == 0) {
            return 10;
        }

        return 0;
    }

    function parse(uint256 key, bytes calldata value) external pure returns (uint256 status, bytes memory parsed) {
        if (key <= _PUBLIC_KEY_LIMIT) {
            return (1, "");
        }

        if (value.length == 0) {
            return (10, "");
        }

        parsed = abi.encode(string(value));
        return (0, parsed);
    }
}
