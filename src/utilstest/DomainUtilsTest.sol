// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DomainUtils} from "../utils/DomainUtils.sol";

contract DomainUtilsTest {
    using DomainUtils for string;
    using DomainUtils for DomainUtils.Slice;

    function tokenId(string calldata domain) public pure returns (uint256) {
        return domain.tokenId();
    }

    function traceLevels(string calldata domain, uint256 level) public pure returns (uint256) {
        
        DomainUtils.Slice[] memory levels = domain.traceLevels();
        // uint256[] memory resp = new uint256[](levels.length);
        // return levels[level].tokenId();
        
        return levels.length;
        // for (uint256 i = levels.length - 1;;) {
        //     resp[i] = levels[i].tokenId();
        // }
        // return resp;
    }
}
