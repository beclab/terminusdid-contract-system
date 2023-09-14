// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseResolver} from "./BaseResolver.sol";

abstract contract RsaResolver is BaseResolver {
    string constant KEY = "std:rsa";

    event RsaChanged(bytes32 indexed node, string key, bytes pubKey);

    function setRsa(bytes32 node, bytes calldata pubKey) external {
        oracle.setExtentedAttr(node, KEY, pubKey);
        emit RsaChanged(node, KEY, pubKey);
    }

    function getRsa(bytes32 node) external view returns (bytes memory) {
        return oracle.getExtentedAttr(node, KEY);
    }
}
