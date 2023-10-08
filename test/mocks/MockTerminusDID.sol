// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockTerminusDID is UUPSUpgradeable {
    function getVersion() public pure returns (string memory) {
        return "mock version";
    }

    function _authorizeUpgrade(address newImplementation) internal view override {}
}
