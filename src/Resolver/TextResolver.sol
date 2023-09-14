// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Oracle} from "../Oracle.sol";
import {BaseResolver} from "./BaseResolver.sol";
import {strings} from "solidity-stringutils/src/strings.sol";

abstract contract TextResolver is BaseResolver {
    using strings for *;

    uint256 CUSTOM = "custom:".toSlice();

    event SetText(bytes32 indexed node, string key, string value);

    function setText(bytes32 node, string calldata key, string calldata value) external {
        require(key.toSlice().startsWith(CUSTOM), "not a valid key");
    }

    function getText(bytes32 node, string calldata key) external view returns (string memory value) {}
}
