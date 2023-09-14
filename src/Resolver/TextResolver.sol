// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseResolver} from "./BaseResolver.sol";
import {strings} from "solidity-stringutils/src/strings.sol";

abstract contract TextResolver is BaseResolver {
    using strings for *;

    strings.slice CUSTOM = "custom:".toSlice();

    event TextChanged(bytes32 indexed node, string indexed key, string value);

    modifier validKeyOnly(string calldata key) {
        strings.slice memory keySlice = key.toSlice();
        require(keySlice.startsWith(CUSTOM), "TextResolver: not a valid key, valid key should starts with 'custom:'");
        _;
    }

    function setText(bytes32 node, string calldata key, string calldata value) external validKeyOnly(key) {
        oracle.setExtentedAttr(node, key, bytes(value));
        emit TextChanged(node, key, value);
    }

    function getText(bytes32 node, string calldata key) external view validKeyOnly(key) returns (string memory) {
        bytes memory value = oracle.getExtentedAttr(node, key);
        return string(value);
    }
}
