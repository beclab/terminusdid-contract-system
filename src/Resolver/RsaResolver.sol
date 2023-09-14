// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseResolver} from "./BaseResolver.sol";

abstract contract RsaResolver is BaseResolver {
    string constant KEY = "std:rsaPubKey";

    event RsaChanged(bytes32 indexed node, string key, string pubKey);

    function setRsaPubKey(bytes32 node, string calldata pubKey) external {
        oracle.setExtentedAttr(node, KEY, bytes(pubKey));
        emit RsaChanged(node, KEY, pubKey);
    }

    function getRsaPubKey(bytes32 node) external view returns (string memory) {
        bytes memory pubKey = oracle.getExtentedAttr(node, KEY);
        return string(pubKey);
    }
}
